use std::path::PathBuf;

pub trait ShortcutTrait {
    fn get_shorcut_dirs(&self) -> Vec<(Option<PathBuf>, &str)> {
        let desktop_dir = dirs::desktop_dir();
        let mut applications_dir: Option<PathBuf> = None;
        if cfg!(unix) {
            applications_dir = Some(
                dirs::home_dir()
                    .unwrap_or("".into())
                    .join(".local/share/applications/"),
            );
            if !applications_dir
                .as_ref()
                .unwrap()
                .try_exists()
                .unwrap_or(false)
            {
                applications_dir = None;
            }
        }
        return vec![
            (
                applications_dir,
                "Dossier de raccourci pour les applications",
            ),
            (desktop_dir, "Bureau"),
        ];
    }

    fn generate_links_name_from_dirs<'a>(
        &'a self,
        dest_dirs: Option<&Vec<(Option<PathBuf>, &'a str)>>,
    ) -> Vec<(PathBuf, &str)> {
        return dest_dirs
            .unwrap_or(&self.get_shorcut_dirs())
            .iter()
            .filter(|dest_dir| dest_dir.0.is_some())
            .map(|dest_dir| (dest_dir.0.as_ref().unwrap(), dest_dir.1))
            .map(|dest_dir| {
                (
                    self.generate_filename_for_link(&dest_dir.0, Some("desktop"), "money_for_mima"),
                    dest_dir.1,
                )
            })
            .collect();
    }

    /// Generate the link for Money For Mima, in the folder given, with the filename given and the
    /// extension given
    ///
    /// * `dest_dir`: the folder where the shortcut will be
    /// * `ext_link`: the shortcut extension
    /// * `link_filename`: the shortcu file name
    fn generate_filename_for_link(
        &self,
        dest_dir: &PathBuf,
        ext_link: Option<&str>,
        link_filename: &str,
    ) -> PathBuf {
        let mut link = dest_dir.join(link_filename);
        if ext_link.is_some() {
            link.set_extension(ext_link.unwrap());
        }
        link
    }
}
