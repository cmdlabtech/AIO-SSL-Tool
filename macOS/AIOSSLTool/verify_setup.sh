#!/bin/bash

# Setup Verification Script for Auto-Update System
# Checks if all components are properly configured

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}AIO SSL Tool - Auto-Update Setup Verification${NC}"
echo "=============================================="
echo ""

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

CHECKS_PASSED=0
CHECKS_FAILED=0

check_pass() {
    echo -e "${GREEN}✓ $1${NC}"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
}

check_fail() {
    echo -e "${RED}✗ $1${NC}"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
}

check_warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

echo "Checking configuration..."
echo ""

# 1. Check if Sparkle dependency exists in Package.swift
echo "📦 Checking Package.swift..."
if grep -q "sparkle-project/Sparkle" Package.swift; then
    check_pass "Sparkle dependency found in Package.swift"
else
    check_fail "Sparkle dependency missing from Package.swift"
fi
echo ""

# 2. Check if UpdaterViewModel exists
echo "📝 Checking ViewModels..."
if [ -f "ViewModels/UpdaterViewModel.swift" ]; then
    check_pass "UpdaterViewModel.swift exists"
else
    check_fail "UpdaterViewModel.swift not found"
fi
echo ""

# 3. Check if Info.plist has Sparkle keys
echo "⚙️  Checking Info.plist configuration..."
if [ -f "Info.plist" ]; then
    if grep -q "SUFeedURL" Info.plist; then
        check_pass "SUFeedURL found in Info.plist"
        
        # Check if it's still placeholder
        if grep -q "YOUR_USERNAME" Info.plist; then
            check_warn "SUFeedURL still has placeholder YOUR_USERNAME - needs update"
        fi
    else
        check_fail "SUFeedURL missing from Info.plist"
    fi
    
    if grep -q "SUPublicEDKey" Info.plist; then
        check_pass "SUPublicEDKey found in Info.plist"
        
        # Check if it's still placeholder
        if grep -q "REPLACE_WITH_YOUR_PUBLIC_KEY" Info.plist; then
            check_warn "SUPublicEDKey still has placeholder - run ./generate_keys.sh"
        fi
    else
        check_fail "SUPublicEDKey missing from Info.plist"
    fi
else
    check_fail "Info.plist not found"
fi
echo ""

# 4. Check if appcast.xml exists
echo "📡 Checking appcast.xml..."
if [ -f "../../appcast.xml" ]; then
    check_pass "appcast.xml exists"
    
    if grep -q "YOUR_USERNAME" ../../appcast.xml; then
        check_warn "appcast.xml has placeholder YOUR_USERNAME - needs update"
    fi
else
    check_fail "appcast.xml not found"
fi
echo ""

# 5. Check if release scripts exist and are executable
echo "🔧 Checking automation scripts..."
if [ -f "release.sh" ]; then
    check_pass "release.sh exists"
    if [ -x "release.sh" ]; then
        check_pass "release.sh is executable"
    else
        check_fail "release.sh is not executable (run: chmod +x release.sh)"
    fi
else
    check_fail "release.sh not found"
fi

if [ -f "generate_keys.sh" ]; then
    check_pass "generate_keys.sh exists"
    if [ -x "generate_keys.sh" ]; then
        check_pass "generate_keys.sh is executable"
    else
        check_fail "generate_keys.sh is not executable (run: chmod +x generate_keys.sh)"
    fi
else
    check_fail "generate_keys.sh not found"
fi
echo ""

# 6. Check if Sparkle tools are installed
echo "🔐 Checking Sparkle tools..."
if command -v generate_keys &> /dev/null; then
    check_pass "Sparkle tools installed (generate_keys found)"
else
    check_warn "Sparkle tools not installed (run: brew install sparkle)"
fi

if command -v sign_update &> /dev/null; then
    check_pass "sign_update command available"
else
    check_warn "sign_update not found (run: brew install sparkle)"
fi
echo ""

# 7. Check if keys have been generated
echo "🔑 Checking signing keys..."
if [ -f "sparkle_eddsa_public.key" ]; then
    check_pass "Public key exists"
else
    check_warn "Public key not found - run ./generate_keys.sh to create"
fi

if [ -f "sparkle_eddsa_private.key" ]; then
    check_pass "Private key exists"
else
    check_warn "Private key not found - run ./generate_keys.sh to create"
fi

# Check if private key is in .gitignore
if [ -f "../../.gitignore" ]; then
    if grep -q "sparkle_eddsa_private.key" ../../.gitignore; then
        check_pass "Private key is excluded from Git"
    else
        check_warn "Private key not in .gitignore - add it to prevent commits"
    fi
fi
echo ""

# 8. Check documentation
echo "📚 Checking documentation..."
DOCS_FOUND=0
[ -f "../AUTO_UPDATE_GUIDE.md" ] && ((DOCS_FOUND++))
[ -f "../AUTO_UPDATE_QUICKSTART.md" ] && ((DOCS_FOUND++))
if [ -f "../AUTO_UPDATE_GUIDE.md" ]; then
    DOCS_FOUND=$((DOCS_FOUND + 1))
fi
if [ -f "../AUTO_UPDATE_QUICKSTART.md" ]; then
    DOCS_FOUND=$((DOCS_FOUND + 1))
fi
if [ -f "AUTO_UPDATE_IMPLEMENTATION.md" ]; then
    DOCS_FOUND=$((DOCS_FOUND + 1))
fi

if [ $DOCS_FOUND -eq 3 ]; then
    check_pass "All documentation files found ($DOCS_FOUND/3)"
else
    check_warn "Some documentation missing ($DOCS_FOUND/3)"
fi
echo ""

# Summary
echo "=============================================="
echo ""
if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All critical checks passed! ($CHECKS_PASSED checks)${NC}"
    echo ""
    echo "🎉 Your auto-update system is configured!"
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Install Sparkle tools (if not already installed):"
    echo "   brew install sparkle"
    echo ""
    echo "2. Generate signing keys (if not already done):"
    echo "   ./generate_keys.sh"
    echo ""
    echo "3. Update Info.plist with:"
    echo "   - Your GitHub username (replace YOUR_USERNAME)"
    echo "   - Your public key (replace REPLACE_WITH_YOUR_PUBLIC_KEY)"
    echo ""
    echo "4. Build and test:"
    echo "   ./build.sh"
    echo ""
    echo "5. Create your first update:"
    echo "   ./release.sh 6.0.1"
    echo ""
    echo "See AUTO_UPDATE_QUICKSTART.md for detailed instructions."
else
    echo -e "${RED}✗ $CHECKS_FAILED check(s) failed${NC}"
    echo -e "${GREEN}✓ $CHECKS_PASSED check(s) passed${NC}"
    echo ""
    echo "Please fix the failed checks above before proceeding."
fi
echo ""
