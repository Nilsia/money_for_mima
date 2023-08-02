use crate::{custom_error::CustomError, log_level::LogLevel, Error};
use std::io::Write;
use std::{
    fs::{self, OpenOptions},
    io::Cursor,
    path::{Path, PathBuf},
};

#[async_trait::async_trait]
pub trait CommonFunctions {
    fn system(&self) -> &str;
    fn log_filename(&mut self) -> &mut Option<PathBuf>;
    fn files_container(&self) -> &Option<PathBuf>;

    /// Download the zip file that contain the files to run Money For Mima, the only element
    /// requested is the file path in which the zip file will be writen
    ///
    /// * `filepath`: the path of the file
    async fn download_file(&self, filename: &PathBuf) -> Result<(), Error> {
        let app_and_version_filename: &str = "money_for_mima";
        let remote_filename = PathBuf::from(format!(
            "{}-{}.zip",
            app_and_version_filename,
            self.system()
        ));
        let resp = reqwest::get(format!(
            "https://leria-etud.univ-angers.fr/~ddasilva/money_for_mima/{}",
            remote_filename.display()
        ))
        .await?;

        // get the binary data of the compressed archive
        let zip_bytes = resp.bytes().await?.to_vec();

        // preparation for the compressed archive
        let mut file_output = OpenOptions::new()
            .write(true)
            .read(true)
            .create(true)
            .open(&filename)?;

        // write everything in a file -> it is the zip file
        let mut cursor = Cursor::new(zip_bytes);
        if let Err(e) = std::io::copy(&mut cursor, &mut file_output) {
            fs::remove_file(&filename)?;
            return Err(Box::new(e));
        };
        Ok(())
    }

    #[cfg(unix)]
    fn extract_zip(
        &self,
        archive: &Path,
        target_dir: &Path,
        _exceptions: Vec<PathBuf>,
    ) -> Result<(), Error> {
        let file_archive = fs::File::open(archive)?;
        zip_extract::extract(&file_archive, target_dir, true)?;
        Ok(())
    }

    #[cfg(target_os = "windows")]
    fn extract_zip(
        &self,
        archive: &Path,
        target_dir: &Path,
        exceptions: Vec<PathBuf>,
    ) -> std::io::Result<()> {
        let file_archive = fs::File::open(archive)?;

        let mut archive = match zip::ZipArchive::new(file_archive) {
            Ok(v) => v,
            Err(e) => {
                return Err(e.into());
            }
        };

        for i in 0..archive.len() {
            let mut file = match archive.by_index(i) {
                Ok(v) => v,
                Err(e) => {
                    println!("hi i am here");
                    return Err(e.into());
                }
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

    fn log_trait(
        &mut self,
        message: &dyn ToString,
        level: LogLevel,
        program: &str,
    ) -> Result<(), Error> {
        if self.log_filename().is_none() {
            if self.files_container().is_none() {
                return Err(Box::new(CustomError::UnkownError));
            }
            *self.log_filename() = Some(self.files_container().as_ref().unwrap().join("exec.log"));
        }

        let date = chrono::offset::Utc::now();
        let mut log_file = OpenOptions::new()
            .append(true)
            .open(self.log_filename().as_ref().unwrap())?;
        log_file.write_all(
            &vec![
                date.to_string(),
                program.to_string(),
                level.to_string(),
                message.to_string(),
            ]
            .join(" | ")
            .as_bytes(),
        )?;
        Ok(())
    }

}
