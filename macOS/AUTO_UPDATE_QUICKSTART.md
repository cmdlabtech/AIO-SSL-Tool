# Auto-Update Quick Start Guide

This guide will get you up and running with automatic updates in under 10 minutes.

## Prerequisites

- macOS 14.0 or later
- Xcode or Swift toolchain
- GitHub repository for hosting releases
- Homebrew (for installing Sparkle)

## Step 1: Install Sparkle Tools (2 minutes)

```bash
brew install sparkle
```

This installs the `generate_keys` and `sign_update` commands needed for signing releases.

## Step 2: Generate Signing Keys (1 minute)

```bash
cd macOS/AIOSSLTool
./generate_keys.sh
```

This creates two files:
- `sparkle_eddsa_public.key` - Add to your Info.plist
- `sparkle_eddsa_private.key` - Keep secret, used for signing

**Important**: The private key is automatically added to `.gitignore`. Never commit it!

## Step 3: Configure Info.plist (2 minutes)

Open `macOS/AIOSSLTool/Info.plist` and update:

```xml
<!-- Replace YOUR_USERNAME with your GitHub username -->
<key>SUFeedURL</key>
<string>https://raw.githubusercontent.com/YOUR_USERNAME/AIO-SSL-Tool/main/appcast.xml</string>

<!-- Replace with your public key from Step 2 -->
<key>SUPublicEDKey</key>
<string>PASTE_YOUR_PUBLIC_KEY_HERE</string>
```

## Step 4: Build Your App (2 minutes)

```bash
cd macOS/AIOSSLTool
./build.sh
```

The app is now ready with auto-update support built-in!

## Step 5: Create Your First Release (3 minutes)

When ready to release version 6.0.1:

```bash
./release.sh 6.0.1
```

This automated script:
1. Updates version numbers
2. Builds the app
3. Creates a DMG
4. Signs it with your private key
5. Generates an appcast entry
6. Creates release notes template

## Step 6: Publish to GitHub (1 minute)

Follow the instructions from the release script:

```bash
# Create GitHub release
gh release create v6.0.1 releases/v6.0.1/AIOSSLTool-macOS-v6.0.1.dmg \
  --title "AIO SSL Tool v6.0.1" \
  --notes-file releases/v6.0.1/RELEASE_NOTES.md

# Update appcast.xml
# Copy the generated entry to the top of appcast.xml

# Commit and push
git add appcast.xml
git commit -m "Release v6.0.1"
git push
```

## Done! 🎉

Users will now automatically receive updates. When they launch your app:
- It checks for updates in the background
- If a new version is found, they get a notification
- They can install with one click
- The old version is seamlessly replaced

## Testing Updates Locally

Want to test before publishing?

1. Build two versions (e.g., 6.0.0 and 6.0.1)
2. Host appcast.xml on a local server:
   ```bash
   python3 -m http.server 8000
   ```
3. Temporarily update SUFeedURL to `http://localhost:8000/appcast.xml`
4. Launch the older version and check for updates

## User Experience

Users can manage updates in **Settings > Updates**:
- View current version
- See last update check time
- Toggle automatic checks
- Toggle automatic downloads
- Manually check for updates

## Troubleshooting

**"Updates not working"**
- Verify SUFeedURL in Info.plist points to your appcast.xml
- Check that SUPublicEDKey matches your public key
- Ensure appcast.xml is accessible at the URL

**"Invalid signature error"**
- Re-sign your DMG with the correct private key
- Verify the signature in appcast.xml matches

**"Can't find sign_update command"**
- Install Sparkle: `brew install sparkle`
- Or download from: https://github.com/sparkle-project/Sparkle/releases

## Security Notes

✅ **DO:**
- Store private key securely
- Back up private key (you can't recover it!)
- Use HTTPS for appcast and downloads
- Sign your app with Developer ID
- Notarize releases with Apple

❌ **DON'T:**
- Commit private key to Git
- Share private key publicly
- Use HTTP for appcast URL
- Skip signature verification

## More Information

- Full documentation: See [AUTO_UPDATE_GUIDE.md](AUTO_UPDATE_GUIDE.md)
- Sparkle docs: https://sparkle-project.org/documentation/
- Appcast specification: https://sparkle-project.org/documentation/publishing/

## Support

Having trouble? Check:
1. Console.app for Sparkle logs
2. Settings > Updates for last check time
3. [AUTO_UPDATE_GUIDE.md](AUTO_UPDATE_GUIDE.md) for detailed troubleshooting

---

**Ready to update?** Just run `./release.sh <version>` and follow the prompts!
