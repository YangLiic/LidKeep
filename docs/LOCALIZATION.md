# Localization

LidKeep supports English (`en`) and Simplified Chinese (`zh-Hans`). The window's language selector offers Follow system, English and 简体中文. Unsupported system languages fall back to English; Chinese system languages use Simplified Chinese. The explicit choice is stored in the app's local preferences and applies immediately to app-owned controls, status messages and menus. Standard macOS menus and administrator authentication dialogs follow macOS settings.

## Editing translations

- Edit `Resources/en.lproj/Localizable.strings` and `Resources/zh-Hans.lproj/Localizable.strings` together.
- English source phrases act as keys; `cli.help` is the multiline CLI help entry.
- Call `L.text` for a translated message and `L.format` for placeholders. Use `%@` for text and `%d` for integer counts, preserving argument order in both languages.
- Keep explanations of system-wide sleep changes, persistence and administrator authorization accurate in both languages.
- The language names English and 简体中文 stay in their own language so users can find them.

`make test` checks missing/duplicate keys, format arguments and packaged resources. Swift tests check explicit language choices and fallback behavior. Inspect both languages in the running app, including Advanced settings, Maintenance, disabled controls, confirmations and long messages; tests cannot establish visual fit.

CLI help and action/error messages follow the selected app language. Diagnostic field names in `status` and `doctor` remain English for consistent issue reports. External command errors are shown as returned by macOS.
