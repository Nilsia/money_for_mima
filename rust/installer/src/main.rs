use installer::{
    installer_lib::Installer,
    shared_tools::{wait_for_input, Error},
};

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let mut wait_after: bool = true;
    match sub_main(&mut wait_after).await {
        Ok(_) => (),
        Err(_) => (),
    }
    if wait_after {
        if let Err(_) = wait_for_input() {
            eprintln!("Une erreur sans importance vient de survenir...");
        }
    }
    Ok(())
}

async fn sub_main(_wait_after: &mut bool) -> Result<(), Error> {
    let mut installer = Installer::new();
    if let Err(e) = installer.run_installation().await {
        eprintln!("{}", e);
        return Err(e);
    }

    Ok(())
}
