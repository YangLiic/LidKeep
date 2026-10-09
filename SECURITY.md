# Security policy and permission design

## Reporting a vulnerability

Use GitHub **Security → Report a vulnerability** for private reports. If that option is unavailable, request a private contact channel through an issue without posting exploit details. Security fixes target the latest release.

## Privileged boundary

LidKeep requests administrator authorization to copy its bundled helper to:

- `/Library/PrivilegedHelperTools/com.ylc.lidkeep.helper` — root:wheel, mode 755.
- `/etc/sudoers.d/lidkeep` — root:wheel, mode 440; exact argument combinations for the installing account.
- `/Library/Application Support/LidKeep` — root:wheel, mode 700; helper state and snapshot files use 600.

Containing directories must be root-owned and not group/world-writable. Symlinked state files are rejected. Shell quoting handles apostrophes and spaces in app paths; launch-agent plists use property-list serialization. The helper has a fixed system PATH and absolute command paths. It never sources state as code or invokes user-provided scripts.

Mutating commands use a root-private directory lock to serialize watchdog holds with restoration. A hard crash can leave a stale lock, which fails safely and requires the documented recovery.

Allowed commands are `version`, `status`, `lid-on`, `lid-off`, `hold`, `suspend`, `restore-system`, and `sleep-both` with exactly two values drawn from `0, 1, 5, 10, 30`. Both sudoers and the helper validate arguments. Restoring the root-owned snapshot can restore original nonnegative idle timers outside that set.

The helper can read/change `pmset` settings and write its own state. Anyone running under the authorized account can invoke its allowed commands; this design restricts commands, not access exclusively to the signed app. It is not sandboxed. The installer itself has normal administrator privileges while installing the files. Authorization is not stored, but sudoers grants persistent access to these commands. Updating the helper may require renewed authorization.

## Watchdog and persistence

`~/Library/LaunchAgents/com.ylc.lidkeep.lidwatch.plist` starts a user shell every 20 seconds and invokes only the restricted helper's `hold` command. The watchdog script is user-owned and runs without root privileges. Root-owned suspension state prevents this watchdog from re-enabling sleep disable while the app requests sleep after a display disconnect. Resume is an explicit keep-awake action.

Sleep settings are system-wide. A second user or another sleep utility may conflict. The first release supports a single installing account; installing for another account replaces the sudoers grant. The app does not automatically lock the screen. Screen-lock detection and notifications depend on undocumented macOS behavior.

## Data and distribution

No network calls, analytics, accounts, or password storage. Local preferences retain selected policies. The root snapshot stores only two sleep timers and the global sleep-disable flag. Build products, certificates, credentials, and diagnostic reports are excluded from source control.

Ad-hoc signatures permit local development but do not identify a trusted publisher. Developer ID signing and Apple notarization are separate release steps. Check the release's stated signing status and checksums. Removing the app alone does not remove privileged files; use the documented uninstall path.
