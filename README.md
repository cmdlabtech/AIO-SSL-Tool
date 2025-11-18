# AIO SSL Tool

**The fastest way to turn any server certificate into a complete, trusted chain and ready-to-use PFX — in seconds.**

A lightweight, zero-install Windows GUI tool built for sysadmins and DevOps who need perfect SSL certificates without the hassle.

[AIO SSL Tool Latest Release](https://github.com/cmdlabtech/aio-ssl-tool/releases/latest)

### Features
- Drag & drop certificate and private key
- Automatically finds and pairs the correct private key (modulus match)
- Builds the full trusted chain using Windows root store first, then AIA fallback
- Shows live certificate details (Subject, Issuer, Validity, SANs, etc.)
- Export PFX with custom Friendly Name (perfect for IIS, Windows, Azure)
- One-click copy full chain to clipboard
- Tiny single executable – no installation, no dependencies
- Works completely offline after first run

### Why admins use it every day
- Eliminates manual intermediate hunting
- Fixes “certificate not trusted” errors instantly
- Produces clean PFX files Windows and IIS accept without warnings
- Saves hours on certificate deployments

### Build (optional)
```bash
pyinstaller --onefile --windowed --icon=icon-ico.ico --name="AIO SSL Tool" aio_ssl_tool.py
