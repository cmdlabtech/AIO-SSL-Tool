# AIO SSL Tool - AI Agent Instructions

## Overview
Dual-platform SSL tool: **Swift/SwiftUI (macOS)** + **Python/CustomTkinter (Windows)**. Local-only cert chain building, CSR generation, PFX creation, key extraction.

## Communication Rules
**Response Style**: Keep responses concise. Do NOT provide detailed "Changes Made" summaries after every edit. Only provide comprehensive summaries at final commit/release. During development, confirm actions briefly without listing all changes.

## Core Rules
**Standards**: Follow RFC 2986, RFC 5280, NIST SP 800-57, FIPS 186-4. SHA-256+ signatures, AES-256 encryption, RSA ≥2048, ECC P-256/384/521. Secure file perms (0600), no MD5/SHA-1.

**Security**: macOS uses Security framework + OpenSSL fallback. Windows uses cryptography lib. Secure temp files, proper cleanup.

**Build**: SPM only (no Xcode projects). Clean `.build/`, `*.app`, `*.dmg` before commits.

**Pre-Commit Testing (MANDATORY)**: 
- **ALWAYS** build and test locally before committing to minimize GitHub Actions runs
- Test build: `cd macOS/AIOSSLTool && swift build -c release`
- Test launch: Create .app bundle and verify it launches without errors
- Verify no compilation errors, warnings, or runtime crashes
- Only commit after successful local verification
- This reduces CI/CD costs and commit noise

**Dependency Updates (MANDATORY before every commit)**:
- **ALWAYS** check for and update crypto/security-related packages before committing:
  - **macOS (SPM)**: Check `Package.swift` for newer OpenSSL / dependency versions. Run `swift package update` and review changes in `Package.resolved`.
  - **Windows (pip)**: Check `windows/requirements.txt` for outdated packages. Run `pip list --outdated` and update pinned versions.
  - Key packages to watch: `cryptography`, `pyOpenSSL`, `cffi`, any OpenSSL SPM wrapper, Sparkle, and other security-sensitive dependencies.
- If any packages are updated, include a brief summary in the commit message listing which packages changed with their old → new versions. Example:
  ```
  Updated dependencies:
  - cryptography 42.0.5 → 43.0.1
  - cffi 1.16.0 → 1.17.0
  ```


**Releases**: 
- **BEFORE creating tags**: 
  1. Update `macOS/AIOSSLTool/Info.plist`: Increment `CFBundleShortVersionString` and `CFBundleVersion`
  2. Update `windows/aio_ssl_tool.py`: Update hardcoded version string in Settings view (search for "Version V")
  3. Update `windows/build.bat`: Update version in header comments
  4. Update `appcast.xml`: Add new version entry at top with correct sparkle:version, file size, and uppercase 'V' URLs
  5. Update `README.md` download links to new version (both macOS and Windows if applicable)
  6. Commit and push all changes
  7. Create and push tag
- Keep only latest + 3 prior releases/tags
- Use `./update_version.sh` for automated updates
- Naming: "VX.Y.Z" (both OS), "macOS VX.Y.Z" (single OS)
- Tags MUST start with uppercase 'V' (e.g., V6.1.2) to trigger GitHub Actions release workflow
- Workflow order: Update Info.plist → Update appcast.xml → Update README → Commit → Push → Tag → Push tag

## Architecture
**macOS**: SwiftUI MVVM, `SSLToolViewModel` core logic, Security framework, manual update checker
**Windows**: CustomTkinter, `aio_ssl_tool.py`, cryptography library

**Key Files**: 
- `macOS/AIOSSLTool/{Views/,ViewModels/,Utils/CertificateUtils.swift,Models/CSRDetails.swift,Info.plist}`
- `windows/{aio_ssl_tool.py,requirements.txt}`
- Root: `appcast.xml`, `README.md`

