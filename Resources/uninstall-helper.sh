#!/bin/bash
# Restore settings before removing the privileged helper.
set -euo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
[[ $# == 0 && $(/usr/bin/id -u) == 0 ]] || exit 2
helper=/Library/PrivilegedHelperTools/com.ylc.lidkeep.helper
[[ -f "$helper" && ! -L "$helper" && $(/usr/bin/stat -f '%u:%Lp' "$helper") == '0:755' ]] || { echo 'Missing or unsafe helper; nothing removed.' >&2; exit 1; }
"$helper" restore-system
rm -f /etc/sudoers.d/lidkeep "$helper"
rmdir '/Library/Application Support/LidKeep'
