use std::{
    env, fs,
    io::{self, ErrorKind, Write},
    path::PathBuf,
};

use fs_extra::dir;

use shared_elements::{
    common_functions::{get_exec_extension, print_sep},
    common_functions_trait::{CommonFunctions, DataHashMap},
    custom_error::CustomError,
    shortcut_trait::ShortcutTrait,
    Error, ReturnValue,
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

        let mut executable_target = self
            .files_destination
            .to_owned()
            .unwrap()
            .join("money_for_mima");
        executable_target.set_extension(self.exec_extension.to_owned());

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
                    self.generate_filename_for_link(&dest_dir.0, Some("desktop"), "money_for_mima"),
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
                        "Dossier {} :\nLe raccourci {} existe déjà voulez-vous le remplacer ? (o / n) : ",
                        dirname,
                        file.to_owned().display()
                    );
                    std::io::stdout().flush()?;
                    std::io::stdin()
                        .read_line(&mut tmp)
                        .expect("Impossible de lire la saisie");
                    match tmp.to_string().trim() {
                        "o" | "" => Ok(true),
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

pub fn verify_target(target: &mut PathBuf) -> std::result::Result<(), Box<String>> {
    match fs::metadata(target.to_owned()) {
        Ok(v) => {
            if !v.is_file() {
                return Err(Box::from(
                    "Veuillez exécuter le fichier dans le dossier money_for_mima (1)"
                        .to_string(),
                ));
            }
            Ok(())
        }
        Err(e) => match e.kind() {
            ErrorKind::NotFound => {
                return Err(Box::from(
                    "Veuillez exécuter le fichier dans le dossier money_for_mimam le fichier n'a pas été trouvé (2)"
                        .to_string(),
                ))
            }
            ErrorKind::PermissionDenied => {
                return Err(Box::from(
                    "Vous ne possédez pas les permissions nécessaires pour accéder au fichier"
                        .to_string(),
                ))
            }

            _ => return Err(Box::from("Une erreur inconnue est survenue".to_string())),
        },
    }
}
pub fn choose_dir(
    dest_dir: &mut Option<PathBuf>,
    answer: &mut String,
    has_to_move_files: &mut bool,
) -> Result<ReturnValue, Box<String>> {
    let mut msg_default: &str = "Mes Documents";
    if dest_dir == &None {
        *dest_dir = dirs::document_dir();
    } else {
        msg_default = dest_dir.as_ref().unwrap().to_str().unwrap();
    }
    println!("{}", msg_default);
    let cur_dir = match env::current_dir() {
        Ok(v) => v,
        Err(_) => {
            return Err(Box::from(
                "Impossible de récupérer le dossier courant".to_string(),
            ))
        }
    };
    *answer = String::new();
    *has_to_move_files = true;
    print!(
        "Veuillez sélectionner le dossier d'installation des fichiers : \n
    1) Installer Money For Mima dans {} (par défaut)\n
    2) Installer Money For Mima dans le dossier courant\n
    3) Installer Money For Mima dans votre Bureau\n
    4) Poursuivre le programme\n
    5) Quitter le programme : ",
        msg_default
    );
    io::stdout().flush().unwrap();
    let max_v = 5;
    let min_v = 1;
    let mut associated_nb: u8 = 0;
    while answer.is_empty() || associated_nb < min_v || associated_nb > max_v {
        io::stdin()
            .read_line(answer)
            .expect("Impossible de lire la réponse");
        associated_nb = match answer.parse() {
            Ok(val) => val,
            Err(_) => {
                if answer == "\n" {
                    *answer = "1".to_string();
                    1
                } else {
                    println!("Veuillez founir une valeur entre {} et {}", min_v, max_v);
                    answer.clear();
                    0
                }
            }
        }
    }

    match associated_nb {
        1 => (),
        2 => *dest_dir = Some(cur_dir.to_owned()),
        3 => *dest_dir = dirs::desktop_dir(),
        4 => {
            *dest_dir = Some(cur_dir.to_owned());
            println!("Copie des fichiers passé");
            *has_to_move_files = false;
        }
        5 => return Ok(ReturnValue::Exit),
        _ => {
            return Err(Box::from(
                "Une erreur inconnue est survenue (1)".to_string(),
            ));
        }
    }

    if dest_dir.is_none() {
        let msg: &str;
        match associated_nb {
            1 => msg = "Impossible d'accéder au dossier Documents",
            3 => msg = "Impossible d'accéder à votre Bureau",
            _ => msg = "Une erreur inconnue est survenue (2)",
        }
        return Err(Box::from(String::from(msg)));
    }
    Ok(ReturnValue::NoError)
}

