use std::{
    env, fs,
    io::{ErrorKind, Write},
    path::PathBuf,
};

use shared_elements::{
    common_functions::{get_exec_extension, print_sep},
    common_functions_trait::{CommonFunctions, DataHashMap},
    custom_error::CustomError,
    shortcut_trait::ShortcutTrait,
    Error,
};

pub struct Installer {
    files_destination: Option<PathBuf>,
    current_dir: Option<PathBuf>,
    home_dir: Option<PathBuf>,
    system: String,
    exec_extension: String,
    log_filename: Option<PathBuf>,
    remote_data: Option<DataHashMap>,
}

impl ShortcutTrait for Installer {}

impl CommonFunctions for Installer {
    fn system(&self) -> &str {
        &self.system
    }

    fn log_filename(&mut self) -> Option<&mut PathBuf> {
        self.log_filename.as_mut()
    }

    fn files_container(&self) -> Option<&PathBuf> {
        self.files_destination.as_ref()
    }

    fn remote_data(&mut self) -> Option<&mut DataHashMap> {
        self.remote_data.as_mut()
    }

    fn exec_extension(&self) -> &str {
        &self.exec_extension
    }

    fn insert_remote_data(&mut self, data: DataHashMap) {
        let _ = self.remote_data.insert(data);
    }

    fn insert_logfilename(&mut self, filename: PathBuf) {
        let _ = self.log_filename.insert(filename);
    }
}

impl Installer {
    pub fn new() -> Installer {
        let system = String::from(if cfg!(windows) { "windows" } else { "linux" });
        let exec_extension = get_exec_extension();
        Installer {
            files_destination: None,
            current_dir: None,
            home_dir: dirs::home_dir(),
            system,
            exec_extension,
            log_filename: None,
            remote_data: None,
        }
    }

    pub fn log(
        &mut self,
        message: &dyn ToString,
        level: shared_elements::log_level::LogLevel,
    ) -> Result<(), Error> {
        self.log_trait(message, level, "INSTALLER")
    }

    pub fn set_files_destination(&mut self) -> &Option<PathBuf> {
        self.files_destination = dirs::data_local_dir();
        if self.files_destination.is_none() {
            self.files_destination = dirs::data_dir();
        }
        if self.files_destination.is_none() {
            self.files_destination = dirs::config_local_dir();
        }
        self.files_destination
            .as_mut()
            .unwrap()
            .push("money_for_mima");
        &self.files_destination
    }

    pub async fn run_installation(&mut self) -> Result<(), Error> {
        if self.files_destination.is_none() {
            self.set_files_destination();
        }
        self.current_dir = Some(env::current_dir()?);
        if self.home_dir.is_none() {
            return Err(Box::new(CustomError::HomeDirNotFound));
        }

        {
            // get new path if not found or if it is no ok with the folder selected
            let path: Option<PathBuf> = self.confirm_or_request_new_path();
            if path.is_some() {
                println!(
                    "Les fichiers seront donc installés dans le dossier {}",
                    path.as_ref().unwrap().display()
                );
                self.files_destination = Some(path.unwrap().join("money_for_mima"));
            }
            fs::create_dir_all(self.files_destination.as_ref().unwrap())?;
        }

        let mut zip_path = self.files_destination.as_ref().unwrap().to_owned();
        zip_path.push("money_for_mima");
        zip_path.set_extension("zip");

        let download_url = self.get_download_url().await?;
        self.download_file(&zip_path, &download_url).await?;
        self.extract_zip(&zip_path, &self.files_destination.as_ref().unwrap(), vec![])?;
        fs::remove_file(&zip_path)?;
        drop(zip_path);

        let executable_target = self
            .files_destination
            .to_owned()
            .unwrap()
            .join("money_for_mima".to_owned() + &self.exec_extension);

        // this function to create file if if does not exist
        self.load_config_file()?;

        self.generate_links(&executable_target, self.get_shorcut_dirs())?;

        print_sep();
        println!("Money For Mima a été installée. Vous pouvez maintenant l'utiliser.");

        Ok(())
    }

    fn confirm_or_request_new_path(&mut self) -> Option<PathBuf> {
        if self.files_destination.is_some() {
            println!(
                "Les fichiers vont être installés dans le dossier suivant : {}, \nCela vous convient-il ? (Si oui taper la touche ENTRER, sinon fournissez le chemin d'installation)",
                self.files_destination
                .as_ref()
                .unwrap()
                .display()
                );
        } else {
            println!("Nous n'avons pas pu trouver de dossier d'installation automatique, veuillez fournir un dossier (Valeur par défaut : le dossier courant (.), taper sur ENTRER pour le sélectionner)");
            self.files_destination = self.current_dir.to_owned();
        }
        let mut answer = String::new();
        let mut new_path: PathBuf;

        // confirm path and get new one if it is not ok
        loop {
            answer.clear();
            std::io::stdin()
                .read_line(&mut answer)
                .expect("Une erreur est survenue lors de la lecture au clavier");
            new_path = PathBuf::from(answer.to_owned());
            if answer.trim().is_empty() {
                return None;
            } else if new_path.try_exists().unwrap_or(false) {
                return Some(new_path);
            } else {
                println!("Le dossier fourni n'est pas valide. Veuillez réessayer.");
            }
        }
    }

