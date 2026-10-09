#!/bin/bash
set -euo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
umask 077
[[ $# == 2 && $(/usr/bin/id -u) == 0 ]] || exit 2
src=$1
account=$2
[[ "$account" =~ ^[A-Za-z_][A-Za-z0-9._-]*$ && -f "$src" && ! -L "$src" ]] || exit 2
/usr/bin/id "$account" >/dev/null
parent=/Library/PrivilegedHelperTools
dest="$parent/com.ylc.lidkeep.helper"
state='/Library/Application Support/LidKeep'
sudoers=/etc/sudoers.d/lidkeep
# Protect parent directories against helper replacement.
for directory in /Library '/Library/Application Support' /private/etc; do
  [[ -d "$directory" && ! -L "$directory" ]] || exit 2
  [[ $(/usr/bin/stat -f '%u' "$directory") == 0 ]] || exit 2
  mode=$(/usr/bin/stat -f '%Lp' "$directory")
  (( (8#$mode & 0022) == 0 )) || exit 2
done
if [[ -e /private/etc/sudoers.d ]]; then
  [[ -d /private/etc/sudoers.d && ! -L /private/etc/sudoers.d && $(/usr/bin/stat -f '%u' /private/etc/sudoers.d) == 0 ]] || exit 2
  mode=$(/usr/bin/stat -f '%Lp' /private/etc/sudoers.d)
  (( (8#$mode & 0022) == 0 )) || exit 2
else
  mkdir -m 755 /private/etc/sudoers.d
  chown root:wheel /private/etc/sudoers.d
fi
[[ ! -L "$parent" && ! -L "$state" && ! -L "$dest" && ! -L "$sudoers" ]] || exit 2
mkdir -p "$parent" "$state"
chown root:wheel "$parent" "$state"
chmod 755 "$parent"
chmod 700 "$state"
helper_tmp=$(mktemp "$parent/.lidkeep.XXXXXX")
sudoers_tmp=$(mktemp /private/etc/sudoers.d/.lidkeep.XXXXXX)
trap 'rm -f "$helper_tmp" "$sudoers_tmp"' EXIT
cp "$src" "$helper_tmp"
chown root:wheel "$helper_tmp"
chmod 755 "$helper_tmp"
{
  for command in version status lid-on lid-off hold suspend restore-system; do
    printf '%s ALL=(root) NOPASSWD: %s %s\n' "$account" "$dest" "$command"
  done
  for ac in 0 1 5 10 30; do
    for battery in 0 1 5 10 30; do
      printf '%s ALL=(root) NOPASSWD: %s sleep-both %s %s\n' "$account" "$dest" "$ac" "$battery"
    done
  done
} > "$sudoers_tmp"
chown root:wheel "$sudoers_tmp"
chmod 440 "$sudoers_tmp"
/usr/sbin/visudo -cf "$sudoers_tmp"
mv -f "$helper_tmp" "$dest"
mv -f "$sudoers_tmp" "$sudoers"
