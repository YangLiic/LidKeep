#!/bin/bash
# Privileged commands accept only validated arguments and root-owned state.
set -euo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
umask 077
STATE_DIR='/Library/Application Support/LidKeep'
WANTED="$STATE_DIR/lid-awake-wanted"
SUSPENDED="$STATE_DIR/suspended"
BACKUP="$STATE_DIR/original-settings"
VERSION=1
fail() { echo "$*" >&2; exit 2; }
[[ $(/usr/bin/id -u) == 0 ]] || fail 'Administrator privileges required.'
allowed_minutes() { case "$1" in 0|1|5|10|30) return 0;; *) return 1;; esac; }
# Reject symlinks and writable state.
[[ -d "$STATE_DIR" && ! -L "$STATE_DIR" ]] || fail 'Install the helper first.'
[[ $(/usr/bin/stat -f '%u:%Lp' "$STATE_DIR") == '0:700' ]] || fail 'Unsafe state directory.'
for file in "$WANTED" "$SUSPENDED" "$BACKUP"; do
  [[ ! -L "$file" ]] || fail 'Unsafe state file.'
  if [[ -e "$file" ]]; then
    [[ -f "$file" && $(/usr/bin/stat -f '%u:%Lp' "$file") == '0:600' ]] || fail 'Unsafe state file.'
  fi
done
read_minutes() {
  /usr/bin/pmset -g custom | /usr/bin/awk -v section="$1" '
    /^[^ \t]/ { active = ($0 == section ":") }
    active && $1 == "sleep" { print $2; exit }'
}
snapshot() {
  [[ ! -e "$BACKUP" ]] || return 0
  local ac battery disabled
  ac=$(read_minutes 'AC Power')
  battery=$(read_minutes 'Battery Power')
  disabled=$(/usr/bin/pmset -g | /usr/bin/awk '$1 == "SleepDisabled" { print $2; exit }')
  [[ "$ac" =~ ^[0-9]+$ && "$battery" =~ ^[0-9]+$ && "$disabled" =~ ^[01]$ ]] || fail 'Cannot read original power settings.'
  printf '%s\n%s\n%s\n' "$ac" "$battery" "$disabled" > "$BACKUP"
}
restore_system() {
  if [[ -f "$BACKUP" ]]; then
    # Treat the snapshot as data, never as executable shell input.
    local values=() value
    while IFS= read -r value; do values+=("$value"); done < "$BACKUP"
    [[ ${#values[@]} == 3 ]] || fail 'Invalid settings snapshot.'
    [[ ${values[0]} =~ ^[0-9]+$ && ${values[1]} =~ ^[0-9]+$ && ${values[2]} =~ ^[01]$ ]] || fail 'Invalid settings snapshot.'
    /usr/bin/pmset -c sleep "${values[0]}"
    /usr/bin/pmset -b sleep "${values[1]}"
    /usr/bin/pmset -a disablesleep "${values[2]}"
    rm -f "$BACKUP"
  fi
  rm -f "$WANTED" "$SUSPENDED"
}
cmd=${1:-}
# Serialize power changes with watchdog holds.
case "$cmd" in
  version|status) ;;
  *)
    lock="$STATE_DIR/.operation-lock"
    acquired=0
    for attempt in {1..50}; do
      if mkdir "$lock" 2>/dev/null; then acquired=1; break; fi
      /bin/sleep 0.1
    done
    [[ $acquired == 1 ]] || fail 'Helper busy or stale operation lock. See docs/UNINSTALL.md.'
    trap 'rmdir "$lock"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    ;;
esac
case "$cmd" in
  version) [[ $# == 1 ]] || fail 'Unexpected arguments.'; echo "$VERSION";;
  status)
    [[ $# == 1 ]] || fail 'Unexpected arguments.'
    [[ ! -f "$WANTED" ]] || echo wanted=1
    [[ ! -f "$SUSPENDED" ]] || echo suspended=1
    [[ ! -f "$BACKUP" ]] || echo snapshot=1
    ;;
  lid-on)
    [[ $# == 1 ]] || fail 'Unexpected arguments.'
    snapshot
    /usr/bin/pmset -a disablesleep 1
    printf '1\n' > "$WANTED"
    rm -f "$SUSPENDED"
    ;;
  lid-off)
    [[ $# == 1 ]] || fail 'Unexpected arguments.'
    snapshot
    /usr/bin/pmset -a disablesleep 0
    rm -f "$WANTED" "$SUSPENDED"
    ;;
  hold)
    [[ $# == 1 ]] || fail 'Unexpected arguments.'
    if [[ -f "$WANTED" && ! -f "$SUSPENDED" ]]; then /usr/bin/pmset -a disablesleep 1; fi
    ;;
  suspend)
    [[ $# == 1 ]] || fail 'Unexpected arguments.'
    snapshot
    printf '1\n' > "$SUSPENDED"
    /usr/bin/pmset -a disablesleep 0
    ;;
  sleep-both)
    [[ $# == 3 ]] || fail 'Expected two sleep values.'
    allowed_minutes "$2" && allowed_minutes "$3" || fail 'Unsupported delay.'
    snapshot
    /usr/bin/pmset -c sleep "$2"
    /usr/bin/pmset -b sleep "$3"
    ;;
  restore-system) [[ $# == 1 ]] || fail 'Unexpected arguments.'; restore_system;;
  *) fail 'Unknown command.';;
esac
