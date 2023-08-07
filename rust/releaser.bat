@echo off

set folderName=money_for_mima
set fileName=windows-money_for_mima
set releaseF=release\
set osD=%releaseF%windows\
set target=%osD%%folderName%\

cd ../
echo Building Installer, Upgrader and Uninstaller
cargo +nightly build -p upgrader -p installer -p uninstaller --release
echo Build of Installer, Upgrader and Uninstaller finished
:: Now we are in root directory of folder

IF NOT EXIST %releaseF% (
    mkdir %releaseF%
) 

IF EXIST %osD% (rmdir /s /q %osD%)
mkdir %osD%
mkdir %target%

copy ".\target\release\installer.exe" "%target%install.exe"
copy ".\target\release\upgrader.exe" "%target%upgrade.exe"
copy ".\target\release\uninstaller.exe" "%target%uninstall.exe"

PowerShell -command "& { flutter build windows --release }"

xcopy build\windows\runner\Release\ "%target%" /v /s /e /y /q
echo All files well copied

PowerShell -command "&{ Compress-Archive -Path %target%* -DestinationPath %osD%\%fileName%.zip }"
echo ZIP file correctly generated

PAUSE
