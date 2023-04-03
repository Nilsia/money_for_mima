use std::io::Result;
use std::path::PathBuf;

use mslnk::ShellLink;

use shared_tools::verify_target;
use shared_tools::{check_shortcut, generate_files_for_links};

pub mod shared_tools;
use crate::shared_tools::{choose_dir, move_files_fn, print_exit_program, ReturnValue};

fn main() -> Result<()> {
    let mut dest_dir: Option<PathBuf> = None;
    let mut has_to_move_files: bool = true;
    let mut answer: String = String::new();

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
        String::from("./money_for_mima.exe"),
        String::from("./install.exe"),
    ];
}

fn generate_links(src_dir: &PathBuf, dest_dir: &PathBuf) -> std::result::Result<(), Box<String>> {
    let mut link: PathBuf = PathBuf::new();
    let mut target: PathBuf = PathBuf::new();
    let mut mfm_dir: PathBuf = src_dir.clone().to_path_buf();
    mfm_dir.push("money_for_mima");

    match generate_files_for_links(&mfm_dir, dest_dir, &mut link, &mut target) {
        Ok(_) => (),
        Err(_) => return Err(Box::from("Impossible de créer le lien".to_string())),
    }

    verify_target(&mut target)?;

    let sl = match ShellLink::new(target) {
        Ok(v) => v,
        Err(e) => return Err(Box::from(e.to_string()))
    };

    match sl.create_lnk(link) {
        Ok(_) => Ok(()),
        Err(e) => Err(Box::from(e.to_string())),
    }
}
