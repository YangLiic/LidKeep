# Using LidKeep

## Keep-awake

**Keep awake (lid and screen lock)** prevents system sleep. **Disable keep-awake** allows normal sleep again. Lock the screen with Control–Command–Q; LidKeep does not lock it automatically.

Keep-awake persists after quitting. Screen-lock timers and display-disconnect rules require the app to remain running.

## Advanced settings

AC and battery policies are independent. Lock delays are available when keep-awake is disabled; their idle-sleep settings also apply while unlocked.

The display rule runs when the last external display disconnects with the lid closed. Choosing sleep suspends keep-awake. Monitor standby may leave the display online.

## Restore and uninstall

**Restore original power settings** restores the settings saved before the first change. To remove LidKeep, choose **Uninstall power helper**, authorize, quit, then move the app to Trash. [Recovery instructions](UNINSTALL.md)

## Installation permissions

The first power change, helper upgrades and helper removal require administrator authorization. Builds labeled `local` are ad-hoc signed and not notarized. If macOS blocks a trusted download, use its **Open Anyway** option in System Settings → Privacy & Security.

Keep the Mac ventilated while running closed and allow sleep before putting it in a bag.

[Command line](CLI.md) · [Compatibility](COMPATIBILITY.md)