## App Icons & Branding
**macOS Icons (CRITICAL)**:
- **AppIcon.icns** must exist at `macOS/AIOSSLTool/AppIcon.icns` (1.1+ MB high-res) - MUST be committed to repo
- **HomeIcon.png** must exist at `macOS/AIOSSLTool/HomeIcon.png` (transparent PNG for home page display) - MUST be committed to repo
- Source file: `windows/HomeIcon.png` (71KB transparent RGBA PNG, 408x612) - same file should exist in both locations
- `Info.plist` must reference: `<key>CFBundleIconFile</key><string>AppIcon</string>`
- `build.sh` copies both icons to app bundle:
  - `cp AppIcon.icns "${APP_BUNDLE}/Contents/Resources/"`
  - `cp HomeIcon.png "${APP_BUNDLE}/Contents/Resources/"`
- **NEVER add HomeIcon.png or AppIcon.icns to .gitignore** - GitHub Actions needs these files to build properly
- **NEVER use hardcoded file paths in Swift code** - Load images ONLY from Bundle.main, never from absolute paths
- **ALWAYS verify icons exist in built app**: Check `AIO SSL Tool.app/Contents/Resources/` for both files
- **CRITICAL: Keep build.sh and GitHub Actions workflow in sync** - Both must copy ALL resource files (AppIcon.icns AND HomeIcon.png) to app bundle. If build.sh copies a resource, .github/workflows/build.yml MUST also copy it. Missing resources cause fallback icons to display.
- AppIcon should be **1024x1024** with all standard macOS icon sizes (512, 256, 128, 32, 16)
- HomeIcon MUST be the transparent version from windows/HomeIcon.png, NOT new-icon.png

**Windows Icons**:
- Windows executable should use proper icon file
- Ensure icon is embedded during build process

**Image Display Rules (CRITICAL)**:
- **NEVER force images into square dimensions** - always maintain aspect ratio
- Calculate aspect ratio: `aspect_ratio = width / height`
- When resizing, adjust one dimension and calculate the other: `new_width = max_height * aspect_ratio`
- For CustomTkinter: Load image, get dimensions, calculate size maintaining ratio
- For SwiftUI: Use `.aspectRatio(contentMode: .fit)` or `.scaledToFit()`
- Example (Python/CTk):
  ```python
  img = Image.open(path)
  img_width, img_height = img.size
  aspect_ratio = img_width / img_height
  display_width = int(max_height * aspect_ratio)
  icon_image = ctk.CTkImage(img, size=(display_width, max_height))
  ```
- **HomeIcon.png is 408x612** - aspect ratio ~0.667, never use square dimensions

**Cross-Platform UI Consistency (CRITICAL)**:
- **ALWAYS match dialog/popup messages exactly between macOS and Windows**
- When implementing alerts, warnings, or confirmations, copy the exact text from the macOS app
- This includes: titles, message content, button labels (where technically possible)
- Key dialogs to keep in sync:
  - Settings Advanced Options toggle: "⚠️ SAFETY OFF ⚠️" with humorous warning
  - PFX Generator Advanced Options: "Advanced Options - Caution" with detailed explanation
  - Any error messages, success messages, or user-facing prompts
- When platform limitations prevent exact button text (e.g., tkinter messagebox), match title and message exactly
- Maintain consistent tone, formatting, and emoji usage across platforms

**Verification Steps**:
1. Before any release: Check both icon files exist and are not corrupted
2. After build: Verify `ls -la 'AIO SSL Tool.app/Contents/Resources/'` shows AppIcon.icns and HomeIcon.png
3. Visual check: Open app and verify AppIcon appears in Dock/Finder and HomeIcon displays on home page
4. Never commit builds without verifying both icons are present

