#!/bin/bash
# Run as your ordinary logged-in account, not with sudo.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $(id -u) != 0 ]] || { echo 'Run without sudo; the script requests authorization where needed.' >&2; exit 1; }
if pgrep -x LidKeep >/dev/null; then echo 'Quit LidKeep first, then rerun.' >&2; exit 1; fi
sudo /bin/bash Resources/uninstall-helper.sh
launchctl bootout "gui/$(id -u)/com.ylc.lidkeep.lidwatch" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/com.ylc.lidkeep.lidwatch.plist"
rm -f "$HOME/Library/Application Support/LidKeep/lidwatch.sh"
rmdir "$HOME/Library/Application Support/LidKeep" 2>/dev/null || true
defaults delete com.ylc.lidkeep 2>/dev/null || true
echo 'Original power settings restored; helper and watchdog removed. Move LidKeep.app to Trash.'
