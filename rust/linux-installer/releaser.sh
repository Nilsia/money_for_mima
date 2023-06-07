#!/bin/bash

if [ "${PWD##*/}" != 'linux-installer' ]; then
    echo 'Please, go to the right place'
    exit 0
fi

actualDir="$(pwd)"
version="$(cat '../../pubspec.yaml' | grep version: | cut -d ' ' -f2)"
printf "Actual version : %s\n" $version

echo 'Building release for installer'
cargo build --release
echo "installer build finished"

echo 'Builing release for upgrader'
cd ../linux-upgrader/
cargo build --release
cd ../linux-installer/
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

cp  '../../target/release/linux-installer' "$target/install"
cp '../../target/release/linux-upgrader' "$target/upgrade"
cd ../../
cd "$actualDir"
flutter build linux --release
cp -r -t "$target" ../../build/linux/x64/release/bundle/*
echo "All files moved"

cd "$actualDir"
cd "$osD"
if [ -e "./$appName.zip" ]; then
    rm "./$appName.zip"
fi
zip "./$appName.zip" $appName/* 
cd "$actualDir"

# echo 'Renaming files'
# for file in $(find $releaseF -maxdepth 2 -name "*.zip"); do
#     filename=$(basename $file)
#     newFilename="$(sed s/$appName/$appName-$version/g <<< $file)"
#     mv $file $newFilename
#     echo "$file successufully moved with its new name"
# done
