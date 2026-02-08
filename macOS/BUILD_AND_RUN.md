# Building and Running AIO SSL Tool on macOS

## System Requirements
- **macOS 14.0** (Sonoma) or later
- Xcode Command Line Tools
- Swift 5.9 or later

## Quick Start

### 1. Build the App
```bash
cd macOS/AIOSSLTool
./build.sh release
```

### 2. Run the App
```bash
open "AIO SSL Tool.app"
```

## What Was Fixed

The "damaged or incomplete" error was caused by:
1. **Missing code signature** - The app wasn't signed at all
2. **Quarantine attributes** - macOS marks downloaded/unsigned apps as quarantined
3. **Incorrect build configuration** - Code signing was completely disabled

### Solutions Applied:
✅ **Ad-hoc code signing** - App is now signed with ad-hoc signature (no developer certificate needed)  
✅ **Quarantine removal** - Build script automatically removes quarantine attributes  
✅ **Updated minimum macOS version** - Set to 14.0 (Sonoma) for better compatibility  
✅ **Fixed Info.plist** - Removed Xcode build variables, added proper bundle identifiers

## Troubleshooting

### If you still see "damaged or incomplete" error:

**Option 1: Remove quarantine manually**
```bash
xattr -cr "AIO SSL Tool.app"
open "AIO SSL Tool.app"
```

**Option 2: Right-click open**
1. Right-click on "AIO SSL Tool.app"
2. Select "Open"
3. Click "Open" in the security dialog
4. The app will now run and be trusted going forward

**Option 3: Override Gatekeeper (not recommended)**
```bash
sudo spctl --master-disable  # Disable Gatekeeper
open "AIO SSL Tool.app"
sudo spctl --master-enable   # Re-enable Gatekeeper after
```

### If build fails:

1. **Check Xcode Command Line Tools:**
   ```bash
   xcode-select --install
   ```

2. **Verify Swift version:**
   ```bash
   swift --version  # Should be 5.9 or later
   ```

3. **Clean build:**
   ```bash
   rm -rf .build "AIO SSL Tool.app"
   ./build.sh release
   ```

## Build Options

**Release build (optimized, smaller binary):**
```bash
./build.sh release
```

**Debug build (with debug symbols):**
```bash
./build.sh debug
```

## Code Signing Details

The app uses **ad-hoc signing** (`codesign --sign -`), which:
- ✅ Works without a paid Apple Developer account
- ✅ Allows local execution
- ✅ Prevents the "damaged" error
- ❌ Cannot be distributed via Mac App Store
- ❌ Cannot be notarized by Apple

To verify the signature:
```bash
codesign -dv "AIO SSL Tool.app"
codesign --verify --verbose "AIO SSL Tool.app"
```

## macOS Version Compatibility

| macOS Version | Codename | Supported |
|---------------|----------|-----------|
| 15.x          | Sequoia  | ✅ Yes    |
| 14.x          | Sonoma   | ✅ Yes    |
| 13.x          | Ventura  | ⚠️ Maybe* |
| 12.x & older  | -        | ❌ No     |

*Note: While the Package.swift requires macOS 14+, you could try building on 13.x by modifying the platform requirement, but it's not officially supported.

## Distribution

For distributing to other users:
1. Build with `./build.sh release`
2. Archive: `zip -r "AIO-SSL-Tool-macOS.zip" "AIO SSL Tool.app"`
3. Users must: Right-click → Open (first time only)

For proper distribution without warnings, you'd need:
- Paid Apple Developer account ($99/year)
- Developer ID certificate
- App notarization

## Support

If you encounter issues:
1. Check that you're on macOS 14.0 or later
2. Ensure Xcode Command Line Tools are installed
3. Try the troubleshooting steps above
4. Check the console: `Console.app` → filter by "AIOSSLTool"