    #[cfg(target_os = "linux")]
    /// Genrate shortcuts for app
    ///
    /// * `target_file`: the folder in which the orginal file is located
    /// * `dest_dir`: the folder in which the shortcut should be
    fn generate_links(
        &self,
        target_file: &PathBuf,
        dest_dirs: Vec<(Option<PathBuf>, &str)>,
    ) -> std::result::Result<(), Error> {
        if dest_dirs.is_empty() {
            return Ok(());
        }

        let links_names = self.generate_links_name_from_dirs(Some(dest_dirs).as_ref());

        let mut return_value: Result<(), Error> = Ok(());

        let src_dir = target_file.parent().unwrap();
        // check if target exists
        // verify_target(&mut target)?;

        let mut lines: Vec<&str> = vec![
            "[Desktop Entry]",
            "Encoding=UTF-8",
            "Type=Application",
            "Terminal=false",
            "Name=Money For Mima",
        ];
        let assets = "/data/flutter_assets/assets";
        let target_file_exec = format!("Exec={}", target_file.to_owned().display());
        let src_dir_path: String = format!("Path={}", src_dir.to_str().unwrap());
        let icon: String = format!("Icon={}{}/images/icons/icon.png", src_dir.display(), assets);
        lines.extend_from_slice(&[
            src_dir_path.as_str(),
            target_file_exec.as_str(),
            icon.as_str(),
        ]);
        for link_name in &links_names {
            if let Err(e) = self.manage_link_name_tuple(link_name, &lines) {
                return_value = Err(e);
                eprintln!(
                    "Une erreur est survenue lors de la génération du raccourci {}",
                    &link_name.0.display()
                );
                continue;
            }
        }

        return_value
    }

    #[cfg(target_os = "linux")]
    fn manage_link_name_tuple(
        &self,
        data: &(PathBuf, &str),
        file_lines: &Vec<&str>,
    ) -> Result<(), Error> {
        use std::{fs::OpenOptions, os::unix::prelude::PermissionsExt, process::Command};

        let link: &PathBuf = &data.0;
        if !self.check_shorcut_substitution(data)? {
            return Ok(());
        }
        if link.try_exists().unwrap_or(false) {
            fs::remove_file(link)?;
        }

        let mut file = OpenOptions::new()
            .create_new(true)
            .write(true)
            .read(true)
            .open(&link)?;

        // write into the file
        for l in file_lines {
            if file.write(&l.as_bytes())? == 0 {
                return Err(Box::from("Impossible d'écrire dans le fichier".to_string()));
            }
            file.write(&[10])?;
        }

        // set link executable
        let mut perm = fs::metadata(link.to_owned())?.permissions();
        perm.set_mode(0o0775);
        fs::set_permissions(link.to_owned(), perm)?;

        // trust the program
        let link_str: String = link.display().to_string();
        let mut cmd = Command::new("gio");
        cmd.args(["set", &link_str, "metadata::trusted", "true"]);

        cmd.output()?;
        println!(
            "Un raccourci a été effectué dans le dossier {} avec succès",
            link.display()
        );
        Ok(())
    }

    #[cfg(target_os = "windows")]
    fn generate_links(
        &self,
        target_file: &PathBuf,
        dest_dirs: Vec<(Option<PathBuf>, &str)>,
    ) -> std::result::Result<(), Error> {
        let mut ee: Result<(), Error> = Ok(());
        let links_names: Vec<(PathBuf, &str)> = dest_dirs
            .iter()
            .filter(|dest_dir| dest_dir.0.is_some())
            .map(|dest_dir| (dest_dir.0.as_ref().unwrap(), dest_dir.1))
            .map(|dest_dir| {
                (
                    self.generate_filename_for_link(&dest_dir.0, Some("lnk"), "Money For Mima"),
                    dest_dir.1,
                )
            })
            .collect();

        for link_name in &links_names {
            if let Err(e) = self.manage_link_name_tuple(link_name, target_file) {
                ee = Err(e);
            }
        }

        ee
    }

    #[cfg(target_os = "windows")]
    fn manage_link_name_tuple(
        &self,
        data: &(PathBuf, &str),
        target_file: &PathBuf,
    ) -> Result<(), Error> {
        use mslnk::ShellLink;
        if !self.check_shorcut_substitution(data)? {
            return Ok(());
        }
        ShellLink::new(target_file)?.create_lnk(&data.0)?;
        println!(
            "Un raccourci a été effectué dans le dossier {} avec succès",
            data.0.display()
        );
        Ok(())
    }

    /// Check if the shortcut located at `data` already exists if true, ask for replacing
    ///
    /// * `data` the path of the shortcut
    pub fn check_shorcut_substitution(&self, data: &(PathBuf, &str)) -> Result<bool, Error> {
        let mut tmp = String::new();
        let file = &data.0;
        let dirname = data.1;

        match fs::metadata(file.to_owned()) {
            Ok(v) => {
                if !v.is_dir() {
                    print_sep();
                    print!(
                        "Dossier {} :\nLe raccourci {} existe déjà voulez-vous le remplacer ? (O / n) : ",
                        dirname,
                        file.to_owned().display()
                    );
                    std::io::stdout().flush()?;
                    std::io::stdin()
                        .read_line(&mut tmp)
                        .expect("Impossible de lire la saisie");
                    match tmp.to_string().trim() {
                        "o" | "" | "oui" => Ok(true),
                        _ => {
                            println!("Aucune action n'a été effectuée.");
                            return Ok(false);
                        }
                    }
                } else {
                    Err(Box::from(
                        "Le raccourci existe déjà sous forme de dossier, abandon".to_string(),
                    ))
                }
            }
            Err(e) => match e.kind() {
                ErrorKind::PermissionDenied => Err(Box::new(CustomError::NotEnoughPermission)),
                ErrorKind::NotFound => Ok(true),
                _ => Err(Box::new(CustomError::UnkownError)),
            },
        }
    }
}
