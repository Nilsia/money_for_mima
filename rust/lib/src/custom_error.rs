use core::fmt;

#[derive(Debug)]
pub enum CustomError {
    WrongParentFolder,
    DesktopNotFound,
    HomeDirNotFound,
    NotEnoughPermission,
    UnkownError,
    ParseErrorJson,
    CannotGetRemoteVersion,
    InvalidJsonValue,
    CannotFetchRemoteData,
    CannotGetRemotePackage,
    CannotGetLocalVersion,
}

impl std::error::Error for CustomError {}

// impl From<json::Error> {

// }

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
            CustomError::ParseErrorJson => {
                write!(f, "Une erreur est survenue lors du parsage du JSON")
            }
            CustomError::CannotGetRemoteVersion => {
                write!(f, "Impossible de récupérer la version distante")
            }
            CustomError::InvalidJsonValue => write!(f, "Le type de la valeur du JSON est invalide."),
            CustomError::CannotFetchRemoteData => write!(f, "Impossible de récupérer les données distantes, veuillez vous connecter à internet. Cependant l'erreur peut aussi provenir du programme, dans ce cas contactez les développeurs."),
            CustomError::CannotGetRemotePackage => write!(f, "Impossible de récupérer les nouvelles versions"),
            CustomError::CannotGetLocalVersion => write!(f, "Impossible de récupérer la version locale, vérifier le fichier de configuration dans les fichiers."),
        }
    }
}
