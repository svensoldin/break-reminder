#!/bin/bash
# Compiles the overlay and registers the launch agent that runs it on a fixed interval.
set -euo pipefail

INTERVAL_SECONDS="${INTERVAL_SECONDS:-2700}"
DISPLAY_SECONDS="${DISPLAY_SECONDS:-30}"
MESSAGE="${MESSAGE:-Look away, stretch, breathe.}"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY="$REPO_DIR/break-reminder"
LABEL="com.breakreminder.agent"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LEGACY_LABEL="com.svensoldin.breakreminder"

echo "Building $BINARY"
swiftc -O -o "$BINARY" "$REPO_DIR/BreakReminder.swift"

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
        <string>$BINARY</string>
        <string>$DISPLAY_SECONDS</string>
        <string>$MESSAGE</string>
    </array>

    <key>StartInterval</key>
    <integer>$INTERVAL_SECONDS</integer>

    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
PLIST_EOF

plutil -lint "$PLIST" > /dev/null

# Earlier installs used a personal label; drop it so the reminder does not fire twice.
launchctl bootout "gui/$(id -u)/$LEGACY_LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LEGACY_LABEL.plist"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "Installed. Reminder every ${INTERVAL_SECONDS}s, on screen for ${DISPLAY_SECONDS}s."
