#!/bin/bash
set -e

# ShiftIt Release Build Script
# This script builds, signs, and prepares the release for upload

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SHIFTIT_DIR="$PROJECT_DIR/ShiftIt"
BUILD_DIR="$PROJECT_DIR/build"

# Get version from Info.plist
VERSION=$(defaults read "$SHIFTIT_DIR/ShiftIt-Info.plist" CFBundleShortVersionString)
ARCHIVE_NAME="ShiftIt-${VERSION}.zip"
ARCHIVE_PATH="$BUILD_DIR/$ARCHIVE_NAME"

# GitHub repo for URLs
GITHUB_REPO="citadelgrad/ShiftIt"

echo "========================================"
echo "ShiftIt Release Builder v${VERSION}"
echo "========================================"
echo ""

# Step 1: Clean and build
echo "[1/5] Building ShiftIt..."
cd "$SHIFTIT_DIR"
xcodebuild -project ShiftIt.xcodeproj -target ShiftIt -configuration Release clean build | grep -E "(Build |error:|warning:)" || true

APP_PATH="$SHIFTIT_DIR/build/Release/ShiftIt.app"
if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: Build failed - ShiftIt.app not found at $APP_PATH"
    exit 1
fi
echo "   Build successful: $APP_PATH"
echo ""

# Step 2: Create build directory and archive
echo "[2/5] Creating archive..."
mkdir -p "$BUILD_DIR"
rm -f "$ARCHIVE_PATH"
ditto -ck --keepParent "$APP_PATH" "$ARCHIVE_PATH"
echo "   Archive created: $ARCHIVE_PATH"
echo ""

# Step 3: Sign with EdDSA
echo "[3/5] Signing with EdDSA (reading key from Keychain)..."
SIGN_OUTPUT=$("$SHIFTIT_DIR/bin/sign_update" "$ARCHIVE_PATH")
echo "   $SIGN_OUTPUT"

# Parse the signature and length from output
# Output format: sparkle:edSignature="..." length="..."
ED_SIGNATURE=$(echo "$SIGN_OUTPUT" | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)
FILE_LENGTH=$(echo "$SIGN_OUTPUT" | grep -o 'length="[^"]*"' | cut -d'"' -f2)

if [ -z "$ED_SIGNATURE" ]; then
    echo "ERROR: Failed to get EdDSA signature"
    exit 1
fi
echo ""

# Step 4: Update appcast.xml
echo "[4/5] Updating appcast.xml..."
APPCAST_FILE="$SCRIPT_DIR/appcast.xml"
PUB_DATE=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")

cat > "$APPCAST_FILE" << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
   <channel>
      <title>ShiftIt Changelog</title>
      <link>https://raw.github.com/${GITHUB_REPO}/master/release/appcast.xml</link>
      <language>en</language>
      <item>
         <title>ShiftIt version ${VERSION}</title>
         <sparkle:releaseNotesLink>
            http://htmlpreview.github.com/?https://raw.github.com/${GITHUB_REPO}/master/release/release-notes-${VERSION}.html
         </sparkle:releaseNotesLink>
         <pubDate>${PUB_DATE}</pubDate>
         <enclosure
            url="https://github.com/${GITHUB_REPO}/releases/download/version-${VERSION}/${ARCHIVE_NAME}"
            sparkle:version="${VERSION}"
            length="${FILE_LENGTH}"
            type="application/octet-stream"
            sparkle:edSignature="${ED_SIGNATURE}" />
         <sparkle:minimumSystemVersion>14.6</sparkle:minimumSystemVersion>
      </item>
   </channel>
</rss>
EOF
echo "   Updated: $APPCAST_FILE"
echo ""

# Step 5: Summary
echo "[5/5] Release preparation complete!"
echo ""
echo "========================================"
echo "Release Summary"
echo "========================================"
echo "Version:    ${VERSION}"
echo "Archive:    ${ARCHIVE_PATH}"
echo "Size:       ${FILE_LENGTH} bytes"
echo "Signature:  ${ED_SIGNATURE:0:40}..."
echo ""
echo "Files updated:"
echo "  - release/appcast.xml"
echo "  - release/release-notes-${VERSION}.html (created earlier)"
echo ""
echo "Next steps:"
echo "  1. Test the app: open \"$APP_PATH\""
echo "  2. Commit changes: git add -A && git commit -m \"Release ${VERSION}\""
echo "  3. Tag release: git tag version-${VERSION}"
echo "  4. Push: git push origin master --tags"
echo "  5. Create GitHub release at:"
echo "     https://github.com/${GITHUB_REPO}/releases/new?tag=version-${VERSION}"
echo "  6. Upload ${ARCHIVE_NAME} to the GitHub release"
echo ""
