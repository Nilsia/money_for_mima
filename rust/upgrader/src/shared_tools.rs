use async_trait::async_trait;
use core::fmt;
use std::{
    fs::{self, OpenOptions},
    io::{self, Cursor},
    path::{Path, PathBuf},
};

#[derive(Debug)]
pub enum CustomError {
    WrongParentFolder,
    DesktopNotFound,
    HomeDirNotFound,
    NotEnoughPermission,
    UnkownError,
}

impl std::error::Error for CustomError {}

impl fmt::Display for CustomError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            CustomError::WrongParentFolder => write!(f, "Vous n'êtes pas dans le bon dossier."),
            CustomError::DesktopNotFound => write!(f, "Impossible de récupérer votre Bureau"),
            CustomError::HomeDirNotFound => {
                write!(f, "Impossible de récupérer votre dossier personnel")
            }
            CustomError::NotEnoughPermission => {
                write!(f, "Vous ne possédez pas les permissions nécéssaires")
            }
            CustomError::UnkownError => write!(f, "Une erreur inconnue est survenue"),
        }
    }
}

pub type Error = Box<dyn std::error::Error>;

pub enum ReturnValue {
    NoError,
    Skip,
    Exit,
}

pub const VERSION: &str = "0.9.0";

#[async_trait]
pub trait CommonFunctions {
    fn system(&self) -> &str;

    /// Download the zip file that contain the files to run Money For Mima, the only element
    /// requested is the file path in which the zip file will be writen
    ///
    /// * `filepath`: the path of the file
    async fn download_file(&self, filename: &PathBuf) -> Result<(), Error> {
        let app_and_version_filename: &str = "money_for_mima";
        let remote_filename = PathBuf::from(format!(
            "{}-{}.zip",
            app_and_version_filename,
            self.system()
        ));
        let resp = reqwest::get(format!(
            "https://leria-etud.univ-angers.fr/~ddasilva/money_for_mima/{}",
            remote_filename.display()
        ))
        .await?;

        // get the binary data of the compressed archive
        let zip_bytes = resp.bytes().await?.to_vec();

        // preparation for the compressed archive
        let mut file_output = OpenOptions::new()
            .write(true)
            .read(true)
            .create(true)
            .open(&filename)?;

        // write everything in a file -> it is the zip file
        let mut cursor = Cursor::new(zip_bytes);
        if let Err(e) = std::io::copy(&mut cursor, &mut file_output) {
            fs::remove_file(&filename)?;
            return Err(Box::new(e));
        };
        Ok(())
    }

    #[cfg(unix)]
    fn extract_zip(
        &self,
        archive: &Path,
        target_dir: &Path,
        _exceptions: Vec<PathBuf>,
    ) -> Result<(), Error> {
        let file_archive = fs::File::open(archive)?;
        zip_extract::extract(&file_archive, target_dir, true)?;
        Ok(())
    }

    #[cfg(target_os = "windows")]
    fn extract_zip(
        &self,
        archive: &Path,
        target_dir: &Path,
        exceptions: Vec<PathBuf>,
    ) -> std::io::Result<()> {
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
}

pub fn get_exec_extension() -> String {
    if cfg!(unix) {
        return "".to_string();
    } else if cfg!(windows) {
        return ".exe".to_string();
    } else {
        return "".to_string();
    }
}

pub async fn get_remote_version() -> Result<String, Error> {
    let resp = match reqwest::get(format!(
        "https://leria-etud.univ-angers.fr/~ddasilva/money_for_mima/get_version.php?appVersion={}",
        VERSION
    ))
    .await
    {
        Ok(v) => v,
        Err(_) => {
            return Err(Box::from(
                "Impossible de récupérer la nouvelle version (2)".to_string(),
            ))
        }
    };
    let text = match resp.text().await {
        Ok(v) => v,
        Err(_) => {
            return Err(Box::from(
                "Impossible de récupérer la nouvelle version (3)".to_string(),
            ))
        }
    };

    let app_version_parsed = match json::parse(&text) {
        Ok(v) => v,
        Err(_) => {
            return Err(Box::from(
                "Impossible de récupérer la nouvelle version (4)".to_string(),
            ))
        }
    };

    match &app_version_parsed["appVersion"] {
        json::JsonValue::Short(s) => Ok(s.to_string()),
        _ => Err(Box::from(
            "Impossible de récupérer la nouvelle version (5)".to_string(),
        )),
    }
}

pub fn print_exit_program() {
    print_sep();
    println!("Fermeture du programme d'installation");
}

pub fn do_all_files_exist(files_to_move: &Vec<String>) -> bool {
    let mut path: &Path;
    for file in files_to_move {
        path = Path::new(&file);
        if !path.exists() {
            return false;
        }
    }
    true
}

pub fn wait_for_input() -> io::Result<()> {
    print_sep();
    println!("Tapez sur la touche ENTRER pour fermer le terminal");
    let mut buf = String::new();
    std::io::stdin().read_line(&mut buf)?;

    Ok(())
}

#[allow(dead_code)]
pub fn copy_dir_content(
    from: &PathBuf,
    to: &PathBuf,
    exception: &Vec<&str>,
    options: &fs_extra::dir::CopyOptions,
) -> Result<(), Error> {
    let mut folder_testing = fs::read_dir(&from)?;
    if folder_testing.next().is_none() {
        fs::create_dir_all(to)?;
        return Ok(());
    }

    for file_res in fs::read_dir(&from)? {
        let f: fs::DirEntry = file_res?;
        let f_pathbuf: PathBuf = f.path().clone();
        let f_path: &Path = f_pathbuf.as_path();
        let filename = match f_path.file_name() {
            Some(v) => match v.to_str() {
                Some(v) => v,
                None => continue,
            },
            None => continue,
        };
        if exception.contains(&filename) {
            continue;
        }
        match f.file_type() {
            Ok(t) => {
                if t.is_dir() {
                    fs_extra::dir::copy(f_path, to, options)?;
                } else if t.is_file() {
                    if let Err(e) = fs::copy(f_path, to.join(filename)) {
                        eprintln!("{} : {}", filename, e);
                    }
                }
            }
            Err(_) => (),
        }
    }

    Ok(())
}

pub fn print_sep() {
    println!("\n==========-==========-==========\n")
}
