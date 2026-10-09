#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
for script in Resources/*.sh scripts/*.sh; do bash -n "$script"; done
plutil -lint Resources/Info.plist
for strings in Resources/*.lproj/*.strings; do plutil -lint "$strings"; done
python3 -m unittest discover -s Tests -p 'test_*.py' -v
mkdir -p .build
xcrun swiftc -swift-version 5 -warnings-as-errors Sources/Localization.swift Sources/PowerTypes.swift Tests/PowerTypesTests.swift -o .build/PowerTypesTests
.build/PowerTypesTests
xcrun swiftc -swift-version 5 -warnings-as-errors Sources/Localization.swift Sources/PowerTypes.swift Sources/PowerManager.swift Sources/ScreenPowerController.swift Tests/ScreenPowerTests.swift -o .build/ScreenPowerTests
.build/ScreenPowerTests
# Read-only smoke tests; none of these install helpers or mutate pmset.
if [[ -x dist/LidKeep.app/Contents/MacOS/LidKeep ]]; then
  binary=dist/LidKeep.app/Contents/MacOS/LidKeep
  "$binary" help
  "$binary" doctor
  if "$binary" unknown-command >/dev/null 2>&1; then echo 'Unknown CLI command incorrectly succeeded.' >&2; exit 1; fi
  if "$binary" ac-sleep nonsense >/dev/null 2>&1; then echo 'Invalid delay incorrectly succeeded.' >&2; exit 1; fi
  codesign --verify --deep --strict dist/LidKeep.app
  xcrun lipo "$binary" -verify_arch arm64 x86_64
  watcher_stage=$(mktemp -d .build/watcher-test.XXXXXX)
  trap 'rm -rf "$watcher_stage"' EXIT
  ditto dist/LidKeep.app "$watcher_stage/LidKeep.app"
  codesign --verify --deep --strict "$watcher_stage/LidKeep.app"
  if LIDKEEP_PREVIEW=1 "$watcher_stage/LidKeep.app/Contents/MacOS/LidKeep" watch; then watcher_status=0
  else watcher_status=$?; fi
  [[ $watcher_status == 1 ]] || { echo 'Background watcher preview guard failed.' >&2; exit 1; }
  "$watcher_stage/LidKeep.app/Contents/MacOS/LidKeep" watch-check
fi
