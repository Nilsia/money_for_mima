use installer::installer_lib::Installer;
use shared_elements::{common_functions::wait_for_input, log_level::LogLevel};

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let mut installer = Installer::new();
    if let Err(e) = installer.run_installation().await {
        eprintln!("{}", e);
       if  let Err(e) = installer.log(&e, LogLevel::WARN) {
        eprintln!("Impossible de sauvegarder les logs... ({e})");
       }
    }
    if let Err(_) = wait_for_input() {
        eprintln!("Une erreur sans importance vient de survenir...");
    }
    Ok(())
}
