use std::{
    env,
    fs::{self, OpenOptions},
    io::Cursor,
    path::PathBuf,
    process::Command,
};

use fs_extra::dir;
use reqwest::Response;

use crate::shared_tools::{copy_dir_content, ReturnValue};

pub async fn upgrade(
    _files_to_move: Vec<String>,
    system: String,
) -> Result<ReturnValue, Box<String>> {
    let app_and_version_filename: String = format!("money_for_mima");
    let filename = PathBuf::from(format!("{}-{}.zip", app_and_version_filename, system));
    println!("{}", filename.display());

    // making a request to the server
    let resp: Response = match reqwest::get(format!(
        "https://leria-etud.univ-angers.fr/~ddasilva/money_for_mima/{}",
        filename.display()
    ))
    .await
    {
        Ok(v) => v,
        Err(e) => return Err(Box::from(e.to_string())),
    };

    // get the binary data of the compressed archive
    let zip_bytes = match resp.bytes().await {
        Ok(t) => t,
        Err(e) => return Err(Box::from(e.to_string())),
    };

    // preparation for the compressed archive
    let mut file_output = match OpenOptions::new()
        .write(true)
        .read(true)
        .create(true)
        .open(&filename)
    {
        Ok(f) => f,
        Err(e) => return Err(Box::from(e.to_string())),
    };

    // write everything in a file -> it is the zip file
    let mut cursor = Cursor::new(zip_bytes);
    if let Err(e) = std::io::copy(&mut cursor, &mut file_output) {
        remove_zip_file(&filename)?;
        return Err(Box::from(e.to_string()));
    };

    // specify the target of the extraction as the current directory
    let extraction_dir: PathBuf = match env::current_dir() {
        Ok(d) => d.join("tmp"),
        Err(_) => {
            remove_zip_file(&filename)?;
            return Err(Box::from(
                "Impossible de récupérer le dossier courant".to_string(),
            ));
        }
    };

    // extract compressed archive caugth from the internet
    match zip_extract::extract(cursor, &extraction_dir.as_path(), true) {
        Ok(_) => (),
        Err(_) => {
            remove_zip_file(&filename)?;
            return Err(Box::from(
                "Impossible de mettre à jour Money For Mima (1)".to_string(),
            ));
        }
    };

    let mut options = dir::CopyOptions::new();
    options.overwrite = true;

    // copy content of the extracted zip into the current folder to update everything
    match copy_dir_content(
        &extraction_dir,
        &env::current_dir().unwrap(),
        &vec!["upgrade", ".dart_tool"],
        &options,
    ) {
        Ok(_) => (),
        Err(e) => return Err(Box::from(e.to_string())),
    };

    remove_zip_file(&filename)?;

    if !PathBuf::from("install").exists() {
        return Err(Box::from(
            "Impossible de finir la mise à jour, le fichier install est manquant.".to_string(),
        ));
    }

    if let Err(_) = Command::new("./install").arg("--move").spawn() {
        return Err(Box::from(
            "Impossible de finir la mise à jour (1)".to_string(),
        ));
    }

    return Ok(ReturnValue::NoError);
}

fn remove_zip_file(filename: &PathBuf) -> Result<(), Box<String>> {
    // remove zip file
    match fs::remove_file(&filename) {
        Ok(_) => Ok(()),
        Err(_) => Err(Box::from(
            "Impossible de supprimer l'archive des mises à jour, ce message n'est pas important."
                .to_string(),
        )),
    }
}
