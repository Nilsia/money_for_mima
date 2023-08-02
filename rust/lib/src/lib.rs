pub mod common_functions;
pub mod common_functions_trait;
pub mod custom_error;
pub mod log_level;
pub mod shortcut_trait;

pub const VERSION: &str = "0.9.0";

pub enum ReturnValue {
    NoError,
    Skip,
    Exit,
}

pub type Error = Box<dyn std::error::Error>;
#[cfg(test)]
mod tests {
    // use super::*;

    // #[test]
}
