#!/usr/bin/env bash
set -euo pipefail
HERE=$(dirname "$(readlink -f "$0")")

echo "Installing theme-apply-sddm helper (requires sudo)..."
sudo install -m 0755 "$HERE/theme-apply-sddm" /usr/local/bin/theme-apply-sddm
sudo install -m 0644 "$HERE/org.marvin.theme-switch.policy" \
                     /usr/share/polkit-1/actions/org.marvin.theme-switch.policy
echo "Done."
