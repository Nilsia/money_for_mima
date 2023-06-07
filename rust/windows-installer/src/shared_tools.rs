use std::{
    fs, io,
    path::{Path, PathBuf},
};

pub enum ReturnValue {
    NoError,
    Skip,
    Exit,
}

pub const VERSION: &str = "0.9.0";

/// return true if version is different and all files are present
pub async fn check_version_and_files(files: &Vec<String>) -> Result<bool, Box<String>> {
    Ok(get_version().await? != VERSION && do_all_files_exist(files))
}

pub async fn get_version() -> Result<String, Box<String>> {
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
) -> io::Result<()> {
    let mut folder_testing = fs::read_dir(&from)?;
    if folder_testing.next().is_none() {
        fs::create_dir_all(to)?;
        return Ok(());
    }

    match fs::read_dir(&from) {
        Ok(folder) => {
            for file_res in folder {
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
                            match fs_extra::dir::copy(f_path, to, options) {
                                Ok(_) => (),
                                Err(e) => {
                                    eprintln!("Une erreur est survenue : {}", e);
                                }
                            };
                        } else if t.is_file() {
                            if let Err(e) = fs::copy(f_path, to.join(filename)) {
                                eprintln!("{} : {}", filename, e);
                            }
                        }
                    }
                    Err(_) => (),
                }
            }
        }
        Err(e) => return Err(e),
    };

    Ok(())
}

pub fn print_sep() {
    println!("\n==========-==========-==========\n")
}
