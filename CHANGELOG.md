# Changelog

## 1.0.0-rc.3 — 2026-10-10

- Add a bilingual screen policy with automatic screen off by default while keeping tasks running without an external display.
- Darken the built-in backlight on lid closure while retaining the display session for remote capture; restore brightness on opening.
- Follow System Settings for display sleep after locking with the lid open.
- Preserve brightness across background-service restarts; release screen control when keep-awake stops or an external display connects.
- Add bilingual screen-off and remote-control hints; verify closed-lid keyboard-backlight behavior and remote control on an M4 MacBook.
- Fix background startup and prevent automatic crash restart loops.

## 1.0.0-rc.2

- Bilingual drag-to-install DMG with a Retina background, positioned app and Applications icons, and a custom volume icon.
- Clear first-launch instructions for unnotarized builds in both READMEs and user guides.

## 1.0.0-rc.1 — 2026-10-09

Initial release.

- Native macOS window, menu bar controls and CLI, with English and Simplified Chinese localization and immediate language switching.
- Keep-awake for lid closure and screen lock, separate AC/battery sleep policies, and an explicit external-display disconnect exception.
- Consistent action and panel styling; clear override, suspension and disabled states.
- Restricted administrator helper with exact argument validation, protected state, serialized changes and original-setting restoration.
- Complete helper/background-service uninstall.
- Universal Apple Silicon/Intel app, original icon, ZIP/DMG packaging and SHA-256 checksums.
- Automated regression checks, CI, bilingual READMEs, contribution guidance and compatibility/testing documentation.

Requires macOS 14+. Hardware coverage is recorded in `docs/COMPATIBILITY.md`. Builds named `*-local` are ad-hoc signed and not notarized.
