@echo off

echo Building release for installer
cargo build --release
echo installer build finished

set actualDir=%~dp0
set appName=money_for_mima
set releaseF=..\..\release\
set osD=%releaseF%windows\
set target=%osD%%appName%\

IF NOT EXIST %releaseF% (
    mkdir %releaseF%
) 

IF EXIST %osD% (rmdir /s /q %osD%)
mkdir %osD%

IF EXIST %target% (rmdir /s /q %target%)
mkdir %target%

copy "..\..\target\release\windows-installer.exe" "%target%installer.exe"
cd ..\..\
flutter build windows --release
cd %actualDir%

xcopy ..\..\build\windows\runner\Release\ "%target%" /v /s /e /y /q
echo 'All files well copied'

PowerShell -command "&{ Compress-Archive -Path %target%* -DestinationPath %osD%\%appName%.zip }"
echo ZIP file correctly generated

PAUSE