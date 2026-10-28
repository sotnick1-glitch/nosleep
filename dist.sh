#!/bin/bash
# Собирает NoSleep.dmg (Apple Silicon + Intel), чтобы отправить друзьям
set -e
cd "$(dirname "$0")"
./build.sh >/dev/null
T=$(mktemp -d)
swiftc -O -swift-version 5 -target arm64-apple-macos12 main.swift -o "$T/a"
swiftc -O -swift-version 5 -target x86_64-apple-macos12 main.swift -o "$T/x"
mkdir -p "$T/dmg"
cp -R ~/Applications/NoSleep.app "$T/dmg/"
lipo -create "$T/a" "$T/x" -output "$T/dmg/NoSleep.app/Contents/MacOS/NoSleep"
codesign --force --sign - "$T/dmg/NoSleep.app"
ln -s /Applications "$T/dmg/Applications"
rm -f NoSleep.dmg
hdiutil create -volname NoSleep -srcfolder "$T/dmg" -format UDZO NoSleep.dmg >/dev/null
rm -rf "$T"
lipo -archs ~/Applications/NoSleep.app/Contents/MacOS/NoSleep >/dev/null
echo "OK: $PWD/NoSleep.dmg"
