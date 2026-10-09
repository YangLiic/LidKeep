# Changelog

## 1.0.0-rc.1 — Unreleased

Initial release.

- Native macOS window, menu bar controls and CLI, with English and Simplified Chinese localization and immediate language switching.
- Keep-awake for lid closure and screen lock, separate AC/battery sleep policies, and an explicit external-display disconnect exception.
- Consistent action and panel styling; clear override, suspension and disabled states.
- Restricted administrator helper with exact argument validation, protected state, serialized changes and original-setting restoration.
- Complete helper/background-service uninstall.
- Universal Apple Silicon/Intel app, original icon, ZIP/DMG packaging and SHA-256 checksums.
- Automated regression checks, CI, bilingual READMEs, contribution guidance and compatibility/testing documentation.

Requires macOS 14+. Hardware coverage is recorded in `docs/COMPATIBILITY.md`. Builds named `*-local` are ad-hoc signed and not notarized.
