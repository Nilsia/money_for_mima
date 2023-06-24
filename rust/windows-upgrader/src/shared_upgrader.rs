use std::{
    env,
    fs::{self, OpenOptions},
    io::{self, Cursor},
    path::{Path, PathBuf},
};

use fs_extra::dir;
use reqwest::Response;

use crate::shared_tools::{copy_dir_content, get_extension, ReturnValue};

pub async fn upgrade(
    _files_to_move: Vec<String>,
    system: String,
) -> Result<ReturnValue, Box<String>> {
    let app_and_version_filename: String = format!("money_for_mima");
    let filename = PathBuf::from(format!("{}-{}.zip", app_and_version_filename, system));
    let extension = get_extension(&system);

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
    match extract_zip(
        &filename,
        &extraction_dir,
        [PathBuf::from("upgrade".to_owned() + extension)].to_vec(),
    ) {
        Ok(_) => (),
        Err(e) => {
            remove_zip_file(&filename)?;
            return Err(Box::from(
                format!("Impossible de mettre à jour Money For Mima (1) {e}").to_string(),
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

    if let Err(_e) = fs::remove_dir_all(&PathBuf::from("./tmp/")) {
        return Err(Box::from(
            "Impossible de supprimer le dossier temporaire, cette erreur n'est pas importante"
                .to_string(),
        ));
    }

    println!("Money For Mima est à jour.");

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

fn extract_zip(archive: &Path, target_dir: &Path, exceptions: Vec<PathBuf>) -> std::io::Result<()> {
    let file_archive = fs::File::open(archive)?;

    let mut archive = match zip::ZipArchive::new(file_archive) {
        Ok(v) => v,
        Err(e) => return Err(e.into()),
    };

    for i in 0..archive.len() {
        let mut file = match archive.by_index(i) {
            Ok(v) => v,
            Err(e) => return Err(e.into()),
        };
        let enclosed_name = match file.enclosed_name() {
            Some(v) => v,
            None => continue,
        };

        let outpath = target_dir.join(enclosed_name.to_owned());
        let filename_in_zip = match enclosed_name.to_str() {
            Some(v) => v,
            None => continue,
        }
        .to_string();

        if exceptions.contains(&PathBuf::from(&filename_in_zip)) {
            continue;
        }
        if filename_in_zip.ends_with('/') || filename_in_zip.ends_with("\\") {
            fs::create_dir_all(&outpath)?;
        } else {
            if let Some(p) = outpath.parent() {
                if !p.exists() {
                    fs::create_dir_all(p)?;
                }
            }
            let mut outfile = fs::File::create(&outpath)?;
            io::copy(&mut file, &mut outfile)?;
        }

        // Get and Set permissions
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;

            if let Some(mode) = file.unix_mode() {
                fs::set_permissions(&outpath, fs::Permissions::from_mode(mode))?;
            }
        }
    }

    Ok(())
}
