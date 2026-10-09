# Command-line interface

Invoke the executable inside the app as your logged-in account, without `sudo`:

```sh
/Applications/LidKeep.app/Contents/MacOS/LidKeep help
/Applications/LidKeep.app/Contents/MacOS/LidKeep status
/Applications/LidKeep.app/Contents/MacOS/LidKeep doctor
```

| Command | Effect |
| --- | --- |
| `on` | Enable global keep-awake |
| `off` or `restore` | Allow system sleep without restoring idle timers |
| `restore-system` | Restore saved original power settings |
| `ac-awake` / `battery-awake` | Disable idle sleep for that power source |
| `ac-sleep [minutes]` / `battery-sleep [minutes]` | Set idle-sleep time for that power source |

Accepted delays: `0`, `1`, `5`, `10`, `30` minutes. `0` requests immediate screen-lock sleep in the GUI but uses a one-minute system idle timer. Reopen the GUI after editing policies through the CLI.

Help and action/error messages follow the app language. `status` and `doctor` retain English field names for diagnostics.
