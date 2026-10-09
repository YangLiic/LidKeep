# Contributing to LidKeep

Bug reports, documentation improvements, translations, compatibility results, and code contributions are welcome. For major changes, open an issue describing the problem first.

## Development

Requires macOS, Command Line Tools (Swift 6.1+), make and Python 3.

```sh
make app       # Build the universal app
make test      # Run isolated tests and read-only checks
make preview   # Preview with power changes disabled
make run       # Run the app
make release   # Package ZIP, DMG and checksums
```

No developer certificate is needed for local builds.

- `Sources/`: SwiftUI views, event coordination, power logic, CLI, and pure parsers.
- `Resources/`: bundle metadata, original icon artwork, and restricted helper scripts.
- `scripts/`: reproducible builds, tests, packaging, and source-checkout uninstall.
- `Tests/`: regression coverage for parsing, sleep guards, and isolated privileged logic.
- `docs/`: usage, compatibility, testing, uninstall, and release instructions.

Keep changes focused. Use descriptive names and comments explaining system assumptions or security boundaries rather than narrating each line. Keep root operations within the fixed helper command allowlist. Never add user-controlled executables or paths to the privileged helper, broad sudoers rules, or secrets to source control.

For a pull request, explain the user-visible change and validation. For power behavior, complete the relevant manual checks on hardware and state which cases remain untested. Run `make app` and `make test`; for packaging changes, also run `make release` and inspect the archives. Avoid claiming support solely from compilation.

The app and READMEs support English and Simplified Chinese. Keep both languages in sync; see [localization guidance](docs/LOCALIZATION.md). Preserve clear descriptions of global system effects.

Contributions are submitted under the project's MIT license. Be considerate in discussions; critique the change, not the contributor.
