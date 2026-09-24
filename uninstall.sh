#!/bin/bash
# Unregisters the launch agent. Leaves the compiled binaries and saved preferences in place.
set -euo pipefail

LABEL="com.breakreminder.menu"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$PLIST"

echo "Uninstalled."
