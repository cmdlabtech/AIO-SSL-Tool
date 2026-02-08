# AIO SSL Tool v6.0.2

## 🎉 Auto-Update Infrastructure

This release introduces the foundation for automatic updates in the macOS version:

### New Features
- **Settings > Updates UI** - Complete interface for managing updates
  - View current version and build number
  - Last update check time display
  - Toggle automatic update checks
  - Toggle automatic downloads
  - Manual "Check for Updates" button

- **Auto-Update Framework** - Sparkle integration (UI-ready)
  - UpdaterViewModel for state management
  - Background update checking on launch
  - User preference persistence
  - Update feed configuration

### Documentation
- Comprehensive auto-update guide
- Quick start setup instructions  
- Automated release scripts
- Configuration verification tools

### Infrastructure
- Created appcast.xml template for update feed
- Added release automation scripts
- Generated EdDSA signing keys
- Configured security settings

### Notes
The auto-update **UI is fully functional** but update checking is temporarily disabled while we resolve framework embedding. Users can see the Settings > Updates interface and future releases will enable full automatic update functionality.

---

**Download:** `AIOSSLTool-macOS-v6.0.2.dmg` (1.6 MB)

**Installation:** Drag to Applications folder. First launch: right-click → Open

**Requirements:** macOS 14.0+ (Sonoma/Sequoia)
