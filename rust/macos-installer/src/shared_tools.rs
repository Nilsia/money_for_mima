use std::{
    env::current_dir,
    io::{self, ErrorKind, Write},
    path::{PathBuf, Path}, fs::metadata,
};

use fs_extra::dir;

pub enum ReturnValue {
    NoError,
    Skip,
    Exit,
}

pub const VERSION: &str = "0.9.0";

pub fn choose_dir(
    dest_dir: &mut Option<PathBuf>,
    answer: &mut String,
    has_to_move_files: &mut bool,
) -> Result<ReturnValue, Box<String>> {
    //let vec_files: Vec<&str> = vec!["money_for_mima."];
    //println!("Nous déplaçons tous les fichiers dans le dossier Documents/money_for_mima");
    *dest_dir = dirs::document_dir();
    let cur_dir = match current_dir() {
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
        1) Installer Money For Mima dans le dossier Mes Documents (par défaut)\n
        2) Installer Money For Mima dans le dossier courant\n
        3) Installer Money For Mima dans votre Bureau\n
        4) Poursuivre le programme\n
        5) Quitter le programme : "
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
                    1
                } else {
                    println!("Veuillez founir une valeur entre {} et {}", min_v, max_v);
                    0
                }
            }
        }
    }

    match associated_nb {
        1 => *dest_dir = dirs::document_dir(),
        2 => *dest_dir = Some(cur_dir.to_owned()),
        3 => *dest_dir = dirs::desktop_dir(),
        4 => {
            *dest_dir = Some(cur_dir.to_owned());
            println!("Déplacement des fichiers passé");
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
    files_to_move: Vec<String>
) -> Result<ReturnValue, Box<String>> {

    let mut overwrite_files = false;

    if *has_to_move_files {
        // create folder money_for_mima
        dest_dir.as_mut().unwrap().push("money_for_mima");
        match std::fs::create_dir(dest_dir.as_ref().unwrap()) {
            Ok(_) => (),
            Err(e) => {
                /* let parent_dir = dest_dir.as_ref()
                    .unwrap()
                    .parent().as_ref()
                    .unwrap()
                    .to_str()
                    .unwrap().clone(); */
                
                    match e.kind() {
                        ErrorKind::AlreadyExists => {
                            println!("Le dossier money_for_mima existe déjà");
                            let mut answer: String = String::new();
                            print!("Que voulez vous faire : \n
                            1) Quitter le programme (par défaut)\n
                            2) Écraser les fichiers présents (seulement ceux qui seraient en doublon) : ");
                            match std::io::stdout().flush() {
                                Ok(_) => (),
                                Err(_) => return Err(Box::from("Une erreur est survenue".to_string())),
                            }
                             match std::io::stdin().read_line(&mut answer) {
                                Ok(_) => (),
                                Err(_) => {
                                    return Err(Box::from("Impossible de récupérer la saisie".to_string()));
                                },
                            }

                            match answer.as_str().trim_end() {
                                "2" => overwrite_files = true,
                                "1" | "" | _=>  return Ok(ReturnValue::Exit),

                            }

                            answer.clear();
                            print!("Vous êtez sur le point de réécrire tous les fichiers présents dans le dossier money_for_mima, Êtes-vous sûr(e) de votre action ? (oui/non) ");
                            std::io::stdout().flush().unwrap();
                            match std::io::stdin().read_line(&mut answer) {
                                Ok(_) => (),
                                Err(_) => return Err(Box::from("Une erreur est survenue".to_string())),
                            }
                            match answer.as_str().trim_end() {
                                "oui" => (),
                                _ => return Ok(ReturnValue::Exit)
                            }

                        },
                        ErrorKind::PermissionDenied => 
                        return Err(Box::from("Vous ne possédez pas les permissions nécessaires pour créer un dossier money_for_mima ".to_string())),
                        
                        _ => return Err(Box::from("Impossible de créer le dossier money_for_mima, erreur inconnue".to_string())),
                    }
                /* return Err(Box::from(format!(
                    "Impossible de créer le dossier money_for_mima dans le dossier {}",

                ))); */
            }
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

pub fn print_exit_program() {
    println!("Fermeture du programme d'installation");
}

pub fn generate_files_for_links(
    src_dir: &PathBuf,
    dest_dir: &PathBuf,
    link: &mut PathBuf,
    target: &mut PathBuf,
) -> std::io::Result<()> {
    let file_name = "money_for_mima".to_string();
    *target = src_dir.clone();
    target.push(file_name.to_owned());
    *link = dest_dir.clone();
    link.push(file_name);
    Ok(())
}

pub fn verify_target(target: &mut PathBuf) -> std::result::Result<(), Box<String>> {
    print!("{}", target.display());
    match metadata(target.to_owned()) {
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
                    "Veuillez exécuter le fichier dans le dossier money_for_mima (2)"
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

pub fn do_all_files_exist(files_to_move: Vec<String>) -> std::io::Result<()> {
    let mut path: &Path;
    for file in files_to_move {
        path = Path::new(&file);
        if !path.exists() {
        
         return Err(ErrorKind::NotFound.into());
        }
    }
    Ok(())
}