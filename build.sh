#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="getup"            # executable filename + bundle filename ("getup.app"). Stays lowercase — matches macOS convention that the binary name matches the bundle filename, and the LaunchAgent + log paths still grep'able.
BUNDLE_ID="com.ychachilo.getup"
DISPLAY_NAME="Getup"        # CFBundleDisplayName + CFBundleName — what Finder, Dock, Cmd-Tab, About box show.
VERSION="0.1"
BUILD="1"
MIN_MACOS="14.0"

BUNDLE="${APP_NAME}.app"
CONTENTS="${BUNDLE}/Contents"

# clean: stale bare binary from pre-bundle era + old bundle
rm -f getup
rm -rf "$BUNDLE"

mkdir -p "${CONTENTS}/MacOS" "${CONTENTS}/Resources"

# Compile via SwiftPM. Frameworks (AppKit, AVFoundation, CoreAudio) are inferred from
# `import` statements and the macOS 14 platform target in Package.swift. Resources
# (`.lproj/Localizable.strings`) are NOT a SwiftPM resource — they're copied into the
# bundle below at assembly time, same as before.
SWIFT_BIN="${SWIFT_BIN:-/Library/Developer/CommandLineTools/usr/bin/swift}"
"$SWIFT_BIN" build -c release
cp ".build/release/${APP_NAME}" "${CONTENTS}/MacOS/${APP_NAME}"

# Copy localizations: every Resources/<lang>.lproj/ goes into the bundle's Resources/.
LOCALES=()
if [ -d Resources ]; then
    for d in Resources/*.lproj; do
        [ -d "$d" ] || continue
        cp -R "$d" "${CONTENTS}/Resources/"
        LOCALES+=("$(basename "$d" .lproj)")
    done
fi

# Copy the app icon. CFBundleIconFile (no extension) tells launchd/Finder/Dock to look up
# Resources/getup.icns. Skip cleanly if the file is missing so a half-set-up dev checkout
# still builds (with a generic placeholder icon).
ICON_KEY_XML=""
if [ -f Resources/getup.icns ]; then
    cp Resources/getup.icns "${CONTENTS}/Resources/getup.icns"
    ICON_KEY_XML="    <key>CFBundleIconFile</key>
    <string>getup</string>
"
fi

# Build the CFBundleLocalizations array entries from $LOCALES
LOC_XML=""
for L in "${LOCALES[@]}"; do
    LOC_XML+="        <string>${L}</string>
"
done

cat > "${CONTENTS}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>${DISPLAY_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
${ICON_KEY_XML}    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleLocalizations</key>
    <array>
${LOC_XML}    </array>
    <key>CFBundleName</key>
    <string>${DISPLAY_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleVersion</key>
    <string>${BUILD}</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.healthcare-fitness</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MIN_MACOS}</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>© 2026</string>
</dict>
</plist>
EOF

# Standard 8-byte stub so Finder/launchd recognize the bundle as an app
printf "APPL????" > "${CONTENTS}/PkgInfo"

echo "Built bundle: $(pwd)/${BUNDLE}"
echo "Localizations: ${LOCALES[*]}"

# Hot redeploy: replace the installed bundle and kick the running daemon so the user
# immediately sees the new build. Skipped when no installed bundle exists (i.e. pre-install.sh
# state) and when REDEPLOY=0 is passed for an opt-out (e.g. CI / packaging pipelines).
if [ "${REDEPLOY:-1}" = "1" ] && [ -d "$HOME/Applications/${BUNDLE}" ]; then
    rm -rf "$HOME/Applications/${BUNDLE}"
    cp -R "$BUNDLE" "$HOME/Applications/${BUNDLE}"
    /bin/launchctl kickstart -k "gui/$(id -u)/com.ychachilo.getup" 2>/dev/null \
        && echo "Redeployed and kicked daemon" \
        || echo "Redeployed (daemon was not registered — skipped kickstart)"
fi
