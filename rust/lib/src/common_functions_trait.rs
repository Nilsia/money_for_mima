use octocrab::models;
use regex::Regex;
use serde_json::{json, Value};

use crate::{custom_error::CustomError, log_level::LogLevel, Error};
use crate::{CONFIG_FILE_NAME, VERSION};
use std::collections::HashMap;
use std::io::ErrorKind;
use std::{
    fs::{self, OpenOptions},
    io::{Cursor, Write},
    path::{Path, PathBuf},
};

pub type DataHashMap = HashMap<String, String>;

// #[async_trait::async_trait]
#[async_trait::async_trait]
pub trait CommonFunctions {
    fn system(&self) -> &str;
    fn log_filename(&mut self) -> Option<&mut PathBuf>;
    fn files_container(&self) -> Option<&PathBuf>;
    fn remote_data(&mut self) -> Option<&mut DataHashMap>;
    fn exec_extension(&self) -> &str;
    fn insert_remote_data(&mut self, data: DataHashMap);
    fn insert_logfilename(&mut self, filename: PathBuf);

    /// Download the zip file that contain the files to run Money For Mima, the only element
    /// requested is the file path in which the zip file will be writen
    ///
    /// * `filepath`: the path of the file
    async fn download_file(&self, filename: &PathBuf, download_url: &str) -> Result<(), Error> {
        let resp = reqwest::get(download_url).await?;

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
        use std::io;
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
            let log_filename = self.files_container().unwrap().join("exec.log");
            self.insert_logfilename(log_filename);
        }

        let date = chrono::offset::Utc::now();
        let mut log_file = OpenOptions::new()
            .append(true)
            .create(true)
            .open(self.log_filename().unwrap())?;
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

    /// set self.remote_config for future use. After this call self.remote_data cannot be None, if
    /// already set return the value get before
    async fn get_remote_data(&mut self) -> Result<&mut DataHashMap, Error> {
        if self.remote_data().is_none() {
            self.insert_remote_data(DataHashMap::new());
            let octocrab = octocrab::instance();
            let last_release_tmp = octocrab
                .repos("Nilsia", "money_for_mima")
                .releases()
                .list()
                .per_page(1)
                .send()
                .await?;
            let last_release: &models::repos::Release = match last_release_tmp.items.get(0) {
                Some(v) => v,
                None => return Err(Box::new(CustomError::CannotFetchRemoteData)),
            };

            // insert version into remote data
            self.remote_data()
                .unwrap()
                .insert("version".to_string(), last_release.tag_name.to_owned());

            let package_regex = Regex::new(
                format!(
                    "{}-money_for_mima-{}.zip$",
                    self.system(),
                    last_release.tag_name
                )
                .as_str(),
            )?;

            let download_url: Vec<String> = last_release
                .assets
                .iter()
                .filter_map(|asset| {
                    package_regex
                        .is_match(asset.browser_download_url.as_str())
                        .then_some(asset.browser_download_url.as_str().to_owned())
                })
                .collect::<Vec<String>>();
            if download_url.is_empty() {
                return Err(Box::new(CustomError::CannotGetRemotePackage));
            }

            // insert download_url into remote data for later use
            self.remote_data().unwrap().insert(
                "download_url".to_string(),
                download_url.get(0).unwrap().as_str().to_string(),
            );
        }
        Ok(self.remote_data().unwrap())
    }

    // async fn manage_new_data(&mut self) -> Result<(), Error> {
    //     // get data local an remote
    //     let _: &mut DataHashMap = self.get_remote_data().await?;
    //     let mut local_config: Value = self.load_config_file()?;
    //
    //     let mut changed = false;
    //
    //     // save data into new file
    //     if changed {
    //         self.save_config_file(&local_config)?;
    //     }
    //     Ok(())
    // }

    async fn update_version_in_file(&mut self, remote_version: Option<&str>) -> Result<(), Error> {
        let remote_version = Value::String(
            remote_version
                .unwrap_or(&self.get_remote_version().await?)
                .to_string(),
        );
        let mut local_config = self.load_config_file()?;
        if local_config.get("version").is_none() {
            local_config["version"] = remote_version;
        } else {
            *local_config.get_mut("version").unwrap() = remote_version;
        }
        self.save_config_file(&local_config)?;
        Ok(())
    }

    fn save_config_file(&self, data: &Value) -> Result<(), Error> {
        let mut config_file = OpenOptions::new()
            .write(true)
            .create(true)
            .open(CONFIG_FILE_NAME)?;
        Ok(config_file.write_all(data.to_string().as_bytes())?)
    }

    /// load config from local file and if it does not exist, file is created with the version that
    /// the program holds
    fn load_config_file(&self) -> Result<Value, Error> {
        let config_filename = PathBuf::from(self.files_container().unwrap().join(CONFIG_FILE_NAME));
        let config_file = match OpenOptions::new()
            .read(true)
            .create(false)
            .open(&config_filename)
        {
            Ok(f) => f,
            Err(e) => match e.kind() {
                ErrorKind::NotFound => {
                    let mut f = OpenOptions::new()
                        .write(true)
                        .create(true)
                        .open(&config_filename)?;
                    let data = json!({ "version": VERSION });
                    f.write_all(data.to_string().as_bytes())?;
                    return Ok(data);
                }
                _ => return Err(Box::new(e)),
            },
        };
        Ok(serde_json::from_reader(config_file)?)
    }

    /// get remote version from data caught or directly from internet, self.remote_data is updated
    async fn get_remote_version(&mut self) -> Result<String, Error> {
        match &self.get_remote_data().await?.get("version") {
            Some(v) => Ok(v.to_string()),
            None => Err(Box::new(CustomError::CannotGetRemoteVersion)),
        }
    }

    async fn get_local_version(&self, local_config: Option<&Value>) -> Result<String, Error> {
        match local_config
            .unwrap_or(&self.load_config_file()?)
            .get("version")
        {
            Some(version) => match version.as_str() {
                Some(s) => Ok(s.to_string()),
                None => Err(Box::new(CustomError::CannotGetLocalVersion)),
            },
            None => Err(Box::new(CustomError::CannotGetLocalVersion)),
        }
    }

    /// get remote package download_url caught from remote data of directly from the internet,
    /// self.remote_data is updated
    async fn get_download_url(&mut self) -> Result<String, Error> {
        match &self.get_remote_data().await?.get("download_url") {
            Some(v) => Ok(v.to_string()),
            None => Err(Box::new(CustomError::CannotGetRemotePackage)),
        }
    }
}
