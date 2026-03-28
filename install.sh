#!/bin/bash
# AppSwitcher Install Script
# Baut, installiert und oeffnet Accessibility-Einstellungen

set -e
echo 'AppSwitcher wird installiert...'

# Debug-Build
xcodebuild -project '/Users/raulg_mbair/Desktop/AppSwitcher/AppSwitcher.xcodeproj' \
  -scheme AppSwitcher -configuration Debug build > /dev/null 2>&1
echo 'Build OK'

# App-Pfad
APP=$(find ~/Library/Developer/Xcode/DerivedData/AppSwitcher-* \
  -name 'AppSwitcher.app' -path "*/Debug/*" -not -path "*/Index.noindex/*" 2>/dev/null | head -1)

# LSUIElement entfernen
/usr/libexec/PlistBuddy -c 'Delete :LSUIElement' "$APP/Contents/Info.plist" 2>/dev/null || true

# Signieren
codesign --force --deep --sign - "$APP"
echo 'Signiert'

# Installieren
pkill -x AppSwitcher 2>/dev/null || true
sleep 0.3
rm -rf /Applications/AppSwitcher.app
cp -R "$APP" /Applications/AppSwitcher.app
echo 'Installiert'

# Starten
open /Applications/AppSwitcher.app
sleep 1

# Accessibility-Einstellungen oeffnen
open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'

echo 'Fertig! Bitte Accessibility-Berechtigung neu erteilen.'
