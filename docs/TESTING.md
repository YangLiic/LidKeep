# Acceptance tests

Automated checks do not close the lid, lock the screen, install a root helper, or put the host to sleep. Those steps must be performed by the person using the Mac. Save your work before the physical sleep checks.

## Automated and packaging checks

```sh
make app
make test
make release
```

Expected: both architectures compile, Swift warnings are errors, shell/plist checks pass, isolated helper/parser tests pass, CLI help/status/doctor work, invalid commands fail, code signature verifies, and release archives contain an app with its icon and helper resources. Verify `SHA256SUMS` from inside `dist`.

Inspect the DMG in Finder: an App and Applications shortcut should be visible. Open the App from its eventual Applications location. Use `make preview` for a read-only window inspection; writes and menu actions are disabled in preview.

## Manual hardware checks

Record app version, model/chip, macOS, power source, display connection and result for each case.

| Case | Action | Expected |
| --- | --- | --- |
| Language switching | Switch English / 简体中文, inspect all sections, relaunch | App text updates immediately; choice persists; no power settings change |
| First launch | Open without selecting an action | No authorization or new idle-timer changes |
| Authorization cancellation | Choose a power action, cancel password dialog | Clear cancellation; no installed helper or power change |
| First installation | Choose an action and authorize | Restricted helper installed; that action succeeds |
| Second operation | Toggle lid policy again | No repeat authorization for compatible installed helper |
| Path handling | Run from a location containing a space/apostrophe | Installation still uses the intended files |
| No external display | Enable keep-awake, lock manually, close lid briefly | A local task continues; open lid and inspect status |
| Allow lid sleep | Restore lid sleep, close lid without a display | System sleep follows its normal policy |
| Lock policy UI | Open Advanced settings / 高级设置 with keep-awake enabled | Controls disabled; override explanation shown; current lock summary says keep-awake overrides it |
| Display-rule UI while enabled | Expand Advanced settings / 高级设置 with keep-awake enabled | Display policy remains editable and explains that sleep suspends keep-awake |
| Action styles | Inspect both Apply buttons, Restore and Uninstall | Apply uses blue confirmation styling; Restore uses a neutral rollback icon; Uninstall uses red trash styling |
| Lock policy UI after disabling | Choose 关闭保持唤醒, then expand 高级设置 | Controls available; previously selected policies retained |
| Lock on AC | Disable keep-awake, expand 高级设置, set 1-minute lock sleep, lock | App requests sleep after delay |
| Lock on battery | Repeat on battery | Battery policy used |
| Unlock before delay | Lock then unlock before the timer fires | Timer canceled |
| Power transition | Switch AC/battery while locked | Delay re-evaluated for new power source (polling interval ≤15s) |
| Disconnect display, sleep | Close lid with external display; disconnect last display | Hold suspended; sleep request; watchdog does not re-enable it |
| Disconnect display, awake | Choose stay-awake then repeat | Keep-awake enabled |
| Monitor standby | Turn off monitor that remains online | No false promise of detection; may not trigger |
| Failed sleep request | Check status/diagnostics if no physical sleep | Failure banner if command fails; assertions may still prevent sleep |
| Close main window | Close it, choose 显示窗口 in menu bar | Window opens again |
| Quit while enabled | Quit App while keep-awake active | Setting/watchdog persists, as documented |
| Restore original | Choose 恢复原始电源设置 | Original AC/battery sleep and disablesleep restored; hold stops |
| Uninstall cancel | Cancel uninstall confirmation or admin dialog | Helper remains; cancellation reported |
| Complete uninstall | Confirm 卸载电源助手, authorize, quit | Original settings restored; helper/sudoers/agent removed |

Other Macs and macOS versions need their own results. Leave untested cases marked pending rather than treating them as passed.

## Baseline and diagnostics

Capture locally before the first modification and compare after restore:

```sh
pmset -g
pmset -g custom
"dist/LidKeep.app/Contents/MacOS/LidKeep" doctor
```

Do not enable another sleep utility during the test. `restore-system` restores the snapshot, so changes made by other utilities after the snapshot can be overwritten. After restore, the next LidKeep modification starts a fresh snapshot.

## Publication gate

Before GitHub publication, confirm name/license/copyright, hardware acceptance, and package signing status. Before calling the release stable `1.0.0`, finish the required manual cases and document outstanding compatibility limits. Release publication is a separate step from local builds and CI artifacts.
