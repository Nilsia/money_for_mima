pub mod common_functions;
pub mod common_functions_trait;
pub mod custom_error;
pub mod log_level;
pub mod shortcut_trait;

pub const DEFAULT_REMOTE_HOST: &str = "https://leria-etud.univ-angers.fr/~ddasilva/money_for_mima/";
pub const VERSION: &str = "v0.1.0-alpha";
pub const CONFIG_FILE_NAME: &str = "config.json";

pub enum ReturnValue {
    NoError,
    Skip,
    Exit,
}

pub type Error = Box<dyn std::error::Error>;
#[cfg(test)]
mod tests {
    use regex::Regex;

    #[test]
    fn test1() {
        let exec_extension = ".exe";
        let install_regex = Regex::new(format!("install{}$", exec_extension).as_str()).unwrap();
        let text =
            "https://github.com/Nilsia/money_for_mima/releases/download/v0.1.0-alpha/install.exe";
        assert!(install_regex.is_match(text));
    }
    #[test]
    fn test2() {
        let system = "windows";
        let version = "v0.1.0-alpha";
        let package_regex =
            Regex::new(format!("{}-money_for_mima-{}.zip$", system, version).as_str());
        let text2 = "https://github.com/Nilsia/money_for_mima/releases/download/v0.1.0-alpha/windows-money_for_mima-v0.1.0-alpha.zip";
        assert!(package_regex.is_ok_and(|p| p.is_match(text2)));
    }
}
