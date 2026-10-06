#!/usr/bin/env bash

set -euo pipefail

readonly CONFIG_PATH=/etc/systemd/zram-generator.conf.d/90-dotfiles-memory.conf
readonly LEGACY_CONFIG_PATH=/etc/systemd/zram-generator.conf.d/10-memory.conf
readonly ZSWAP_UNIT_NAME=disable-zswap-before-zram.service
readonly ZSWAP_UNIT_PATH=/etc/systemd/system/disable-zswap-before-zram.service

if ! command -v sudo >/dev/null 2>&1; then
    echo "error: sudo is required" >&2
    exit 1
fi

temp_config=$(mktemp)
trap 'rm -f "$temp_config"' EXIT
managed_setup_found=false

cat >"$temp_config" <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
EOF

sudo systemctl disable "$ZSWAP_UNIT_NAME" >/dev/null 2>&1 || true
sudo systemctl stop "$ZSWAP_UNIT_NAME" >/dev/null 2>&1 || true

if sudo test -e "$ZSWAP_UNIT_PATH"; then
    managed_setup_found=true
    echo "Disabling $ZSWAP_UNIT_NAME..."
    sudo rm -f -- "$ZSWAP_UNIT_PATH"
fi

if sudo test -e "$CONFIG_PATH"; then
    managed_setup_found=true
    echo "Removing $CONFIG_PATH..."
    sudo rm -f -- "$CONFIG_PATH"
fi

# An early version of the setup script used this filename. Only remove it when
# its content exactly matches the configuration that script generated.
if sudo test -e "$LEGACY_CONFIG_PATH"; then
    if sudo cmp -s "$temp_config" "$LEGACY_CONFIG_PATH"; then
        managed_setup_found=true
        echo "Removing legacy configuration $LEGACY_CONFIG_PATH..."
        sudo rm -f -- "$LEGACY_CONFIG_PATH"
    else
        echo "Preserving unrelated configuration $LEGACY_CONFIG_PATH."
    fi
fi

sudo systemctl daemon-reload

zram_active=false
zram_used_kib=0
if [[ "$managed_setup_found" == true ]]; then
    while read -r device _ _ used _; do
        if [[ "$device" == /dev/zram0 ]]; then
            zram_active=true
            zram_used_kib=$((zram_used_kib + used))
        fi
    done < <(tail -n +2 /proc/swaps)
fi

if [[ "$zram_active" == true ]]; then
    available_kib=$(awk '/^MemAvailable:/ { print $2 }' /proc/meminfo)
    readonly SAFETY_MARGIN_KIB=$((1024 * 1024))
    required_kib=$((zram_used_kib + SAFETY_MARGIN_KIB))

    if (( available_kib >= required_kib )); then
        echo "Disabling active zram swap..."
        if sudo swapoff -- /dev/zram0; then
            if command -v zramctl >/dev/null 2>&1; then
                sudo zramctl --reset /dev/zram0
            fi
        else
            echo "Could not safely disable /dev/zram0; it will be released at reboot." >&2
        fi
    else
        echo
        echo "Active zram swap was left running for safety:"
        echo "  swapped data:  $((zram_used_kib / 1024)) MiB"
        echo "  available RAM: $((available_kib / 1024)) MiB"
        echo "Its configuration has been removed, so it will disappear after reboot."
    fi
elif [[ "$managed_setup_found" == false ]]; then
    echo "No managed zram setup was found; unrelated zram devices were preserved."
fi

echo
if [[ "$managed_setup_found" == true ]] && \
   awk 'NR > 1 && $1 == "/dev/zram0" { found = 1 } END { exit !found }' /proc/swaps; then
    echo "The managed zram setup has been removed; reboot to release active zram."
else
    echo "The managed zram setup has been removed."
fi

if command -v pacman >/dev/null 2>&1 && pacman -Qq zram-generator >/dev/null 2>&1; then
    echo "The zram-generator package was preserved because it may predate this setup."
fi

if [[ -r /sys/module/zswap/parameters/enabled ]]; then
    echo "zswap will return to the kernel/bootloader default after reboot."
fi
