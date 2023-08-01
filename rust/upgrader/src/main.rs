use std::io::Result;

use upgrader::upgrader_lib::Upgrader;

#[tokio::main]
async fn main() -> Result<()> {
    let mut upgrader: Upgrader = Upgrader::new();
    match upgrader.run_upgrade().await {
        Ok(_) => (),
        Err(e) => {
            eprintln!("Une erreur est survenue : {}", e);
            return Ok(());
        }
    }
    // check that the software is not already up to date

    // check that all files are in the current directory
    // if !do_all_files_exist(&get_files_to_move()) {
    //     println!("Veuillez vous positionner dans le dossier contant tous les dossiers pour mettre à jour le programme.");
    //     return Ok(());
    // }
    //
    // let system = if cfg!(windows) { "windows" } else { "linux" };
    //
    // // start upgrading
    // match upgrade(get_files_to_move(), system.to_string()).await {
    //     Ok(_) => (),
    //     Err(e) => {
    //         eprintln!("{}", e.to_string());
    //     }
    // };

    Ok(())
}
