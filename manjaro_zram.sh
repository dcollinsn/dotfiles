#!/usr/bin/env bash

set -euo pipefail

# Sort after typical vendor/local snippets so these requested settings win.
readonly CONFIG_PATH=/etc/systemd/zram-generator.conf.d/90-dotfiles-memory.conf
readonly ZSWAP_UNIT_PATH=/etc/systemd/system/disable-zswap-before-zram.service

if ! command -v pacman >/dev/null 2>&1; then
    echo "error: pacman was not found; this script is intended for Manjaro" >&2
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
    echo "error: sudo is required" >&2
    exit 1
fi

package_was_installed=false
if ! pacman -Qq zram-generator >/dev/null 2>&1; then
    echo "Installing zram-generator..."
    sudo pacman -S --needed zram-generator
    package_was_installed=true
fi

temp_config=$(mktemp)
temp_unit=$(mktemp)
trap 'rm -f "$temp_config" "$temp_unit"' EXIT

cat >"$temp_config" <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
EOF

# Manjaro kernels commonly enable zswap by default. Running zswap in front of
# zram can compress the same pages twice, so disable it before swap activation.
cat >"$temp_unit" <<'EOF'
[Unit]
Description=Disable zswap before enabling zram swap
DefaultDependencies=no
Before=systemd-zram-setup@zram0.service swap.target
ConditionPathExists=/sys/module/zswap/parameters/enabled

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'printf N > /sys/module/zswap/parameters/enabled'
RemainAfterExit=yes

[Install]
WantedBy=sysinit.target
EOF

config_changed=false
if ! sudo test -f "$CONFIG_PATH" || ! sudo cmp -s "$temp_config" "$CONFIG_PATH"; then
    echo "Installing $CONFIG_PATH..."
    sudo install -Dm0644 "$temp_config" "$CONFIG_PATH"
    config_changed=true
else
    echo "$CONFIG_PATH is already up to date."
fi

if ! sudo test -f "$ZSWAP_UNIT_PATH" || ! sudo cmp -s "$temp_unit" "$ZSWAP_UNIT_PATH"; then
    echo "Installing $ZSWAP_UNIT_PATH..."
    sudo install -Dm0644 "$temp_unit" "$ZSWAP_UNIT_PATH"
else
    echo "$ZSWAP_UNIT_PATH is already up to date."
fi

sudo systemctl daemon-reload
sudo systemctl enable --now disable-zswap-before-zram.service

if awk '$1 == "/dev/zram0" { found = 1 } END { exit !found }' /proc/swaps; then
    echo "/dev/zram0 is already active."
    if [[ "$config_changed" == true || "$package_was_installed" == true ]]; then
        echo "The new configuration will take effect after the next reboot."
        echo "The active zram swap was left in place to avoid an unsafe swapoff."
    fi
else
    echo "Starting zram swap..."
    sudo systemctl start systemd-zram-setup@zram0.service
fi

echo
echo "Configured swap devices:"
swapon --show
