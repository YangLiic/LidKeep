#!/bin/bash
# Runs in the logged-in user's session; the root helper owns the hold/suspend state.
set -euo pipefail
exec /usr/bin/sudo -n /Library/PrivilegedHelperTools/com.ylc.lidkeep.helper hold
