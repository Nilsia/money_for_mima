use std::io::Result;

use linux_upgrader::{
    shared_linux::get_files_to_move,
    shared_tools::{do_all_files_exist, get_version, VERSION},
    shared_upgrader::upgrade,
};

#[tokio::main]
async fn main() -> Result<()> {
    // check that the software is not already up to date
    let remote_version = match get_version().await {
        Ok(v) => v,
        Err(e) => {
            eprintln!("{}", e);
            return Ok(());
        }
    };
    if remote_version == VERSION {
        println!("Money For Mima est déjà à jour.");
        return Ok(());
    }

    // check that all files are in the current directory
    if !do_all_files_exist(&get_files_to_move()) {
        println!("Veuillez vous positionner dans le dossier contant tous les dossiers pour mettre à jour le programme.");
        return Ok(());
    }

    // start upgrading
    match upgrade(get_files_to_move(), "linux".to_string()).await {
        Ok(_) => (),
        Err(e) => {
            eprintln!("{}", e.to_string());
        }
    };

    Ok(())
}
