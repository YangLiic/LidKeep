# Uninstalling LidKeep

Deleting the App alone leaves persistent power settings and a user watchdog. A complete uninstall restores the saved settings first.

## From the app

1. Choose **卸载电源助手** (Uninstall power helper).
2. Confirm, then authorize with the system administrator dialog.
3. The bundled uninstaller invokes the fixed root helper's `restore-system` command, removes the helper and sudoers grant, and removes its state directory. The app unloads and removes the current user's watchdog and clears its preferences.
4. Quit and move `LidKeep.app` to Trash.

If restoration fails, the root uninstaller stops before removing the helper. Investigate the error; do not erase the snapshot first. Keep the app until cleanup succeeds. Only the current installing user's agent is handled; simultaneous multi-user installations are unsupported.

## From a source checkout

Quit the App and run `./scripts/uninstall.sh` as your ordinary account. It asks for `sudo` authentication for the same bundled uninstaller. Do not invoke the entire script as root, because user LaunchAgent cleanup belongs to the logged-in account.

The restored fields are only AC `sleep`, battery `sleep`, and global `disablesleep`. LidKeep does not change screen-lock or display-sleep settings. The snapshot is captured immediately before the first successful write attempt.

## Recovery

If the App is unavailable but the installed helper and sudoers grant are intact, restore first:

```sh
sudo -n /Library/PrivilegedHelperTools/com.ylc.lidkeep.helper restore-system
```

Then obtain the trusted source and run its uninstall script. A failed or missing helper should be investigated before removing files. Do not run scripts copied from untrusted issue comments with administrator privileges.

If a helper is force-killed or the Mac crashes during a write, a stale operation lock can remain. First confirm no LidKeep helper operation is still running (for example, inspect `ps -axo pid,command`). Only then remove the empty lock with `sudo rmdir "/Library/Application Support/LidKeep/.operation-lock"` and retry restoration. Never remove a lock belonging to an active operation.
