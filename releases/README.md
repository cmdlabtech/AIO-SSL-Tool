# Releases

This directory contains release notes and metadata for AIO SSL Tool releases.

## Current Version: v6.0.4

### Download Links

**All releases are available on the [GitHub Releases page](https://github.com/cmdlabtech/AIO-SSL-Tool/releases)**

- **macOS v6.0.4**: [Download DMG](https://github.com/cmdlabtech/AIO-SSL-Tool/releases/download/v6.0.4/AIOSSLTool-macOS-v6.0.4.dmg)
- **macOS v6.0.2**: [Download DMG](https://github.com/cmdlabtech/AIO-SSL-Tool/releases/download/v6.0.2/AIOSSLTool-macOS-v6.0.2.dmg)
- **macOS v6.0.0**: [Download DMG](https://github.com/cmdlabtech/AIO-SSL-Tool/releases/download/v6.0.0/AIOSSLTool-macOS-v6.0.0.dmg)

> **Note:** DMG files are not stored in this repository to keep it lightweight. Download them from GitHub Releases.

## Installation

### macOS
1. Download the DMG file
2. Open and drag to Applications
3. First launch: Right-click → Open
4. Requires macOS 14.0+ (Sonoma/Sequoia)

**🔄 Automatic Updates**: The macOS version includes automatic updates! Once installed, the app will notify you when new versions are available and can update itself with one click. No need to manually download future releases.

### Windows
1. Download the EXE file
2. Run directly - no installation required
3. Windows 10/11 (64-bit)

## Version History

- **v6.0.0** (2026-02-08): Native macOS app, improved UI, custom icon
- **v5.0.0**: Python-based cross-platform version

## Verification

Check file integrity:

**macOS DMG:**
```bash
shasum -a 256 AIOSSLTool-macOS-v6.0.0.dmg
```

**Windows EXE:**
```powershell
Get-FileHash AIOSSLTool-Windows-v6.0.0.exe -Algorithm SHA256
```

## Notes

- All releases are ad-hoc signed (macOS) or unsigned (Windows)
- Files are safe but may trigger OS security warnings
- See main README for troubleshooting steps