## Workflows
**Build**: `cd macOS/AIOSSLTool && ./build.sh [debug]`
**Release**: `./release.sh X.Y.Z` → creates DMG, appcast entry, release notes, auto-updates README/appcast
**Update Versions**: `./update_version.sh <platform> <version> [size]` (auto-run by release.sh & GitHub Actions)
**GitHub Release**: `gh release create vX.Y.Z <DMG> --title "vX.Y.Z"` or push tag for auto-build
**Cleanup**: `swift package clean && rm -rf .build *.app *.dmg`

## GitHub Actions Simulation
**CRITICAL**: Simulate GitHub Actions behavior locally before committing:
- Match the exact workflow steps in `.github/workflows/build.yml`
- Use the same Swift version, build flags, and commands
- Test DMG creation with identical naming: `AIOSSLTool-macOS-vX.Y.Z.dmg`
- Verify artifact naming matches what workflow produces
## Release Checklist
1. **Local testing first**: Build, launch, and test app locally
2. GitHub Actions compatible code
3. `./release.sh X.Y.Z` (auto-updates README + appcast via `update_version.sh`)
4. Test DMG locally
5. Create GitHub Release: `gh release create vX.Y.Z <DMG> --title "vX.Y.Z"`
6. **Version links auto-updated** by GitHub Actions on tag push
7. Push to GitHub: `git tag vX.Y.Z && git push origin vX.Y.Z`
8. **Cleanup old releases** (keep latest + 3 prior):
   - List: `gh release list`
   - Delete old: `gh release delete vX.X.X --yes`
   - Delete tags: `git tag -d vX.X.X && git push origin :refs/tags/vX.X.X`
   - Clean local: `rm -rf releases/vX.X.X`
   - Commit: `git add releases && git commit -m "Clean up old releases"`

## Release Management - Critical Rules

**Release Naming Scheme (STRICT)**:
- **macOS only**: `macOS VX.Y.Z` (e.g., "macOS V6.0.4")
- **Windows only**: `Windows VX.Y.Z` (e.g., "Windows V6.1.0")
- **Both platforms**: `VX.Y.Z` (e.g., "V6.1.1")
- Tag name ALWAYS matches release title
- **Tags MUST start with uppercase 'V'** (e.g., V6.1.2) to trigger GitHub Actions release workflow
- **Keep only latest + 3 prior releases/tags** - delete older versions
- Never create releases with inconsistent naming

**Asset File Naming (STRICT)**:
- macOS DMG: `AIO-SSL-Tool-macOS-VX.Y.Z.dmg`
- Windows EXE: `AIO-SSL-Tool-Windows-VX.Y.Z.exe`
- Format: `AIO-SSL-Tool-[os]-VX.Y.Z.[extension]`
- GitHub Actions workflow enforces this naming automatically

**NEVER manually upload duplicate assets**: GitHub Actions automatically creates properly named assets. Do NOT manually upload additional files.

**Deleting draft releases**: 
- ALWAYS check if drafts share a tag with a published release
- Use `gh api` to delete draft releases by ID, NOT by tag
- Command: `gh api repos/:owner/:repo/releases --jq '.[] | select(.draft == true) | .id' | xargs -I {} gh api -X DELETE "repos/:owner/:repo/releases/$id"`
- NEVER use `gh release delete <tag>` when multiple releases share the same tag

**Workflow runs cleanup**:
- Regularly clean old/failed runs to keep Actions list manageable
- Delete failed: `gh run list --limit 100 --json databaseId,conclusion --jq '.[] | select(.conclusion == "failure") | .databaseId' | xargs -I {} gh run delete {}`
- Keep only recent 20 successful runs for history

**README Download Links**:
- macOS: `https://github.com/cmdlabtech/AIO-SSL-Tool/releases/download/VX.Y.Z/AIO-SSL-Tool-macOS-VX.Y.Z.dmg`
- Windows: `https://github.com/cmdlabtech/AIO-SSL-Tool/releases/download/VX.Y.Z/AIO-SSL-Tool-Windows-VX.Y.Z.exe`
- **ALWAYS use versioned names** in README.md download links
- Never use generic names - they cause duplicate downloads and version confusion
