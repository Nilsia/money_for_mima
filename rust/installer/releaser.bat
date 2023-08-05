@echo off

set actualDir=%~dp0
set folderName=money_for_mima
set fileName=windows-money_for_mima
set releaseF=..\..\release\
set osD=%releaseF%windows\
set target=%osD%%folderName%\

echo Building release for installer
cargo build --release
echo installer build finished

echo Building release for uninstaller
cd ../uninstaller/
cargo build --release
echo Uninstaller build finished

echo Builing release for upgrader
cd ../upgrader/
cargo build --release
cd ../installer/
echo Upgrader build finished

IF NOT EXIST %releaseF% (
    mkdir %releaseF%
) 

IF EXIST %osD% (rmdir /s /q %osD%)
mkdir %osD%

IF EXIST %target% (rmdir /s /q %target%)
mkdir %target%

copy "..\..\target\release\installer.exe" "%target%install.exe"
copy "..\..\target\release\upgrader.exe" "%target%upgrade.exe"
copy "..\..\target\release\uninstaller.exe" "%target%uninstall.exe"

cd ..\..\
PowerShell -command "& { flutter build windows --release }"
cd %actualDir%

xcopy ..\..\build\windows\runner\Release\ "%target%" /v /s /e /y /q
echo All files well copied

PowerShell -command "&{ Compress-Archive -Path %target%* -DestinationPath %osD%\%fileName%.zip }"
echo ZIP file correctly generated

PAUSE
