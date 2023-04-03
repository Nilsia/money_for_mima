use std::io::Result;

use std::os::unix::fs::symlink;
use std::path::PathBuf;

use shared_tools::{verify_target, do_all_files_exist};
use shared_tools::{check_shortcut, generate_files_for_links};

pub mod shared_tools;
use crate::shared_tools::{choose_dir, move_files_fn, print_exit_program, ReturnValue};

fn main() -> Result<()> {
    let mut dest_dir: Option<PathBuf> = None;
    let mut has_to_move_files: bool = true;
    let mut answer: String = String::new();

    match do_all_files_exist(get_files_to_move()) {
        Ok(_) => (),
        Err(_) => {
            eprintln!("Tous les fichiers ne sont pas présents, veuillez retélécharger les fichier .ZIP");
            return Ok(());
            //println!("Vos fichiers ne sont pas présents, voulez-vous les télécharger depuis le internet ?");
        },
    }

    match choose_dir(&mut dest_dir, &mut answer, &mut has_to_move_files) {
        Ok(return_val) => match return_val {
            ReturnValue::NoError => (),
            ReturnValue::Exit => {
                print_exit_program();
                return Ok(());
            }
            ReturnValue::Skip => (),
        },
        Err(v) => {
            eprintln!("{}", v.to_string());
            return Ok(());
        }
    }

    // move files
    match move_files_fn(&mut dest_dir, &mut has_to_move_files, get_files_to_move()) {
        Ok(val) => match val {
            ReturnValue::NoError => (),
            ReturnValue::Exit => {
                print_exit_program();
                return Ok(());
            }
            ReturnValue::Skip => (),
        },
        Err(e) => {
            eprintln!("{e}");
            return Ok(());
        }
    }
    // check if user wants a shorcut
    match check_shortcut(&mut answer) {
        Ok(val) => match val {
            ReturnValue::NoError => {
                match generate_links(
                    &dest_dir.unwrap(),
                    &match dirs::desktop_dir() {
                        Some(v) => v,
                        None => {
                            eprintln!("Impossible d'accéder à votre Bureau");
                            return Ok(());
                        }
                    },
                ) {
                    Ok(_) => (),
                    Err(e) => {
                        eprintln!("{e}");
                        return Ok(());
                    }
                }
            }
            ReturnValue::Skip => println!("Création du raccouci passée"),
            ReturnValue::Exit => {
                print_exit_program();
                return Ok(());
            }
        },
        Err(e) => {
            eprintln!("{}", e);
            return Ok(());
        }
    }

    Ok(())
}

fn get_files_to_move() -> Vec<String> {
    return vec![
        String::from("./data/"),
        String::from("./lib/"),
        String::from("./money_for_mima"),
        String::from("./install"),
        String::from("./.dart_tool/")
    ];
}

fn generate_links(src_dir: &PathBuf, dest_dir: &PathBuf) -> std::result::Result<(), Box<String>> {
    let mut link: PathBuf = PathBuf::new();
    let mut target: PathBuf = PathBuf::new();
    let mut mfm_dir: PathBuf = src_dir.clone().to_path_buf();
    mfm_dir.push("money_for_mima");

    match generate_files_for_links(&mfm_dir, dest_dir, &mut link, &mut target, None) {
        Ok(_) => (),
        Err(_) => return Err(Box::from("Impossible de créer le lien".to_string())),
    }

    verify_target(&mut target)?;

    match symlink(target, link) {
        Ok(_) => Ok(()),
        Err(e) => Err(Box::from(e.to_string())),
    }

}
