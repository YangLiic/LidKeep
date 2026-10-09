# Release workflow

## Version and validation

Set the version in `VERSION` and increment `CFBundleVersion` in `Resources/Info.plist`. Use `MAJOR.MINOR.PATCH` for stable releases and a prerelease suffix for release candidates.

```sh
make app
make test
./scripts/package.sh
```

Verify both architectures, archive contents, checksums and the relevant [hardware tests](TESTING.md). Update the changelog, compatibility matrix and release notes.

## Signing and notarization

Ad-hoc builds produce `*-universal-local.zip` and `.dmg`. For Developer ID distribution, use a certificate and a notarization profile stored in Keychain:

```sh
SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)' make app
make test
SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
  NOTARIZE=1 NOTARY_PROFILE='your-keychain-profile' ./scripts/package.sh
```

The script notarizes and staples the App and DMG, then computes final checksums. Test a quarantined download on a clean Mac. Certificates and credentials must stay outside source control.

See Apple's [Developer ID](https://developer.apple.com/developer-id/) and [notarization documentation](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

## Publish

Create a version tag and a draft GitHub Release. Attach the App ZIP, DMG and `SHA256SUMS`; include signing status and compatibility limits in the release notes. Mark release candidates as prereleases. Review the draft before publishing.

Build products belong in Releases, not in Git. CI uploads build artifacts without publishing a release.
