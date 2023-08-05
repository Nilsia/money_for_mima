use std::{env, fs, io::Write, path::PathBuf};

use shared_elements::{
    shortcut_trait::ShortcutTrait, Error,
};

struct Uninstaller {
    current_dir: Option<PathBuf>,
}

impl ShortcutTrait for Uninstaller {}

impl Uninstaller {
    fn new() -> Uninstaller {
        Uninstaller { current_dir: None }
    }

    fn run_deletion(&mut self) -> Result<(), Error> {
        if self.current_dir.as_ref().is_none() {
            self.current_dir = Some(env::current_dir()?);
        }

        println!("La suppression de Money For Mima ne pourra pas être faite entièrement, il vous faudra ensuite supprimer le dossier {}",
                 self.current_dir.as_ref().unwrap().display());

        let shortcuts: Vec<(PathBuf, &str)> = self.generate_links_name_from_dirs(None);
        let shortcuts_str = shortcuts
            .iter()
            .map(|s| {
                String::from("\n - ".to_owned() + s.1 + " (" + &s.0.display().to_string() + ")")
            })
            .collect::<Vec<String>>()
            .join("");
        println!("Tous les fichiers présents dans le dossier {} seront supprimés.\nÉgalement les raccourcis suivants : {}", 
                 self.current_dir.as_ref().unwrap().display(), 
                 shortcuts_str);

        print!("Êtes-vous sûr(e) de vouloir supprimer Money For Mima, cette action est irréversible ? (o/N)");
        let mut answer = String::new();
        std::io::stdout().flush()?;
        std::io::stdin()
            .read_line(&mut answer)
            .expect("Impossible de lire au clavier");

        match answer.to_lowercase().trim() {
            "oui" | "o" => (),
            _ => {
                println!("Arrêt du programme.");
                return Ok(());
            }
        }

        self.remove_dir_all_ignoring_errors(self.current_dir.as_ref().unwrap());

        let mut result: Result<(), Error> = Ok(());

        for shortcut in &shortcuts {

            if let Err(e) = fs::remove_file(&shortcut.0) {
                result = Err(Box::new(e));
            }

        }
        result
    }

    fn remove_dir_all_ignoring_errors(&self, dir: &PathBuf) {
        if let Ok(dir_entry) = fs::read_dir(dir) {
            for file in dir_entry {
                if let Ok(file_entry) = file {
                    if let Ok(metadata) = file_entry.metadata() {
                        if metadata.is_dir() {
                            self.remove_dir_all_ignoring_errors(&file_entry.path());
                            let _ = fs::remove_dir(&file_entry.path());
                        } else {
                            let _ = fs::remove_file(&file_entry.path());
                        }
                    }
                }
            }
        }
    }
}

fn main() {
    let mut uninstaller: Uninstaller = Uninstaller::new();
    if let Err(e) = uninstaller.run_deletion() {
        eprintln!("Une erreur est survenue lors de la suppression de Money For Mima ({e})");
        return;
    }
    println!("Money For Mima a été supprimé avec succès");
}
