pub mod common_functions;
pub mod common_functions_trait;
pub mod custom_error;
pub mod log_level;
pub mod shortcut_trait;

pub const VERSION: &str = "v1.0.2";
pub const CONFIG_FILE_NAME: &str = "config.json";

pub enum ReturnValue {
    NoError,
    Skip,
    Exit,
}

pub type Error = Box<dyn std::error::Error>;
#[cfg(test)]
mod tests {

    #[test]
    fn test1() {}
}
