# Releasing Glacier

## One-time setup

1. Create a **Developer ID Application** certificate (Xcode, Settings, Accounts, Manage Certificates).
2. Store notarization credentials in the keychain:
   `xcrun notarytool store-credentials glacier-notary`
3. Optional, for automatic updates: generate an EdDSA key pair with Sparkle's `generate_keys`, put the public key into `Glacier/Resources/Info.plist` as `SUPublicEDKey`, set `SUFeedURL` to where the appcast is hosted and set `UpdatesManager.isEnabled = true` in `Glacier/Main/Updates.swift`. Keep a backup of the private key.

## Each release

1. Raise `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the Xcode project.
2. Run `Scripts/release.sh`. It builds, signs, notarizes, staples and writes `release/Glacier-<version>.zip`.
3. Upload the zip to a GitHub release.
4. With updates enabled, sign the zip with Sparkle's `sign_update` and add it to the appcast.
