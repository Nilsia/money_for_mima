use std::io::Result;
use std::path::PathBuf;

use mslnk::ShellLink;

use shared_tools::{
    check_file_existence, check_shortcut, choose_dir, do_all_files_exist, generate_files_for_links,
    move_files_fn, print_exit_program, verify_target, wait_for_input, ReturnValue,
};

pub mod shared_tools;

fn main() -> Result<()> {
    match sub_main() {
        Ok(_) => (),
        Err(_) => (),
    }
    println!(
        "La suppression des fichiers n'est pas automatique, vous pouvez maintenant les supprimer"
    );
    wait_for_input()?;
   
    Ok(())
}

fn sub_main() -> Result<()> {
    let mut dest_dir: Option<PathBuf> = None;
    let mut has_to_move_files: bool = true;
    let mut answer: String = String::new();

    match do_all_files_exist(get_files_to_move()) {
        Ok(_) => (),
        Err(_) => {
            eprintln!(
                "Tous les fichiers ne sont pas présents, veuillez retélécharger les fichier .ZIP"
            );
            return Ok(());
            //println!("Vos fichiers ne sont pas présents, voulez-vous les télécharger depuis le internet ?");
        }
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
    match move_files_fn(&mut dest_dir, &mut has_to_move_files, get_files_to_move(), "money_for_mima".to_string()) {
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
        String::from("./flutter_windows.dll"),
        String::from("./sqlite3.dll"),
        String::from("./sqlite3_flutter_libs_plugin.dll"),
    ];
}

fn generate_links(src_dir: &PathBuf, dest_dir: &PathBuf) -> std::result::Result<(), Box<String>> {
    let mut link: PathBuf = PathBuf::new();
    let mut target: PathBuf = PathBuf::new(); // source file

    match generate_files_for_links(
        src_dir,
        dest_dir,
        &mut link,
        &mut target,
        Some("exe"),
        Some("lnk"),
        "Money For Mima"
    ) {
        Ok(_) => (),
        Err(_) => return Err(Box::from("Impossible de créer le lien".to_string())),
    }

    verify_target(&mut target)?;

    check_file_existence(&link)?;

    let sl = match ShellLink::new(target) {
        Ok(v) => v,
        Err(e) => return Err(Box::from(e.to_string())),
    };

    match sl.create_lnk(link) {
        Ok(_) => Ok(()),
        Err(e) => Err(Box::from(e.to_string())),
    }
}
