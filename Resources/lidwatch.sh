#!/bin/bash
# Runs without administrator privileges; the helper owns the hold/suspend state.
set -euo pipefail
exec "$(dirname "$0")/.watcher/LidKeep.app/Contents/MacOS/LidKeep" watch
