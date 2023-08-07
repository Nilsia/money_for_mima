use std::{env, io::Result};

use shared_elements::common_functions::wait_for_input;
use upgrader::upgrader_lib::Upgrader;

#[tokio::main]
async fn main() -> Result<()> {
    let ask = !env::args().any(|arg| arg == "--force");

    let mut upgrader: Upgrader = Upgrader::new();
    match upgrader.run_upgrade(ask).await {
        Ok(_) => (),
        Err(e) => {
            eprintln!("Une erreur est survenue : {}", e);
            if let Err(e) = upgrader.log(
                &format!("Error while upgrading : {}", e),
                shared_elements::log_level::LogLevel::WARN,
            ) {
                eprintln!("Impossible d'écrire dans le fichier de log pour l'erreur ({e})");
            }
            return Ok(());
        }
    }

    if ask {
        if let Err(_) = wait_for_input() {
            println!("Une erreur sans importance vient de survenir");
        }
    }

    Ok(())
}
