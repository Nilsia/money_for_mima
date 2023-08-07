use std::{env, fs, io::Write, path::PathBuf};

use fs_extra::dir;

use shared_elements::{
    common_functions::{copy_dir_content, get_exec_extension},
    common_functions_trait::{CommonFunctions, DataHashMap},
    custom_error::CustomError,
    Error,
};

pub struct Upgrader {
    current_dir: Option<PathBuf>,
    system: String,
    exec_extension: String,
    log_filename: Option<PathBuf>,
    remote_value: Option<DataHashMap>,
}

impl CommonFunctions for Upgrader {
    fn system(&self) -> &str {
        &self.system
    }

    fn log_filename(&mut self) -> Option<&mut PathBuf> {
        self.log_filename.as_mut()
    }

    fn files_container(&self) -> Option<&PathBuf> {
        self.current_dir.as_ref()
    }

    fn remote_data(&mut self) -> Option<&mut DataHashMap> {
        self.remote_value.as_mut()
    }

    fn exec_extension(&self) -> &str {
        &self.exec_extension
    }

    fn insert_remote_data(&mut self, data: DataHashMap) {
        let _ = self.remote_value.insert(data);
    }

    fn insert_logfilename(&mut self,filename:PathBuf) {
        let _ = self.log_filename.insert(filename);
    }
}

impl Upgrader {
    pub fn new() -> Upgrader {
        let system = String::from(if cfg!(windows) { "windows" } else { "linux" });
        Upgrader {
            current_dir: None,
            system,
            exec_extension: get_exec_extension(),
            log_filename: None,
            remote_value: None,
        }
    }
    pub async fn run_upgrade(&mut self, ask: bool) -> Result<(), Error> {
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

        let _ = self.get_remote_data().await?;

        // verify it is already up to date
        let remote_version = self.get_remote_version().await?;
        let local_version = self.get_local_version(None).await?;
        println!(
            "La version actuelle de Money For Mima est la suivante : {}",
            local_version
        );
        if remote_version == local_version {
            println!("Money For Mima est déjà à jour.");
            return Ok(());
        }

        if ask {
            let mut answer = String::new();
            print!("Une nouvelle version de Money For Mima est disponible ({})\nSouhaitez-vous mettre à jour Money For Mima ? (O/n) : ",  remote_version);
            std::io::stdout().flush()?;
            std::io::stdin()
                .read_line(&mut answer)
                .expect("Impossible de lire votre saisie au clavier.");
            match answer.trim() {
                "" | "oui" | "o" => (),
                _ => {
                    println!("Abandon de la mise à jour.");
                    return Ok(());
                }
            }
        }

        self.update_version_in_file(Some(&remote_version)).await?;

        // download remote version for upgrade
        let mut downloaded_file = self.current_dir.as_ref().unwrap().join("money_for_mima");
        downloaded_file.set_extension(".zip");
        let download_url = self.get_download_url().await?;
        self.download_file(&downloaded_file, &download_url).await?;

        // specify the target of the extraction as the current directory
        let extraction_dir = self.current_dir.as_ref().unwrap().join("tmp");

        let upgrade_filename = PathBuf::from("upgrade".to_owned() + &self.exec_extension);
        // extract compressed archive caugth from the internet
        self.extract_zip(
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
