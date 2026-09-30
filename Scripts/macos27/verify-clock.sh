#!/bin/bash
#
# Verifies that the clock and Control Center open while Glacier conceals items on macOS 27.
# Requirements: Glacier installed with Scripts/install.sh, Thaw not running.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d /tmp/glacier-verify-clock.XXXXXX)"
swiftc -O "$ROOT/Scripts/macos27/system-click.swift" -o "$WORK/system-click"

quit_glacier() {
    osascript -e 'tell application id "de.nlmyr.glacier" to quit' >/dev/null 2>&1 || true
    for _ in $(seq 1 40); do pgrep -x Glacier >/dev/null || return 0; sleep 0.25; done
}
start_glacier() {
    open "$HOME/Applications/Glacier.app"
    for _ in $(seq 1 40); do pgrep -x Glacier >/dev/null && return 0; sleep 0.25; done
}
# Leave Glacier running, the way the run found it. A run that ended with Glacier down left the
# machine concealing nothing, and whatever was looked at next showed nothing worth seeing.
restore() {
    quit_glacier
    start_glacier
}
trap restore EXIT

quit_glacier
open "$HOME/Applications/Glacier.app"
sleep 10

FAILED=0
if "$WORK/system-click" clock; then echo "PASS  the clock opens Notification Center while concealing"; else echo "FAIL  the clock opens Notification Center while concealing"; FAILED=1; fi
sleep 2
if "$WORK/system-click" controlcenter; then echo "PASS  Control Center opens while concealing"; else echo "FAIL  Control Center opens while concealing"; FAILED=1; fi
exit $FAILED
