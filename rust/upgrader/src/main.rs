use std::{env, io::Result};

use upgrader::upgrader_lib::Upgrader;

#[tokio::main]
async fn main() -> Result<()> {
    let ask = !env::args().any(|arg| arg == "--force");

    let mut upgrader: Upgrader = Upgrader::new();
    match upgrader.run_upgrade(ask).await {
        Ok(_) => (),
        Err(e) => {
            eprintln!("Une erreur est survenue : {}", e);
            return Ok(());
        }
    }

    Ok(())
}
