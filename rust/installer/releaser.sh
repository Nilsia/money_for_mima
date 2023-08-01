#!/bin/bash

if [ "${PWD##*/}" != 'installer' ]; then
    echo 'Please, go to the right place'
    exit 0
fi

actualDir="$(pwd)"
version="$(grep version: ../../pubspec.yaml| cut -d ' ' -f2)"     
printf "Actual version : %s\n" "$version"

echo 'Building release for installer'
cargo build --release
echo "installer build finished"

echo 'Builing release for upgrader'
cd ../upgrader/ || exit
cargo build --release
cd ../installer/ || exit
echo 'Upgrader build finished'

# appName="money_for_mima-$version"
appName="money_for_mima-linux"
releaseF='../../release/'
osD="$releaseF/linux/"
target="$osD/$appName/"

if [ ! -e "$releaseF/" ]; then
    mkdir "$releaseF/"
fi

if [ -e "$osD" ]; then
    rm -rf "$osD"
fi
mkdir $osD

if [ -e "$target" ]; then
    rm -rf "$target"
fi
mkdir $target

cp  '../../target/release/installer' "$target/install"
cp '../../target/release/upgrader' "$target/upgrade"
cd ../../
cd "$actualDir" || exit
flutter build linux --release
cp -r -t "$target" ../../build/linux/x64/release/bundle/*
echo "All files moved"

cd "$actualDir" || exit
cd "$osD" || exit
if [ -e "./$appName.zip" ]; then
    rm "./$appName.zip"
fi
zip -r "./$appName.zip" $appName/* 
cd "$actualDir" || exit

# echo 'Renaming files'
# for file in $(find $releaseF -maxdepth 2 -name "*.zip"); do
#     filename=$(basename $file)
#     newFilename="$(sed s/$appName/$appName-$version/g <<< $file)"
#     mv $file $newFilename
#     echo "$file successufully moved with its new name"
# done
