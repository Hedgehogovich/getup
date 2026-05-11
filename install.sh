#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

LABEL="com.ychachilo.getup"
APPS_DIR="$HOME/Applications"
BUNDLE="${APPS_DIR}/getup.app"
SUPPORT_DIR="$HOME/Library/Application Support/getup"
LA_DIR="$HOME/Library/LaunchAgents"
PLIST="${LA_DIR}/${LABEL}.plist"

if [ ! -d ./getup.app ]; then
    ./build.sh
fi

mkdir -p "$APPS_DIR" "$SUPPORT_DIR" "$LA_DIR"

# Tear down any existing install (bare-binary or bundled).
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl unload "$PLIST" 2>/dev/null || true

# Replace bundle atomically.
rm -rf "$BUNDLE"
cp -R ./getup.app "$BUNDLE"
echo "Installed bundle  -> $BUNDLE"

# Best-effort cleanup of pre-bundle install location.
rm -f "$HOME/.local/bin/getup"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${BUNDLE}/Contents/MacOS/getup</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>StandardOutPath</key>
    <string>${SUPPORT_DIR}/getup.log</string>
    <key>StandardErrorPath</key>
    <string>${SUPPORT_DIR}/getup.err</string>
</dict>
</plist>
EOF
echo "Wrote LaunchAgent -> $PLIST"

if ! launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null; then
    launchctl load -w "$PLIST"
fi
launchctl kickstart -k "gui/$(id -u)/$LABEL" 2>/dev/null || true

echo
echo "Loaded:   $LABEL"
echo "Settings: ⌘, in the 🚶 menu, or click 'Settings…'"
echo "Logs:     $SUPPORT_DIR/getup.{log,err}"
echo
echo "Uninstall:"
echo "    launchctl bootout gui/\$(id -u)/$LABEL"
echo "    rm \"$PLIST\""
echo "    rm -rf \"$BUNDLE\""
