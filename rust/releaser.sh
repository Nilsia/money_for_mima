#!/bin/bash

if [ "${PWD##*/}" != 'rust' ]; then
    echo 'Please, go to the right place'
    exit 0
fi

oldVersionWithoutV="$(grep VERSION ./lib/src/lib.rs | cut -d ' ' -f6 | tr -d '"' | tr -d \; | cut -c 2-)"
echo "Old version : v$oldVersionWithoutV"
read -rp "Please provide the new version : v" version
version="v$version"

read -rp "Is it the right version (y/N) : $version ?" check
if [ "$check" != "y" ]; then
    echo "exiting"
    exit 0
fi

if [ "$version" != "v$oldVersionWithoutV" ];then 
    filesToEditWithoutV=("../pubspec.yaml")
    filesToEditWithV=("../config.json" "./lib/src/lib.rs")
        
    echo "Changing version from v$oldVersionWithoutV to $version"
    for file in "${filesToEditWithoutV[@]}"; do
        if [ ! -e "$file" ];then 
            continue
        fi
        sed -i "s/version: \"$oldVersionWithoutV\"/version: \"$(cut -c 2- <<< "$version" )\"/g" "$file"
        echo "$file edited"
    done
    
    for file in "${filesToEditWithV[@]}"; do
        if [ ! -e "$file" ];then 
            continue
        fi
        sed -i "s/v$oldVersionWithoutV/$version/g" "$file"
        echo "$file edited"
    done
    
    echo
    printf 'oldVersion : %s\n' "v$oldVersionWithoutV"

fi 
printf "Actual version : %s\n" "$version"

echo
echo 'Building release for Installer, Upgrader and Uninstaller'
cargo +nightly build --release -p installer -p upgrader -p uninstaller
echo 'Builds of Installer, Upgrader and Uninstaller finished'
cd ../ 


actualDir="$(pwd)"
fileName="linux-money_for_mima-$version"
folderName="money_for_mima"
releaseF='./release/'
osD="$releaseF/linux/"
target="$osD/$folderName/"

if [ ! -e "$releaseF/" ]; then
    mkdir "$releaseF/"
fi

if [ -e "$osD" ]; then
    rm -rf "$osD"
fi
mkdir $osD
mkdir "$target"

cp  './target/release/installer' "$target/install"
cp './target/release/upgrader' "$target/upgrade"
cp './target/release/uninstaller' "$target/uninstall"
cp './config.json' "$target"

flutter build linux --release
cp -r -t "$target" ./build/linux/x64/release/bundle/*
echo "All files moved"

# cd "$actualDir" || exit
cd "$osD" || exit
if [ -e "./$fileName.zip" ]; then
    rm "./$fileName.zip"
fi
zip -r "./$fileName.zip" $folderName/* 
cd "$actualDir" || exit

# echo 'Renaming files'
# for file in $(find $releaseF -maxdepth 2 -name "*.zip"); do
#     filename=$(basename $file)
#     newFilename="$(sed s/$appName/$appName-$version/g <<< $file)"
#     mv $file $newFilename
#     echo "$file successufully moved with its new name"
# done
