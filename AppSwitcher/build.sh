#!/bin/bash

# AppSwitcher Build Script
# Kompiliert die App und erstellt eine Release-Version

set -e  # Beende bei Fehler

echo "🚀 AppSwitcher Build Script"
echo "============================"
echo ""

# Farben für Output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Projekt-Name
PROJECT_NAME="AppSwitcher"
SCHEME_NAME="AppSwitcher"

# Build-Konfiguration
CONFIGURATION="Release"
DERIVED_DATA_PATH="build"

echo -e "${BLUE}📦 Cleaning previous builds...${NC}"
rm -rf "$DERIVED_DATA_PATH"
rm -rf "Release"

echo -e "${BLUE}🔨 Building $PROJECT_NAME...${NC}"
xcodebuild \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "$SCHEME_NAME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    clean build

echo -e "${BLUE}📁 Copying app to Release folder...${NC}"
mkdir -p Release

# Finde die .app Datei
APP_PATH=$(find "$DERIVED_DATA_PATH" -name "${PROJECT_NAME}.app" -type d | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo -e "${RED}❌ Error: ${PROJECT_NAME}.app not found!${NC}"
    exit 1
fi

# Kopiere die App
cp -R "$APP_PATH" "Release/"

echo ""
echo -e "${GREEN}✅ Build erfolgreich!${NC}"
echo ""
echo "📂 Die App befindet sich hier:"
echo "   $(pwd)/Release/${PROJECT_NAME}.app"
echo ""
echo "📋 Nächste Schritte:"
echo "   1. Öffne den Finder:"
echo "      open Release"
echo ""
echo "   2. Kopiere ${PROJECT_NAME}.app in den Programme-Ordner:"
echo "      cp -R Release/${PROJECT_NAME}.app /Applications/"
echo ""
echo "   3. Starte die App aus dem Programme-Ordner"
echo ""
echo "   4. Erteile Accessibility-Berechtigung:"
echo "      Systemeinstellungen → Datenschutz → Bedienungshilfen"
echo ""
echo -e "${GREEN}🎉 Fertig!${NC}"
