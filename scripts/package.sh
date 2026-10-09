#!/bin/bash
# Build distribution archives; optionally sign and notarize.
set -euo pipefail
cd "$(dirname "$0")/.."
version=$(cat VERSION)
app=dist/LidKeep.app
[[ -d "$app" ]] || { echo 'Run make app first.' >&2; exit 1; }
[[ $(/usr/libexec/PlistBuddy -c 'Print :LidKeepVersion' "$app/Contents/Info.plist") == "$version" ]] || { echo 'App version differs from VERSION; rebuild first.' >&2; exit 1; }
codesign --verify --deep --strict "$app"
xcrun lipo "$app/Contents/MacOS/LidKeep" -verify_arch arm64 x86_64
suffix=local
if [[ ${NOTARIZE:-0} == 1 ]]; then
  [[ -n ${NOTARY_PROFILE:-} ]] || { echo 'Set NOTARY_PROFILE to a stored Keychain profile.' >&2; exit 1; }
  codesign -dv "$app" 2>&1 | /usr/bin/grep -q 'Authority=Developer ID Application:' || { echo 'Developer ID signature required.' >&2; exit 1; }
  ditto -c -k --sequesterRsrc --keepParent "$app" .build/notary-upload.zip
  xcrun notarytool submit .build/notary-upload.zip --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$app"
  xcrun stapler validate "$app"
  spctl --assess --type execute "$app"
  suffix=notarized
fi
base="LidKeep-$version-universal-$suffix"
zip="dist/$base.zip"
dmg="dist/$base.dmg"
stage=$(mktemp -d .build/dmg.XXXXXX)
trap 'rm -rf "$stage"' EXIT
cp -R "$app" "$stage/"
ln -s /Applications "$stage/Applications"
cp LICENSE "$stage/License.txt"
cat > "$stage/Read Me.txt" <<EOF
LidKeep $version — $suffix

English
Requires macOS 14+. Drag LidKeep.app into Applications, then open it.
The app supports English and Simplified Chinese; use its language selector.
The first power change requires administrator authorization.
Quitting does not restore power settings.
To uninstall: choose Uninstall power helper, authorize, quit, then move the app to Trash.
Builds labeled local are ad-hoc signed and not notarized.

简体中文
需要 macOS 14 或更新版本。将 LidKeep.app 拖入「应用程序」后打开。
App 支持中文与英文，可通过窗口中的语言选择器切换。
首次修改电源设置需要管理员认证。退出不会恢复电源设置。
卸载时请先选择「卸载电源助手」，完成认证，退出后将 App 移到废纸篓。
标记为 local 的构建只有临时签名，未经过 Apple 公证。
EOF
rm -f "$zip" "$dmg"
ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"
hdiutil create -quiet -volname LidKeep -srcfolder "$stage" -ov -format UDZO "$dmg"
if [[ "$suffix" == notarized ]]; then
  codesign --timestamp --sign "${SIGN_IDENTITY:?Set SIGN_IDENTITY to sign the DMG}" "$dmg"
  xcrun notarytool submit "$dmg" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$dmg"
  xcrun stapler validate "$dmg"
fi
(cd dist && shasum -a 256 "$base.zip" "$base.dmg" > SHA256SUMS)
printf 'Version: %s\nArchitectures: arm64 x86_64\nSigning/distribution: %s\nMinimum macOS: 14.0\n' "$version" "$suffix" > dist/RELEASE-INFO.txt
echo "Created $zip and $dmg"
