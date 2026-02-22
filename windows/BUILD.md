# Windows Build Guide

This directory contains the Windows build scripts for AIO SSL Tool.

## Quick Start

### Test Without Building
```cmd
test.bat
```
Runs the Python application directly without building an executable.

### Build Executable
```cmd
build.bat
```
Creates `dist\AIO-SSL-Tool-Windows.exe`

### Create Release
```cmd
release.bat 6.1.1
```
Builds and packages a versioned release.

## For Most Users

Download pre-built executables from [GitHub Releases](https://github.com/cmdlabtech/AIO-SSL-Tool/releases) - no build required!

## Build Process

The build process uses PyInstaller with a spec file:

1. **Check Requirements** - Python 3.8+, required files, spec file
2. **Install Dependencies** - PyInstaller and project requirements
3. **Clean Previous Builds** - Remove build/ and dist/ directories
4. **Build Executable** - Uses AIO-SSL-Tool-Windows.spec
5. **Verify Build** - Check executable exists and display size

## Build Scripts

### test.bat
Quick development testing - runs Python directly without compilation.

### build.bat
Builds standalone executable using PyInstaller and the spec file.

### release.bat
Complete release workflow with versioning and release notes.
Usage: `release.bat X.Y.Z`

## Icon Configuration

Icons are configured in `AIO-SSL-Tool-Windows.spec`:

### Executable Icon
```python
icon=['icon-ico.ico']
```

### Bundled Resources
```python
datas=[('HomeIcon.png', '.'), ('icon-ico.ico', '.')]
```

### Runtime Loading
```python
def resource_path(relative_path):
    base_path = getattr(sys, '_MEIPASS', os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(base_path, relative_path)
```

## Requirements

- Windows 10 or later
- Python 3.8+
- PyInstaller (auto-installed)

## Troubleshooting

### Python not found
Install from [python.org](https://www.python.org/downloads/) with "Add to PATH" enabled.

### Build fails
Clear cache: `rmdir /s build dist`
Reinstall: `pip install --force-reinstall pyinstaller`

### Large executable
Normal for PyInstaller bundles (includes Python runtime + dependencies).
Enable UPX compression in spec file for smaller size.

Build artifacts are created in:
- `dist/AIO-SSL-Tool.exe` - Final executable (~20-30 MB)
- `build/` - Temporary build files (deleted by --clean)
- `AIO-SSL-Tool.spec` - PyInstaller specification file
