# Releasing Glacier

## One-time setup

1. Create a **Developer ID Application** certificate (Xcode, Settings, Accounts, Manage Certificates).
2. Store notarization credentials in the keychain:
   `xcrun notarytool store-credentials glacier-notary`
3. Optional, for automatic updates:
   - Generate an EdDSA key pair with Sparkle's `generate_keys` (the private key goes into the login keychain, export a backup with `generate_keys -x`).
   - Put the public key into `Glacier/Resources/Info.plist` as `SUPublicEDKey` and set `SUFeedURL` to `https://dieboiz.github.io/Glacier/appcast.xml`.
   - Set `UpdatesManager.isEnabled = true` in `Glacier/Main/Updates.swift`.
   - Enable GitHub Pages for the `docs` folder on `main` (the repository has to be public).

## Each release

1. Raise `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the Xcode project.
2. Run `Scripts/release.sh`. It builds, signs, notarizes, staples and writes `release/Glacier-<version>.zip`.
3. Upload the zip to a GitHub release.
4. With updates enabled, run `Scripts/appcast.sh release/Glacier-<version>.zip`, then commit and push `docs/appcast.xml`. The zip has to be attached to the GitHub release `v<version>` first.
