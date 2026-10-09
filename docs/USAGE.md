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

Builds labeled `local` are ad-hoc signed and not Apple-notarized. If macOS blocks the app:

1. Drag the app into **Applications**, double-click **LidKeep**, then click **Done** in the warning.
2. Open **System Settings → Privacy & Security**, scroll down to **Security**, and click **Open Anyway** beside LidKeep.
3. Authenticate with your Mac login password, then confirm **Open**.

**Open Anyway** appears only after an attempt to launch the app is blocked. If it is missing, double-click the app first, then return to Settings. Replacing or downloading another copy may require another confirmation. Only allow a download you trust. [Apple's instructions](https://support.apple.com/en-us/102445)

The first power change, helper upgrades and helper removal request administrator authorization separately. Accessibility permission is not required.

Keep the Mac ventilated while running closed and allow sleep before putting it in a bag.

[Command line](CLI.md) · [Compatibility](COMPATIBILITY.md)
