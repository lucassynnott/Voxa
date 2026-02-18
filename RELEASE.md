# Voxa Release Process

This document describes how to build, sign, package, and distribute Voxa.

## Quick Start

To create a distributable DMG:

```bash
./scripts/package-release.sh
```

This will:
1. Build the app in release mode
2. Sign it with your Developer ID
3. Create a beautiful DMG installer
4. Generate Sparkle update artifacts (`.build/updates/appcast.xml`)

The DMG will be created at: `.build/Voxa-Installer.dmg`

## Individual Steps

### 1. Build the App

```bash
./scripts/build-app.sh --release
```

This creates a signed app bundle at `.build/Voxa.app` with:
- Developer ID Application certificate
- Hardened Runtime enabled
- Required entitlements (microphone, accessibility)

### 2. Create DMG

```bash
./scripts/create-dmg.sh
```

This creates a professionally designed DMG installer with:
- Custom background with Voxa branding
- Drag-to-Applications UI
- Proper icon positioning
- Signed DMG

### 3. Notarization (Optional but Recommended)

For distribution outside the Mac App Store, notarization is recommended to avoid Gatekeeper warnings.

#### Setup (one-time)

1. Generate an app-specific password at https://appleid.apple.com
   - Sign in with your Apple ID
   - Go to "App-Specific Passwords"
   - Generate a new password

2. Store credentials in keychain:
```bash
xcrun notarytool store-credentials 'notarytool-password' \
  --apple-id 'your-apple-id@email.com' \
  --team-id '9785XZK34L' \
  --password 'your-app-specific-password'
```

3. Set environment variables:
```bash
export APPLE_ID='your-apple-id@email.com'
export APPLE_TEAM_ID='9785XZK34L'
```

#### Notarize the App

```bash
./scripts/notarize-app.sh
```

This will:
- Create a zip of the app
- Submit to Apple for notarization
- Wait for approval (usually 1-5 minutes)
- Staple the notarization ticket to the app

### 4. Generate Sparkle Appcast

```bash
./scripts/generate-appcast.sh
```

This creates update artifacts at `.build/updates/`:
- A versioned update ZIP archive
- `appcast.xml` for Sparkle clients

To enable in-app updates in production, set these keys in `Resources/Info.plist` before release:

```xml
<key>SUFeedURL</key>
<string>https://your-update-host.example.com/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>YOUR_SPARKLE_PUBLIC_ED25519_KEY</string>
```

Then publish all files from `.build/updates/` to your update host over HTTPS.

### 5. Publish Updates to GitHub Pages

```bash
./scripts/publish-updates-github-pages.sh
```

This script:
- Pushes `.build/updates/*` to the `gh-pages` branch under `/updates`
- Ensures GitHub Pages is configured to serve from `gh-pages` root
- Publishes feed URL:
  - `https://lucassynnott.github.io/Voxa/updates/appcast.xml`

#### Notarize the DMG (Optional)

```bash
xcrun notarytool submit .build/Voxa-Installer.dmg \
  --apple-id $APPLE_ID \
  --team-id $APPLE_TEAM_ID \
  --password '@keychain:notarytool-password' \
  --wait

# If successful, staple the ticket
xcrun stapler staple .build/Voxa-Installer.dmg
```

## Verification

### Check Code Signature

```bash
codesign -dvv .build/Voxa.app
```

Should show:
- Authority: Developer ID Application
- Runtime flag enabled
- Team ID: 9785XZK34L

### Check Entitlements

```bash
codesign -d --entitlements - .build/Voxa.app
```

Should show:
- `com.apple.security.device.audio-input`
- `com.apple.security.automation.apple-events`

### Test the App

```bash
# Test opening the DMG
open .build/Voxa-Installer.dmg

# Install to Applications and test launch
cp -R .build/Voxa.app /Applications/
open /Applications/Voxa.app
```

## Distribution

Once notarized, you can distribute:

1. **DMG File**: `.build/Voxa-Installer.dmg`
   - Users download and drag to Applications
   - No Gatekeeper warnings if notarized

2. **Direct Download**: Host the DMG on your website
   - Recommended: Use HTTPS
   - Include SHA-256 checksum for verification

3. **Auto-Updates**: Sparkle is integrated; publish `.build/updates/appcast.xml` and archives

## Troubleshooting

### Gatekeeper Blocking App

If users see "app is damaged and can't be opened":
- Ensure app is notarized
- Check code signature: `codesign -v .build/Voxa.app`
- Users can temporarily bypass: `xattr -cr /Applications/Voxa.app`

### Permission Dialogs Not Showing

- Verify entitlements are included in signature
- Check app is signed with Developer ID (not ad-hoc)
- Ensure hardened runtime is enabled

### Notarization Failures

Common issues:
- **Invalid signature**: Re-sign the app
- **Missing entitlements**: Check `Resources/Voxa.entitlements`
- **Hardened runtime issues**: Ensure `--options runtime` in codesign

Check notarization log:
```bash
xcrun notarytool log <submission-id> \
  --apple-id $APPLE_ID \
  --team-id $APPLE_TEAM_ID \
  --password '@keychain:notarytool-password'
```

## Version Bumping

Before releasing:

1. Update version in `Resources/Info.plist`:
```xml
<key>CFBundleShortVersionString</key>
<string>0.2.0</string>
<key>CFBundleVersion</key>
<string>2</string>
```

2. Tag the release:
```bash
git tag v0.2.0
git push origin v0.2.0
```

3. Create release notes in GitHub

## Security Notes

- Never commit Apple ID credentials
- Use app-specific passwords (not your main Apple ID password)
- Store credentials in system keychain
- Rotate app-specific passwords periodically

## Resources

- [Apple Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/)
- [Hardened Runtime](https://developer.apple.com/documentation/security/hardened_runtime)
