use std::fs::OpenOptions;
use std::io::{Result, Write};

use std::fs;
use std::os::unix::prelude::PermissionsExt;
use std::path::PathBuf;
use std::process::Command;

use shared_tools::{
    check_file_existence, check_shortcut, choose_dir, do_all_files_exist, generate_files_for_links,
    move_files_fn, print_exit_program, print_sep, verify_target, wait_for_input, ReturnValue,
};

pub mod shared_tools;

fn main() -> Result<()> {
    match sub_main() {
        Ok(_) => (),
        Err(_) => (),
    }
    wait_for_input()?;
    println!(
        "La suppression des fichiers n'est pas automatique, vous pouvez maintenant les supprimer"
    );
    Ok(())
}

fn sub_main() -> Result<()> {
    let mut dest_dir: Option<PathBuf> = None;
    let mut has_to_move_files: bool = true;
    let mut answer: String = String::new();
    let folder_name: String;

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

    print_sep();
    // check if the user wants its folder to be hidden
    answer.clear();
    print!("Souhaitez-vous que le dossier soit caché ? (o / n) : ");
    std::io::stdout().flush()?;
    std::io::stdin().read_line(&mut answer)?;
    match answer.as_str().trim() {
        "o" | "oui" => {
            folder_name = ".money_for_mima".to_string();
        }
        _ => {
            folder_name = "money_for_mima".to_string();
        }
    }

    // move files
    match move_files_fn(
        &mut dest_dir,
        &mut has_to_move_files,
        get_files_to_move(),
        folder_name,
    ) {
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
    ];
}

fn generate_links(src_dir: &PathBuf, dest_dir: &PathBuf) -> std::result::Result<(), Box<String>> {
    let mut link: PathBuf = PathBuf::new();
    let mut target: PathBuf = PathBuf::new();

    match generate_files_for_links(
        src_dir,
        dest_dir,
        &mut link,
        &mut target,
        None,
        Some("desktop"),
        "money_for_mima",
    ) {
        Ok(_) => (),
        Err(_) => return Err(Box::from("Impossible de créer le lien".to_string())),
    }

    // check if target exists
    verify_target(&mut target)?;

    let mut lines = vec![
        "[Desktop Entry]",
        "Encoding=UTF-8",
        "Type=Application",
        "Terminal=false",
        "Name=Money For Mima",
    ];
    let assets = "/data/flutter_assets/assets";
    let b = format!("Exec={}", target.clone().display());
    let icon = format!("Icon={}{}/images/icons/icon.png", src_dir.display(), assets);
    lines.push(b.as_str());
    lines.push(&icon);

    check_file_existence(&link)?;

    let mut file = match OpenOptions::new()
        .create_new(true)
        .write(true)
        .read(true)
        .open(link.to_owned())
    {
        Ok(f) => f,
        Err(e) => return Err(Box::from(e.to_string())),
    };

    // write into the file
    for l in lines {
        match file.write(&l.as_bytes()) {
            Ok(size) => match size {
                0 => return Err(Box::from("Impossible d'écrire dans le fichier".to_string())),
                _ => (),
            },
            Err(e) => return Err(Box::from(e.to_string())),
        }
        file.write(&[10]).unwrap();
    }

    // set link executable
    let mut perm = match fs::metadata(link.to_owned()) {
        Ok(m) => m.permissions(),
        Err(e) => return Err(Box::from(e.to_string())),
    };
    perm.set_mode(0o0775);
    match fs::set_permissions(link.to_owned(), perm) {
        Ok(_) => (),
        Err(e) => return Err(Box::from(e.to_string())),
    }

    // trust the program
    let b = format!("{}", link.display().to_string().as_str());
    let mut cmd = Command::new("gio");
    cmd.args(["set", b.as_str(), "metadata::trusted", "true"]);

    match cmd.output() {
        Ok(_) => println!("Le raccourci a été généré avec succès"),
        Err(e) => return Err(Box::from(e.to_string())),
    }

    Ok(())
}
