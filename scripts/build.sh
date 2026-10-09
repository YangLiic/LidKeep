#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $(uname -s) == Darwin ]] || { echo 'Build requires macOS.' >&2; exit 1; }
version=$(cat VERSION)
sdk=$(xcrun --sdk macosx --show-sdk-path)
app=dist/LidKeep.app
mkdir -p .build "$app/Contents/MacOS" "$app/Contents/Resources"
for arch in arm64 x86_64; do
  xcrun swiftc -target "$arch-apple-macosx14.0" -sdk "$sdk" -swift-version 5 -warnings-as-errors -O \
    -framework SwiftUI -framework AppKit -framework Combine -framework CoreGraphics \
    -o ".build/LidKeep-$arch" Sources/*.swift
done
xcrun lipo -create .build/LidKeep-arm64 .build/LidKeep-x86_64 -output "$app/Contents/MacOS/LidKeep"
cp Resources/Info.plist "$app/Contents/Info.plist"
# Bundle versions omit the prerelease suffix.
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${version%%-*}" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :LidKeepVersion $version" "$app/Contents/Info.plist"
cp Resources/*.sh "$app/Contents/Resources/"
cp -R Resources/*.lproj "$app/Contents/Resources/"
chmod 755 "$app/Contents/Resources/"*.sh
xcrun swift scripts/make-icon.swift .build/AppIcon.iconset
iconutil -c icns .build/AppIcon.iconset -o "$app/Contents/Resources/AppIcon.icns"
cp Resources/AppIcon.svg "$app/Contents/Resources/"
cp LICENSE "$app/Contents/Resources/License.txt"
if [[ -n ${SIGN_IDENTITY:-} ]]; then
  [[ "$SIGN_IDENTITY" == 'Developer ID Application:'* ]] || { echo 'SIGN_IDENTITY must be a Developer ID Application identity.' >&2; exit 1; }
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$app"
else
  codesign --force --sign - "$app"
fi
codesign --verify --deep --strict "$app"
xcrun lipo "$app/Contents/MacOS/LidKeep" -verify_arch arm64 x86_64
echo "Built $app ($version, arm64 + x86_64)"
