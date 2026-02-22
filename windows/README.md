# AIO SSL Tool - Windows Edition

Professional SSL Certificate Management Tool for Windows.

## Quick Start

### Download Pre-Built Executable
Get the latest release from [GitHub Releases](https://github.com/cmdlabtech/AIO-SSL-Tool/releases) - no installation required!

### Run from Source
```cmd
test.bat
```

### Build Your Own
```cmd
build.bat
```

## Features

- **Certificate Chain Builder** - Automatically builds complete certificate chains from Windows certificate store
- **CSR Generator** - Create Certificate Signing Requests with RSA or ECC keys
- **PFX Generator** - Convert certificate chains and private keys to PFX/P12 format
- **Key Extractor** - Extract private keys from PFX files
- **Modern UI** - Sidebar navigation with dedicated views for each tool

## Interface

The Windows app mirrors the macOS version with:
- **Sidebar Navigation** - Quick access to all tools
- **Home View** - Working directory setup and welcome screen
- **Dedicated Views** - Each tool has its own clean interface
- **Dark Theme** - Modern dark mode interface

## Security & Standards

### Standards Compliance
- RFC 2986: PKCS #10 Certification Request Syntax
- RFC 5280: X.509 Public Key Infrastructure
- NIST SP 800-57: Key Management Recommendations
- FIPS 186-4: Digital Signature Standard

### Cryptographic Features
- **RSA Keys**: 2048, 3072, 4096 bits (minimum 2048 per NIST)
- **ECC Keys**: P-256, P-384, P-521 (NIST-approved curves)
- **Signatures**: SHA-256 (NIST SP 800-57 compliant)
- **Encryption**: AES-256 for private key protection

### Privacy
- **100% Local** - No network calls, all processing happens on your machine
- **No Telemetry** - No data collection or tracking
- **Secure Storage** - Private keys encrypted with AES-256

## System Requirements

- Windows 10 or later
- No additional dependencies for pre-built executable
- For building from source: Python 3.8+

## Development

### File Structure
```
windows/
├── aio_ssl_tool.py              # Main application
├── AIO-SSL-Tool-Windows.spec    # PyInstaller configuration
├── requirements.txt             # Python dependencies
├── build.bat                    # Build script
├── release.bat                  # Release script
├── test.bat                     # Test script
├── BUILD.md                     # Build documentation
├── HomeIcon.png                 # App icon (220x220)
└── icon-ico.ico                 # Windows icon
```

### Build Scripts

**test.bat** - Run without building
```cmd
test.bat
```

**build.bat** - Build executable
```cmd
build.bat
```

**release.bat** - Create versioned release
```cmd
release.bat 6.1.1
```

See [BUILD.md](BUILD.md) for detailed build instructions.

## Usage

### Setting Up
1. Launch the application
2. Set your working directory from the Home view
3. Select a tool from the sidebar

### Certificate Chain Builder
1. Select a certificate file
2. Click "Build Chain"
3. Full chain saved as `FullChain.cer`

### CSR Generator
1. Click "Generate New CSR + Private Key"
2. Fill in certificate details
3. Choose key type (RSA/ECC) and size
4. Optionally set a passphrase
5. Files saved: `csr.pem` and `private_key.pem`

### PFX Generator
1. Select private key file
2. Enter key password (if encrypted)
3. Set PFX password
4. Click "Create PFX"
5. Output: `FullChain-pfx.pfx`

### Key Extractor
1. Select PFX/P12 file
2. Enter PFX password
3. Click "Extract Private Key"
4. Save unencrypted private key

## Troubleshooting

### Application Won't Start
- Ensure you're running Windows 10 or later
- Try right-click → Run as Administrator
- Check Windows Defender/Antivirus isn't blocking it

### "Windows protected your PC" Warning
- This is normal for unsigned executables
- Click "More info" → "Run anyway"
- Or build from source yourself

### Certificate Chain Building Fails
- Ensure certificate is valid
- Check Windows certificate store has intermediate/root CAs
- Try importing missing CAs to Windows certificate store

### PFX Creation Fails
- Verify private key matches certificate
- Check password is correct for encrypted keys
- Ensure FullChain.cer exists

## Support

- **Issues**: [GitHub Issues](https://github.com/cmdlabtech/AIO-SSL-Tool/issues)
- **Documentation**: See BUILD.md and main README.md
- **Source Code**: [GitHub Repository](https://github.com/cmdlabtech/AIO-SSL-Tool)

## License

See main repository LICENSE file.

## Changelog

See main CHANGELOG.md for version history.
