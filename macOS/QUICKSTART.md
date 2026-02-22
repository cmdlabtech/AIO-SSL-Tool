# Quick Start Guide - macOS Version

## Getting Started with the macOS Native App

### Prerequisites
- macOS 13.0 (Ventura) or later
- Xcode 14.0 or later (free from App Store)

### Method 1: Open in Xcode (Recommended)

This is the easiest method:

1. **Install Xcode** from the Mac App Store if you haven't already

2. **Navigate to the project**:
   ```bash
   cd /Users/cameron/Documents/GitHub/AIO-SSL-Tool/macOS/AIOSSLTool
   ```

3. **Create the Xcode project** (first time only):
   ```bash
   # Option A: Generate from Swift Package
   swift package generate-xcodeproj
   
   # Option B: Manual creation (preferred)
   # Open Xcode → File → New → Project → macOS App
   # - Name: AIOSSLTool
   # - Interface: SwiftUI
   # - Then drag all .swift files into the project
   ```

4. **Open the project**:
   ```bash
   open AIOSSLTool.xcodeproj
   ```

5. **Configure Signing**:
   - Click on the project name in the left sidebar
   - Select "AIOSSLTool" under Targets
   - Go to "Signing & Capabilities" tab
   - Select your Team (use your Apple ID)

6. **Build and Run**:
   - Press `⌘R` or click the Play button
   - The app will launch!

### Method 2: Automated Build Script

Use the included build script:

```bash
cd /Users/cameron/Documents/GitHub/AIO-SSL-Tool/macOS/AIOSSLTool

# Make the script executable
chmod +x build.sh

# Build debug version
./build.sh

# Build release version
./build.sh release

# Run the app
open .build/Build/Products/Debug/AIOSSLTool.app
```

### Method 3: Manual Swift Build

For advanced users:

```bash
cd /Users/cameron/Documents/GitHub/AIO-SSL-Tool/macOS/AIOSSLTool

# Build
swift build -c release

# The executable will be at:
.build/release/AIOSSLTool
```

## File Structure

All source files are in `/Users/cameron/Documents/GitHub/AIO-SSL-Tool/macOS/AIOSSLTool/`:

```
AIOSSLTool/
├── AIOSSLToolApp.swift              # App entry point (@main)
├── ContentView.swift                 # Main UI
├── ViewModels/
│   └── SSLToolViewModel.swift       # Business logic
├── Views/
│   ├── CSRGenerationView.swift      # CSR generator
│   ├── ExtractPFXView.swift         # PFX extractor
│   └── SettingsView.swift           # Settings
├── Utils/
│   └── CertificateUtils.swift       # Certificate operations
├── Info.plist                        # App metadata
├── AIOSSLTool.entitlements          # Security permissions
├── Package.swift                     # Swift package definition
└── build.sh                          # Build script
```

## Creating a Proper macOS App

### Using Xcode (Recommended)

1. **Create New Xcode Project**:
   ```
   File → New → Project
   Choose: macOS → App
   ```

2. **Project Settings**:
   - Product Name: `AIOSSLTool`
   - Team: Select your Apple ID
   - Organization: `CMDLAB` (or your organization)
   - Bundle Identifier: `com.cmdlab.aio-ssl-tool`
   - Interface: SwiftUI
   - Language: Swift
   - Include Tests: No

3. **Add Files**:
   - Delete the default `ContentView.swift` and `AIOSSLToolApp.swift`
   - Drag all `.swift` files from the repository into the project
   - Ensure "Copy items if needed" is checked
   - Create Groups to match the folder structure:
     - ViewModels group
     - Views group  
     - Utils group

4. **Add Info.plist**:
   - Drag `Info.plist` into the project
   - In project settings, set "Info.plist File" to point to it

5. **Add Entitlements**:
   - Drag `AIOSSLTool.entitlements` into the project
   - In project settings → Signing & Capabilities
   - Set Code Signing Entitlements to `AIOSSLTool.entitlements`

6. **Build Settings**:
   - Minimum macOS version: 13.0
   - Enable Hardened Runtime
   - Enable automatic code signing

7. **Build and Run**: Press `⌘R`

## Usage

Once the app is running:

1. **Select Save Location** - Choose where to save files
2. **Browse Certificate** - Load an SSL certificate (.cer, .crt, .pem)
3. **Create Full Chain** - Automatically builds the certificate chain
4. **Browse Private Key** - Load your private key (or generate via File menu)
5. **Create PFX** - Generate a password-protected PFX file

### Additional Features

**File Menu:**
- Generate CSR and Private Key - Create new certificate requests
- Extract Private Key from PFX/P12 - Extract keys from existing PFX files

## Troubleshooting

### "No such module 'SwiftUI'"
- Make sure you're using Xcode with macOS 13+ deployment target

### Code Signing Issues
- In Xcode: Signing & Capabilities → Select your team
- For testing, you can disable signing temporarily

### "Cannot find type 'SecCertificate'"
- Ensure you're building for macOS (not iOS or other platforms)
- Security framework is macOS-only

### Build Script Fails
- Open the project in Xcode and build manually
- Check that all files are included in the target

## Advantages Over Python Version

✅ **Native Performance** - Runs as compiled native code  
✅ **Better UI** - Native macOS controls and appearance  
✅ **System Integration** - Direct keychain access  
✅ **No Dependencies** - Standalone app, no Python required  
✅ **Sandboxing** - Enhanced security with macOS sandboxing  
✅ **App Store Ready** - Can be distributed via Mac App Store  

## Next Steps

- **Customize**: Modify the UI in SwiftUI files
- **Extend**: Add more certificate operations in `CertificateUtils.swift`  
- **Distribute**: Archive and export for distribution
- **Submit**: Prepare for Mac App Store submission

## Support

For issues or questions:
1. Check the main README.md
2. Review Xcode build errors
3. Ensure all files are properly added to the target

Happy coding! 🚀
