# Releases

This directory contains pre-built binaries for AIO SSL Tool.

## Current Version: v6.0.0

### Download Links

- **macOS**: [AIOSSLTool-macOS-v6.0.0.dmg](v6.0.0/AIOSSLTool-macOS-v6.0.0.dmg) (1.5 MB)
- **Windows**: [AIOSSLTool-Windows-v6.0.0.exe](v6.0.0/AIOSSLTool-Windows-v6.0.0.exe) (18 MB)

## Installation

### macOS
1. Download the DMG file
2. Open and drag to Applications
3. First launch: Right-click → Open
4. Requires macOS 14.0+ (Sonoma/Sequoia)

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
