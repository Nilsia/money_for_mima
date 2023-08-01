use std::{
    env, fs, io,
    path::{Path, PathBuf},
};

use fs_extra::dir;

use crate::shared_tools::{
    copy_dir_content, get_exec_extension, get_remote_version, CommonFunctions, CustomError, Error,
    VERSION,
};

pub struct Upgrader {
    pub current_dir: Option<PathBuf>,
    pub system: String,
    pub exec_extension: String,
}

impl CommonFunctions for Upgrader {
    fn system(&self) -> &str {
        &self.system
    }
    // fn files_destination(&self) ->  &Option<PathBuf> {
    //     &None
    // }
}

impl Upgrader {
    pub fn new() -> Upgrader {
        let system = String::from(if cfg!(windows) { "windows" } else { "linux" });
        Upgrader {
            current_dir: None,
            system,
            exec_extension: get_exec_extension(),
        }
    }
    pub async fn run_upgrade(&mut self) -> Result<(), Error> {
        self.current_dir = Some(env::current_dir()?);

        // check the parent directory
        if self
            .current_dir
            .as_ref()
            .unwrap()
            .file_name()
            .is_some_and(|name| name != "money_for_mima")
        {
            return Err(Box::new(CustomError::WrongParentFolder));
        }

        // verify it is already up to date
        let remote_version = get_remote_version().await?;
        if remote_version == VERSION {
            println!("Money For Mima est déjà à jour.");
            return Ok(());
        }

        // download remote version for upgrade
        let mut downloaded_file = self.current_dir.as_ref().unwrap().join("money_for_mima");
        downloaded_file.set_extension(".zip");
        self.download_file(&downloaded_file).await?;

        // specify the target of the extraction as the current directory
        let extraction_dir = self.current_dir.as_ref().unwrap().join("tmp");

        let upgrade_filename = PathBuf::from("upgrade".to_owned() + &self.exec_extension);
        // extract compressed archive caugth from the internet
        extract_zip(
            &downloaded_file,
            &extraction_dir,
            [upgrade_filename.to_owned()].to_vec(),
        )?;

        let mut options = dir::CopyOptions::new();
        options.overwrite = true;

        // copy content of the extracted zip into the current folder to update everything
        copy_dir_content(
            &extraction_dir,
            &self.current_dir.as_ref().unwrap(),
            &vec![upgrade_filename.to_str().unwrap_or("upgrade"), ".dart_tool"],
            &options,
        )?;

        // remove zip file
        fs::remove_file(&downloaded_file)?;

        if let Err(_) = fs::remove_dir_all(&extraction_dir) {
            return Err(Box::from(
                "Impossible de supprimer le dossier temporaire, cette erreur n'est pas importante"
                    .to_string(),
            ));
        }

        println!("Money For Mima est à jour.");

        Ok(())
    }
}

#[cfg(unix)]
fn extract_zip(
    archive: &Path,
    target_dir: &Path,
    _exceptions: Vec<PathBuf>,
) -> std::io::Result<()> {
    let file_archive = fs::File::open(archive)?;
    match zip_extract::extract(&file_archive, target_dir, true) {
        Ok(_) => (),
        Err(_) => {
            return Err(std::io::Error::new(
                io::ErrorKind::Other,
                "Cannot extract zip file",
            ))
        }
    };
    Ok(())
}

#[cfg(windows)]
fn extract_zip(archive: &Path, target_dir: &Path, exceptions: Vec<PathBuf>) -> std::io::Result<()> {
    let file_archive = fs::File::open(archive)?;

    let mut archive = match zip::ZipArchive::new(file_archive) {
        Ok(v) => v,
        Err(e) => {
            return Err(e.into());
        }
    };

    for i in 0..archive.len() {
        let mut file = match archive.by_index(i) {
            Ok(v) => v,
            Err(e) => {
                println!("hi i am here");
                return Err(e.into());
            }
        };
        let enclosed_name = match file.enclosed_name() {
            Some(v) => v,
            None => continue,
        };

        let outpath = target_dir.join(enclosed_name.to_owned());
        let filename_in_zip = match enclosed_name.to_str() {
            Some(v) => v,
            None => continue,
        }
        .to_string();

        if exceptions.contains(&PathBuf::from(&filename_in_zip)) {
            continue;
        }
        if filename_in_zip.ends_with('/') || filename_in_zip.ends_with("\\") {
            fs::create_dir_all(&outpath)?;
        } else {
            if let Some(p) = outpath.parent() {
                if !p.exists() {
                    fs::create_dir_all(p)?;
                }
            }
            let mut outfile = fs::File::create(&outpath)?;
            io::copy(&mut file, &mut outfile)?;
        }

        // Get and Set permissions
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;

            if let Some(mode) = file.unix_mode() {
                fs::set_permissions(&outpath, fs::Permissions::from_mode(mode))?;
            }
        }
    }

    Ok(())
}
