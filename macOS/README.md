# AIO SSL Tool - macOS Native Version

A modern, native macOS application for SSL certificate management built with Swift and SwiftUI.

## Features

- **Certificate Chain Building**: Automatically build complete certificate chains from any certificate
- **CSR Generation**: Generate Certificate Signing Requests with custom details and SANs
- **Private Key Management**: Extract private keys from PFX/P12 files
- **PFX Creation**: Create PFX files from certificates and private keys
- **Automatic Updates**: Built-in automatic updates powered by Sparkle framework
- **Native macOS Integration**: Uses macOS Security framework and system keychain
- **Modern UI**: Built with SwiftUI for a native macOS experience

## Automatic Updates

The app includes seamless automatic updates using the Sparkle framework:

- Updates check automatically in the background
- One-click installation replaces existing app
- Configurable in Settings > Updates
- EdDSA-signed for security

**For Developers**: See [AUTO_UPDATE_QUICKSTART.md](AUTO_UPDATE_QUICKSTART.md) for setup instructions.

## Requirements

- **macOS**: 13.0 (Ventura) or later
- **Xcode**: 14.0 or later
- **Swift**: 5.7 or later

## Building from Source

### Option 1: Using Xcode

1. Open the project:
   ```bash
   cd macOS/AIOSSLTool
   open AIOSSLTool.xcodeproj
   ```
   
   If the project file doesn't exist, create it:
   ```bash
   cd macOS/AIOSSLTool
   swift package init --type executable --name AIOSSLTool
   ```

2. In Xcode:
   - Select your development team in Signing & Capabilities
   - Choose your target device (Any Mac)
   - Press ⌘R to build and run

### Option 2: Command Line Build

```bash
cd macOS/AIOSSLTool
swift build -c release
```

The compiled binary will be in `.build/release/AIOSSLTool`

### Creating an App Bundle

To create a proper macOS app bundle:

1. Open in Xcode
2. Product → Archive
3. Distribute App → Copy App
4. The `.app` bundle will be exported to your chosen location

## Project Structure

```
macOS/AIOSSLTool/
├── AIOSSLToolApp.swift          # Main app entry point
├── ContentView.swift             # Main interface
├── ViewModels/
│   └── SSLToolViewModel.swift   # Business logic and state management
├── Views/
│   ├── CSRGenerationView.swift  # CSR generation dialog
│   ├── ExtractPFXView.swift     # PFX extraction dialog
│   └── SettingsView.swift       # Settings/About view
├── Utils/
│   └── CertificateUtils.swift   # Certificate operations using Security framework
├── Info.plist                    # App configuration
└── AIOSSLTool.entitlements      # Security entitlements
```

## Creating the Xcode Project

If you need to create the Xcode project from scratch:

```bash
cd /Users/cameron/Documents/GitHub/AIO-SSL-Tool
mkdir -p macOS/AIOSSLTool
cd macOS/AIOSSLTool

# Create the Swift package
cat > Package.swift << 'EOF'
// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "AIOSSLTool",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "AIOSSLTool", targets: ["AIOSSLTool"])
    ],
    targets: [
        .executableTarget(
            name: "AIOSSLTool",
            path: ".",
            exclude: ["Info.plist"],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
EOF
```

Alternatively, create an Xcode project:

```bash
# Generate Xcode project
swift package generate-xcodeproj

# Or create a new Xcode project
# File → New → Project → macOS → App
# - Product Name: AIOSSLTool
# - Interface: SwiftUI
# - Language: Swift
# - Include Tests: No
```

## Manual Xcode Project Setup

1. **Create New Project**:
   - Open Xcode
   - File → New → Project
   - Choose "App" under macOS
   - Product Name: `AIOSSLTool`
   - Interface: SwiftUI
   - Language: Swift

2. **Add Source Files**:
   - Drag all `.swift` files from the repository into the project
   - Ensure "Copy items if needed" is checked
   - Organize into groups matching the directory structure

3. **Configure Signing**:
   - Select project in navigator
   - Select AIOSSLTool target
   - Signing & Capabilities tab
   - Choose your Team and Bundle Identifier

4. **Add Entitlements** (if needed):
   - Signing & Capabilities → + Capability
   - Add "Keychain Sharing" if accessing system keychain
   - Add "File Access" for reading/writing certificates

5. **Build Settings**:
   - Set minimum deployment target: macOS 13.0
   - Enable "Hardened Runtime"

## Usage

1. **Launch the app**
2. **Select Save Location**: Choose where to save generated files
3. **Browse Certificate**: Load your SSL certificate
4. **Create Full Chain**: Build the complete certificate chain
5. **Add Private Key**: Load or generate a private key
6. **Create PFX**: Generate a PFX file with password protection

### Additional Features

- **File → Generate CSR and Private Key**: Create new CSR with custom details
- **File → Extract Private Key from PFX/P12**: Extract keys from existing PFX files

## Security Notes

- The app uses macOS Security framework for certificate operations
- Private keys are handled securely in memory
- Password-protected keys and PFX files are supported
- The app requires appropriate file system permissions

## Differences from Python Version

This native macOS version offers several advantages:

1. **Better Performance**: Native code runs faster than interpreted Python
2. **Native UI**: SwiftUI provides native macOS controls and appearance
3. **System Integration**: Direct access to macOS keychain and certificate stores
4. **No Dependencies**: No need to install Python or external libraries
5. **App Store Ready**: Can be distributed through Mac App Store
6. **Sandboxing**: Supports macOS security features like sandboxing

## Technical Implementation

- **Security Framework**: Uses `SecCertificate`, `SecKey`, and `SecTrust` APIs
- **SwiftUI**: Modern declarative UI framework
- **Combine**: Reactive state management
- **async/await**: Modern Swift concurrency for certificate operations

## Troubleshooting

### "Developer Cannot Be Verified"

If you get this error when opening the app:
```bash
xattr -cr /path/to/AIOSSLTool.app
```

### Code Signing Issues

Ensure you have a valid Developer ID or run in Debug mode with your development certificate.

### Missing Entitlements

If the app can't access files or keychain:
1. Check Signing & Capabilities in Xcode
2. Add required entitlements (File Access, Keychain)

## Contributing

To contribute to the macOS version:

1. Maintain compatibility with macOS 13+
2. Follow Swift style guidelines
3. Use SwiftUI for all UI components
4. Leverage native Security framework APIs
5. Test on multiple macOS versions

## License

Same as the original Python version - check LICENSE file in repository root.

## Version History

- **v6.0** (2026): Initial macOS native version
  - Complete rewrite in Swift and SwiftUI
  - Native Security framework integration
  - Modern macOS design language

## Credits

Ported from the original Python version by CMDLAB.
macOS version utilizes Apple's Security framework for industrial-strength cryptography.
