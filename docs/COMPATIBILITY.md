# Compatibility

## Intended support

Minimum deployment target: macOS 14.0. The build compiles both `arm64` and `x86_64`, then verifies that both slices are present. This covers the instruction sets used by Apple Silicon and supported Intel MacBooks; it does not establish that every macOS/hardware combination responds to sleep controls identically.

| Environment | Compilation | Runtime / physical behavior |
| --- | --- | --- |
| M4 MacBook, macOS 15.7.7 | arm64 compiled | Install/uninstall, keep-awake, timer restoration and bilingual UI checked. Closed-lid built-in display/keyboard lights off and remote control confirmed on 2026-10-10; remaining sleep/lock/disconnect cases pending |
| Other Apple Silicon MacBooks | arm64 compiled | Not hardware-tested |
| Intel MacBooks with macOS 14+ | x86_64 compiled | Not hardware-tested |
| macOS 14 | Deployment target is 14.0 | Not tested on a macOS 14 installation |
| Newer macOS versions | Intended | Must verify against each major version |
| Desktop Macs | Can launch | Lid controls unavailable; not an intended use case |

## System assumptions

- `pmset disablesleep` is a system-level control. Its exact behavior is not a stable, model-independent app API contract.
- Lid detection reads `AppleClamshellState` from IORegistry. Missing detection is treated as unsupported rather than assuming an open lid.
- Screen-lock detection uses session metadata and distributed notifications that Apple does not document as a public stable interface. A future macOS version can change them.
- Built-in backlight control dynamically loads the undocumented DisplayServices interface. Missing APIs or failed brightness reads disable backlight changes; LidKeep never falls back to a forced display-sleep request. Remote capture and physical backlight behavior require hardware acceptance.
- Keyboard-backlight shutdown on lid closure is managed by macOS and confirmed on the tested M4; it is not a separate keyboard-control API in LidKeep. Other hardware combinations need their own acceptance results.
- Display detection counts online non-built-in displays. Mirrored, virtual, Sidecar, DisplayLink and sleeping monitors may differ. No claim of power-button detection on every monitor is made.
- Sleep requests may be blocked by the system, another process, or other power software. Check `pmset -g assertions` when investigating.
- Normal Apple closed-display mode may keep a Mac awake even after LidKeep allows sleep.
- Policies and power settings affect the whole system. Multi-user simultaneous use is not supported in this first release.

Report results with the issue template, including exact hardware and macOS version. Add a confirmed matrix entry only after running the relevant cases in `TESTING.md`.
