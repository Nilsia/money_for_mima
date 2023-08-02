use crate::{Error, VERSION};
use std::{
    fs, io,
    path::{Path, PathBuf},
};
pub fn get_exec_extension() -> String {
    if cfg!(unix) {
        return "".to_string();
    } else if cfg!(windows) {
        return ".exe".to_string();
    } else {
        return "".to_string();
    }
}
pub fn get_system() -> String {
    return String::from(if cfg!(windows) { "windows" } else { "linux" });
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
