use std::{
    env, fs,
    io::{self, ErrorKind, Write},
    path::PathBuf,
};

use fs_extra::dir;

use crate::shared_tools::{print_sep, ReturnValue, check_version_and_files};

/// .
///
/// # Errors
///
/// This function will return an error if .
#[allow(dead_code)]
pub async fn copy_upgrade_and_remove(files: &Vec<String>) -> std::result::Result<(), Box<String>> {
    if !check_version_and_files(&files).await? {
        return Err(Box::from(
            "Vous semblez ne pas être au bon endroit, ou vous êtes déjà à la dernière version."
                .to_string(),
        ));
    }

    let file = PathBuf::from("./tmp/upgrade");
    if !file.exists() {
        return Err(Box::from(
            "Impossible de mettre à jour complètement Money For Mima (1)".to_string(),
        ));
    }

    if let Err(_) = fs::copy(&file.as_path(), &PathBuf::from("./upgrade")) {
        return Err(Box::from(
            "Impossible de mettre à jour complètement Money For Mima (2)".to_string(),
        ));
    }

    if let Err(_e) = fs::remove_dir_all(&PathBuf::from("./tmp/")) {
        return Err(Box::from(
            "Impossible de supprimer le dossier temporaire, cette erreur n'est pas importante"
                .to_string(),
        ));
    }

    println!("\nVotre logiciel Money For Mima est à jour");
    Ok(())
}
pub fn check_shorcut_existence(file: &PathBuf) -> Result<(), Box<String>> {
    let mut a = String::new();

    match fs::metadata(file.to_owned()) {
        Ok(v) => {
            if !v.is_dir() {
                print_sep();
                print!(
                    "Le raccourci {} existe déjà voulez-vous le remplacer ? (o / n) : ",
                    file.to_owned().display()
                );
                std::io::stdout().flush().unwrap();
                std::io::stdin()
                    .read_line(&mut a)
                    .expect("Impossible de lire la saisie");
                match a.to_string().trim() {
                    "o" => match fs::remove_file(file) {
                        Ok(_) => Ok(()),
                        Err(e) => return Err(Box::from(e.to_string())),
                    },
                    _ => {
                        println!("Aucune action n'a été effectuée.");
                        return Ok(());
                    }
                }
            } else {
                Err(Box::from(
                    "Le raccourci existe déjà sous forme de dossier, abandon".to_string(),
                ))
            }
        }
        Err(e) => match e.kind() {
            ErrorKind::PermissionDenied => Err(Box::from(
                "Vous ne posséder pas les permission nécéssaires".to_string(),
            )),
            ErrorKind::NotFound => Ok(()),
            _ => Err(Box::from("Une erreur inconnue est survenue".to_string())),
        },
    }
}
pub fn generate_files_for_links(
    src_dir: &PathBuf,
    dest_dir: &PathBuf,
    link: &mut PathBuf,
    target: &mut PathBuf,
    ext_exe: Option<&str>,
    ext_link: Option<&str>,
    link_filename: &str,
) -> std::io::Result<()> {
    let file_name = "money_for_mima".to_string();
    *target = src_dir.clone();
    target.push(file_name.to_owned());
    if ext_exe.is_some() {
        target.set_extension(ext_exe.unwrap());
    }

    *link = dest_dir.clone();
    link.push(link_filename);
    if ext_link.is_some() {
        link.set_extension(ext_link.unwrap());
    }

    Ok(())
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
        associated_nb = match answer.trim().parse() {
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
        2 => *dest_dir = Some(cur_dir.to_owned()),
        3 => *dest_dir = dirs::desktop_dir(),
        4 => {
            *dest_dir = Some(cur_dir.to_owned());
            println!("Copie des fichiers passé");
            *has_to_move_files = false;
        }
        5 => return Ok(ReturnValue::Exit),
        _ => {
            return Err(Box::from("Une erreur inconnue est survenue".to_string()));
        }
    }

    if dest_dir.is_none() {
        let msg: &str;
        match associated_nb {
            1 => msg = "Impossible d'accéder au dossier Documents",
            3 => msg = "Impossible d'accéder à votre Bureau",
            _ => msg = "Une erreur inconnue est survenue",
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
            Ok(_) => (),
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