pub fn move_files_fn(
    dest_dir: &mut Option<PathBuf>,
    has_to_move_files: &mut bool,
    files_to_move: Vec<String>,
    folder_name: String,
) -> Result<ReturnValue, Box<String>> {
    let mut overwrite_files = false;

    if *has_to_move_files {
        // create folder money_for_mima
        dest_dir.as_mut().unwrap().push(folder_name);
        match std::fs::create_dir(dest_dir.as_ref().unwrap()) {
            Ok(_) => (),
            Err(e) => match e.kind() {
                ErrorKind::AlreadyExists => {
                    print_sep();
                    println!(
                        "Le dossier {} existe déjà",
                        dest_dir.as_deref().unwrap().display()
                    );
                    let mut answer: String = String::new();
                    print!(
                        "Que voulez vous faire : \n
    1) Quitter le programme (par défaut)\n
    2) Écraser les fichiers présents (seulement ceux qui seraient en doublon) : "
                    );
                    match std::io::stdout().flush() {
                        Ok(_) => (),
                        Err(_) => return Err(Box::from("Une erreur est survenue".to_string())),
                    }
                    match std::io::stdin().read_line(&mut answer) {
                        Ok(_) => (),
                        Err(_) => {
                            return Err(Box::from("Impossible de récupérer la saisie".to_string()));
                        }
                    }

                    match answer.as_str().trim_end() {
                        "2" => overwrite_files = true,
                        "1" | "" | _ => return Ok(ReturnValue::Exit),
                    }

                    answer.clear();
                    print_sep();
                    print!("Vous êtes sur le point de réécrire tous les fichiers présents dans le dossier money_for_mima, Êtes-vous sûr(e) de votre action ? (oui/non) ");
                    std::io::stdout().flush().unwrap();
                    match std::io::stdin().read_line(&mut answer) {
                        Ok(_) => (),
                        Err(_) => return Err(Box::from("Une erreur est survenue".to_string())),
                    }
                    match answer.as_str().trim_end() {
                        "oui" => (),
                        _ => return Ok(ReturnValue::Exit),
                    }
                }
                ErrorKind::PermissionDenied => {
                    return Err(Box::from(
                        "Vous ne possédez assez de permissions ".to_string(),
                    ))
                }

                _ => {
                    return Err(Box::from(
                        "Impossible de créer le dossier money_for_mima, erreur inconnue"
                            .to_string(),
                    ))
                }
            },
        }

        // move all files
        let mut options = dir::CopyOptions::new();
        if overwrite_files {
            println!("La réécriture des fichiers est activée");
            options.overwrite = true;
        }
        match fs_extra::copy_items(&files_to_move, dest_dir.as_ref().unwrap(), &options) {
            Ok(_) => {
                println!("Le déplacement des fichiers s'est fait correctement");
            }
            Err(e) => {
                eprintln!("{e}");
                return Err(Box::from(
                    "Le déplacement des fichiers a échoué".to_string(),
                ));
            }
        }
    }
    Ok(ReturnValue::NoError)
}

pub fn check_shortcut(answer: &mut String) -> Result<ReturnValue, Box<String>> {
    print_sep();
    print!("Voulez-vous effectuer un raccouci vers ce programme depuis votre Bureau ? (o / n, vous pourrez toujours accéder à ce paramètre en récexécutant le programme) : ");
    std::io::stdout().flush().unwrap();
    answer.clear();
    match io::stdin().read_line(answer) {
        Ok(_) => (),
        Err(_) => {
            return Err(Box::from(
                "Impossible de récupérer votre réponse".to_string(),
            ))
        }
    }
    match answer.as_str().trim_end() {
        "o" | "oui" => Ok(ReturnValue::NoError),
        _ => Ok(ReturnValue::Skip),
    }
}
