#!/bin/bash
# Run as your ordinary logged-in account, not with sudo.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $(id -u) != 0 ]] || { echo 'Run without sudo; the script requests authorization where needed.' >&2; exit 1; }
while read -r pid; do
  command=$(ps -p "$pid" -o args=)
  [[ "$command" == *'/Contents/MacOS/LidKeep watch' ]] || { echo 'Quit LidKeep first, then rerun.' >&2; exit 1; }
done < <(pgrep -x LidKeep || true)
sudo /bin/bash Resources/uninstall-helper.sh
launchctl bootout "gui/$(id -u)/com.ylc.lidkeep.lidwatch" 2>/dev/null || true
if [[ -f "$HOME/Library/Application Support/LidKeep/screen-brightness.json" ]]; then
  brightness_tool=dist/LidKeep.app/Contents/MacOS/LidKeep
  [[ -x "$brightness_tool" ]] || brightness_tool="$HOME/Library/Application Support/LidKeep/.watcher/LidKeep.app/Contents/MacOS/LidKeep"
  "$brightness_tool" restore-brightness
fi
rm -f "$HOME/Library/LaunchAgents/com.ylc.lidkeep.lidwatch.plist"
rm -f "$HOME/Library/Application Support/LidKeep/lidwatch.sh"
rm -rf "$HOME/Library/Application Support/LidKeep/.watcher"
rm -f "$HOME/Library/Application Support/LidKeep/screen-brightness.json.lock"
rmdir "$HOME/Library/Application Support/LidKeep" 2>/dev/null || true
defaults delete com.ylc.lidkeep 2>/dev/null || true
echo 'Original power settings restored; helper and watchdog removed. Move LidKeep.app to Trash.'
