#!/usr/bin/env bash
set -euo pipefail

echo "=== katalk-ax Accessibility Diagnostic ==="
echo ""

echo "1. Checking if KakaoTalk is running..."
if pgrep -x "KakaoTalk" > /dev/null; then
    echo "   ✓ KakaoTalk is running"
    KATALK_PID=$(pgrep -x "KakaoTalk" | head -1)
    echo "   PID: $KATALK_PID"
else
    echo "   ✗ KakaoTalk is NOT running"
    echo "   Please launch KakaoTalk first"
    exit 1
fi

echo ""
echo "2. Checking app bundle locations..."
if [ -d "dist/katalk-ax-cli.app" ]; then
    echo "   ✓ CLI app bundle exists: dist/katalk-ax-cli.app"
    codesign -d --verbose=4 dist/katalk-ax-cli.app 2>&1 | grep -E "Identifier|Authority" | sed 's/^/   /' || true
else
    echo "   ✗ CLI app bundle not found"
    echo "   Build it with: scripts/build-cli-app.sh"
fi

if [ -d "dist/katalk-ax.app" ]; then
    echo "   ✓ Menu bar app bundle exists: dist/katalk-ax.app"
else
    echo "   ✗ Menu bar app not found"
    echo "   Build it with: scripts/build-menu-bar-app.sh"
fi

echo ""
echo "3. Checking Accessibility permission status..."
echo "   To check manually:"
echo "   - Open: System Settings > Privacy & Security > Accessibility"
echo "   - Look for your terminal app or katalk-ax in the list"
echo "   - Make sure it's enabled"

echo ""
echo "4. Current process info:"
echo "   Bundle: $(defaults read "$(pwd)/dist/katalk-ax-cli.app/Contents/Info" CFBundleIdentifier 2>/dev/null || echo 'N/A (not built)')"
echo "   Version: $(defaults read "$(pwd)/dist/katalk-ax-cli.app/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo 'N/A (not built)')"

echo ""
echo "5. Quick fix steps if permission is not detected:"
echo "   a. Remove existing entries from Accessibility list"
echo "   b. Add the app bundle again: dist/katalk-ax-cli.app"
echo "   c. Restart your terminal"
echo "   d. Run: swift run katalk-ax status --prompt"
echo ""
echo "=== Diagnostic complete ==="
