#!/bin/bash
# Compiles the overlay and the menu bar app that schedules it, then starts the menu bar app at login.
set -euo pipefail

DISPLAY_SECONDS="${DISPLAY_SECONDS:-30}"
MESSAGE="${MESSAGE:-Look away, stretch, breathe.}"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY="$REPO_DIR/break-reminder"
MENU_BINARY="$REPO_DIR/break-reminder-menu"
LABEL="com.breakreminder.menu"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
# Earlier installs fired the overlay straight from launchd; the menu bar app schedules it now.
LEGACY_LABELS=("com.svensoldin.breakreminder" "com.breakreminder.agent")

echo "Building $BINARY"
swiftc -O -o "$BINARY" "$REPO_DIR/BreakReminder.swift"

echo "Building $MENU_BINARY"
swiftc -O -o "$MENU_BINARY" "$REPO_DIR/BreakReminderMenu.swift"

echo "Writing $PLIST"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>

    <key>ProgramArguments</key>
    <array>
        <string>$MENU_BINARY</string>
        <string>$DISPLAY_SECONDS</string>
        <string>$MESSAGE</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <!-- Restart after a crash, but let Quit from the menu stick. -->
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
</dict>
</plist>
PLIST_EOF

plutil -lint "$PLIST" > /dev/null

for legacy_label in "${LEGACY_LABELS[@]}"; do
    launchctl bootout "gui/$(id -u)/$legacy_label" 2>/dev/null || true
    launchctl enable "gui/$(id -u)/$legacy_label"
    rm -f "$HOME/Library/LaunchAgents/$legacy_label.plist"
done

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "Installed. Pick the interval from the eye icon in the menu bar; breaks stay on screen for ${DISPLAY_SECONDS}s."
