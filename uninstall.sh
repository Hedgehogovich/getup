#!/usr/bin/env bash
set -euo pipefail

LABEL="com.ychachilo.getup"
APPS_DIR="$HOME/Applications"
BUNDLE="${APPS_DIR}/getup.app"
SUPPORT_DIR="$HOME/Library/Application Support/getup"
LA_DIR="$HOME/Library/LaunchAgents"
PLIST="${LA_DIR}/${LABEL}.plist"
PREFS_NEW="$HOME/Library/Preferences/${LABEL}.plist"
PREFS_OLD="$HOME/Library/Preferences/getup.plist"
LEGACY_BIN="$HOME/.local/bin/getup"

PURGE=0
for arg in "$@"; do
    case "$arg" in
        --purge|-p) PURGE=1 ;;
        --help|-h)
            cat <<USAGE
Uninstall getup.

Usage:
    ./uninstall.sh           Remove app, LaunchAgent, and binary. Keep user data.
    ./uninstall.sh --purge   Also remove sound.aiff, logs, and saved settings.
USAGE
            exit 0 ;;
        *) echo "unknown flag: $arg (try --help)" >&2; exit 2 ;;
    esac
done

echo "→ Stopping daemon"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl unload "$PLIST" 2>/dev/null || true

echo "→ Removing LaunchAgent plist"
rm -f "$PLIST"

echo "→ Removing app bundle"
rm -rf "$BUNDLE"

echo "→ Removing legacy bare-binary install (if present)"
rm -f "$LEGACY_BIN"

if [ "$PURGE" -eq 1 ]; then
    echo "→ Purging user data"
    rm -rf "$SUPPORT_DIR"
    # UserDefaults: clear both new (bundled) and legacy (bare-binary) domains
    defaults delete "$LABEL" 2>/dev/null || true
    defaults delete getup    2>/dev/null || true
    rm -f "$PREFS_NEW" "$PREFS_OLD"
else
    echo "→ Keeping user data:"
    echo "    $SUPPORT_DIR  (sound.aiff, logs)"
    echo "    $PREFS_NEW    (settings)"
    echo "  Re-run with --purge to remove these too."
fi

echo
echo "Uninstalled."
