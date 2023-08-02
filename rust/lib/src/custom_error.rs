use core::fmt;

#[derive(Debug)]
pub enum CustomError {
    WrongParentFolder,
    DesktopNotFound,
    HomeDirNotFound,
    NotEnoughPermission,
    UnkownError,
}

impl std::error::Error for CustomError {}

impl fmt::Display for CustomError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            CustomError::WrongParentFolder => write!(f, "Vous n'êtes pas dans le bon dossier."),
            CustomError::DesktopNotFound => write!(f, "Impossible de récupérer votre Bureau"),
            CustomError::HomeDirNotFound => {
                write!(f, "Impossible de récupérer votre dossier personnel")
            }
            CustomError::NotEnoughPermission => {
                write!(f, "Vous ne possédez pas les permissions nécéssaires")
            }
            CustomError::UnkownError => write!(f, "Une erreur inconnue est survenue"),
        }
    }
}
