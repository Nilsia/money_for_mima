pub enum LogLevel {
    WARN,
}

impl ToString for LogLevel {
    fn to_string(&self) -> String {
        match self {
            LogLevel::WARN => "WARN",
        }
        .to_string()
    }
}
