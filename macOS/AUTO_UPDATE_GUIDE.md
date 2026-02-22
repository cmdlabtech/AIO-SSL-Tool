# Auto-Update System Documentation

## Overview

AIO SSL Tool uses the [Sparkle framework](https://sparkle-project.org/) to provide automatic updates. Sparkle is the industry-standard update framework for macOS applications, offering secure, signed updates that seamlessly replace the existing installation.

## Features

- **Automatic Update Checking**: Checks for updates automatically at configurable intervals
- **Background Downloads**: Downloads updates in the background without interrupting work
- **Secure Updates**: Uses EdDSA signatures to verify update authenticity
- **Seamless Installation**: Replaces the existing app installation without user intervention
- **User Control**: Users can enable/disable automatic checks and downloads in Settings

## How It Works

### Update Flow

1. **Check for Updates**: The app checks the appcast feed URL for new versions
2. **Download**: If a newer version is found, it downloads the DMG/ZIP file
3. **Verify**: Verifies the EdDSA signature to ensure authenticity
4. **Install**: Extracts and replaces the existing app with the new version
5. **Relaunch**: Optionally relaunches the app with the new version

### Update Checking Schedule

- Automatically checks every 24 hours (configurable in Info.plist)
- Manual check available in Settings > Updates
- Initial check occurs 2 seconds after app launch

## Setup Instructions

### 1. Generate Sparkle Keys

Generate an EdDSA key pair for signing releases:

```bash
# Install Sparkle's tools
brew install sparkle

# Generate keys
./generate_keys

# This creates two files:
# - sparkle_eddsa_public.key  (add to Info.plist)
# - sparkle_eddsa_private.key (keep secret, use for signing)
```

**Important**: Never commit your private key to version control!

### 2. Configure Info.plist

Update the following keys in `Info.plist`:

```xml
<!-- Replace YOUR_USERNAME with your GitHub username -->
<key>SUFeedURL</key>
<string>https://raw.githubusercontent.com/YOUR_USERNAME/AIO-SSL-Tool/main/appcast.xml</string>

<!-- Add your public EdDSA key -->
<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_KEY_HERE</string>
```

### 3. Sign Release DMG

When creating a new release, sign the DMG file:

```bash
# Sign the DMG
./sign_update /path/to/AIOSSLTool-macOS-v6.0.1.dmg sparkle_eddsa_private.key

# This outputs the signature to paste in appcast.xml
```

### 4. Update Appcast.xml

For each new release, add an entry to `appcast.xml`:

```xml
<item>
    <title>Version 6.0.1</title>
    <sparkle:version>6.0.1</sparkle:version>
    <sparkle:shortVersionString>6.0.1</sparkle:shortVersionString>
    <description><![CDATA[
        <h2>What's New</h2>
        <ul>
            <li>Feature 1</li>
            <li>Bug fix 1</li>
        </ul>
    ]]></description>
    <pubDate>Sat, 08 Feb 2026 12:00:00 +0000</pubDate>
    <enclosure 
        url="https://github.com/YOUR_USERNAME/AIO-SSL-Tool/releases/download/v6.0.1/AIOSSLTool-macOS-v6.0.1.dmg" 
        sparkle:version="6.0.1" 
        length="INSERT_FILE_SIZE_IN_BYTES" 
        type="application/octet-stream"
        sparkle:edSignature="INSERT_SIGNATURE_HERE" />
    <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
</item>
```

**Required fields:**
- `url`: Direct download link to the DMG
- `length`: File size in bytes (get with `ls -l`)
- `sparkle:edSignature`: Generated signature from step 3

### 5. Publish Update

1. Build and sign your new release
2. Create a GitHub release with the DMG
3. Update `appcast.xml` with the new release entry
4. Commit and push `appcast.xml` to the repository
5. Users will automatically receive the update!

## Release Workflow

### Complete Release Process

```bash
# 1. Update version numbers
# Edit Info.plist: CFBundleShortVersionString and CFBundleVersion

# 2. Build the app
cd macOS/AIOSSLTool
./build.sh

# 3. Create DMG (if not already created)
hdiutil create -volname "AIO SSL Tool" -srcfolder "AIO SSL Tool.app" -ov -format UDZO AIOSSLTool-macOS-v6.0.1.dmg

# 4. Sign the DMG for Sparkle
sign_update AIOSSLTool-macOS-v6.0.1.dmg sparkle_eddsa_private.key

# 5. Get file size
ls -l AIOSSLTool-macOS-v6.0.1.dmg | awk '{print $5}'

# 6. Update appcast.xml with:
#    - New version entry
#    - EdDSA signature from step 4
#    - File size from step 5
#    - Direct GitHub release URL

# 7. Create GitHub release
gh release create v6.0.1 AIOSSLTool-macOS-v6.0.1.dmg --title "v6.0.1" --notes "Release notes here"

# 8. Commit and push appcast.xml
git add appcast.xml
git commit -m "Update appcast for v6.0.1"
git push
```

## Testing Updates

### Test Update Flow Locally

1. **Build two versions**: Build v6.0.0 and v6.0.1
2. **Host appcast locally**: Use a local web server
3. **Test automatic check**: Launch v6.0.0 and wait for update prompt
4. **Test manual check**: Click "Check for Updates" in Settings

### Local Testing Setup

```bash
# Host appcast on local server
python3 -m http.server 8000

# Update Info.plist temporarily for testing
<key>SUFeedURL</key>
<string>http://localhost:8000/appcast.xml</string>
```

## User Experience

### Settings Interface

Users can manage updates in **Settings > Updates**:

- View current version and build number
- See when updates were last checked
- Toggle automatic update checking
- Toggle automatic download
- Manually check for updates

### Update Notifications

When an update is available:
1. User sees a notification with release notes
2. Options to:
   - Install and Relaunch
   - Download in background
   - Skip this version
   - Remind me later

## Security

### EdDSA Signatures

Sparkle uses EdDSA (Edwards-curve Digital Signature Algorithm) to ensure:
- Updates come from the legitimate developer
- Updates haven't been tampered with
- Protection against man-in-the-middle attacks

### Best Practices

1. **Never share private key**: Store securely, never commit to Git
2. **Use HTTPS**: Host appcast and downloads over HTTPS
3. **Code signing**: Sign your app with a Developer ID certificate
4. **Notarization**: Notarize releases with Apple for Gatekeeper
5. **Test signatures**: Verify signature before publishing

## Troubleshooting

### Updates Not Working

**Check these common issues:**

1. **SUFeedURL not configured**: Verify URL in Info.plist
2. **Public key mismatch**: Ensure SUPublicEDKey matches generated key
3. **Signature invalid**: Re-sign the DMG with correct private key
4. **Network blocked**: Check firewall/proxy settings
5. **Appcast not accessible**: Verify URL returns valid XML

### Debug Mode

Enable Sparkle debug logging:

```bash
defaults write com.cmdlab.aio-ssl-tool SUEnableDebugging -bool YES
```

View logs:
```bash
log stream --predicate 'subsystem contains "org.sparkle-project"' --level debug
```

## Configuration Options

### Info.plist Keys

| Key | Type | Description | Default |
|-----|------|-------------|---------|
| `SUFeedURL` | String | URL to appcast XML | Required |
| `SUPublicEDKey` | String | EdDSA public key | Required |
| `SUEnableAutomaticChecks` | Boolean | Enable automatic checks | true |
| `SUScheduledCheckInterval` | Integer | Check interval (seconds) | 86400 (24hrs) |
| `SUAutomaticallyUpdate` | Boolean | Install without asking | false |
| `SUAllowsAutomaticUpdates` | Boolean | Allow background install | true |

## References

- [Sparkle Documentation](https://sparkle-project.org/documentation/)
- [Sparkle GitHub](https://github.com/sparkle-project/Sparkle)
- [Publishing Updates](https://sparkle-project.org/documentation/publishing/)
- [Security Best Practices](https://sparkle-project.org/documentation/security/)

## Support

If you encounter issues with automatic updates:

1. Check Settings > Updates for last check time
2. Manually click "Check for Updates"
3. Review Console.app for Sparkle logs
4. Verify appcast.xml is accessible
5. Open an issue on GitHub with details
