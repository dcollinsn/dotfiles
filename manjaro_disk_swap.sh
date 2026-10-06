#!/usr/bin/env bash

set -euo pipefail

readonly SWAP_DIR=/swap
readonly SWAP_PATH=/swap/swapfile
readonly FSTAB_PATH=/etc/fstab
readonly ZSWAP_UNIT_NAME=enable-zswap-before-swap.service
readonly ZSWAP_UNIT_PATH=/etc/systemd/system/enable-zswap-before-swap.service

usage() {
    cat <<'EOF'
Usage: manjaro_disk_swap.sh [SIZE]

Create and enable /swap/swapfile, then enable zswap when the kernel supports it.
SIZE accepts whole MiB or GiB values such as 8192M, 16G, or 32G.

With no SIZE, the script uses half of physical RAM, bounded to 8-32 GiB.
EOF
}

if [[ ${1:-} == -h || ${1:-} == --help ]]; then
    usage
    exit 0
fi

if (( $# > 1 )); then
    usage >&2
    exit 2
fi

if ! command -v pacman >/dev/null 2>&1; then
    echo "error: pacman was not found; this script is intended for Manjaro" >&2
    exit 1
fi

for command_name in sudo findmnt mkswap swapon numfmt blkid stat df fallocate dd; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "error: required command was not found: $command_name" >&2
        exit 1
    fi
done

if [[ -n ${1:-} ]]; then
    swap_size=$1
    if [[ ! "$swap_size" =~ ^[1-9][0-9]*[MG]$ ]]; then
        echo "error: SIZE must look like 8192M, 16G, or 32G" >&2
        exit 2
    fi
else
    memory_kib=$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)
    memory_gib=$(((memory_kib + 1024 * 1024 - 1) / (1024 * 1024)))
    swap_gib=$(((memory_gib + 1) / 2))
    (( swap_gib < 8 )) && swap_gib=8
    (( swap_gib > 32 )) && swap_gib=32
    swap_size="${swap_gib}G"
fi

swap_size_bytes=$(numfmt --from=iec "$swap_size")

if sudo test -e /etc/systemd/zram-generator.conf.d/90-dotfiles-memory.conf || \
   sudo test -e /etc/systemd/system/disable-zswap-before-zram.service; then
    echo "error: the managed zram setup is still installed" >&2
    echo "Run manjaro_undo_zram.sh before setting up disk swap." >&2
    exit 1
fi

if awk 'NR > 1 && $1 ~ /^\/dev\/zram/ { found = 1 } END { exit !found }' /proc/swaps; then
    echo "error: zram swap is still active" >&2
    echo "Run manjaro_undo_zram.sh again after freeing memory, or reboot first." >&2
    exit 1
fi

fstab_has_entry=false
if sudo awk -v path="$SWAP_PATH" '
    /^[[:space:]]*#/ { next }
    $1 == path && $3 == "swap" { found = 1 }
    END { exit !found }
' "$FSTAB_PATH"; then
    fstab_has_entry=true
elif sudo awk -v path="$SWAP_PATH" '
    /^[[:space:]]*#/ { next }
    $1 == path { found = 1 }
    END { exit !found }
' "$FSTAB_PATH"; then
    echo "error: $FSTAB_PATH contains a conflicting entry for $SWAP_PATH" >&2
    exit 1
fi

swap_is_active=false
if awk -v path="$SWAP_PATH" 'NR > 1 && $1 == path { found = 1 } END { exit !found }' /proc/swaps; then
    swap_is_active=true
fi

if sudo test -L "$SWAP_PATH"; then
    echo "error: refusing to use symbolic link $SWAP_PATH" >&2
    exit 1
fi

if sudo test -e "$SWAP_PATH"; then
    swap_type=$(sudo blkid -p -s TYPE -o value "$SWAP_PATH" 2>/dev/null || true)
    if [[ "$swap_type" != swap ]]; then
        echo "error: $SWAP_PATH exists but is not a swap file; preserving it" >&2
        exit 1
    fi

    actual_size=$(sudo stat -c %s "$SWAP_PATH")
    echo "$SWAP_PATH already exists as swap ($((actual_size / 1024 / 1024)) MiB)."
    if (( actual_size != swap_size_bytes )); then
        echo "Requested size $swap_size differs; preserving the existing swap file."
    fi
else
    if sudo test -e "$SWAP_DIR" && ! sudo test -d "$SWAP_DIR"; then
        echo "error: $SWAP_DIR exists but is not a directory; preserving it" >&2
        exit 1
    fi

    storage_target=/
    if sudo test -d "$SWAP_DIR"; then
        storage_target=$SWAP_DIR
    fi

    available_bytes=$(df --output=avail -B1 "$storage_target" | tail -n 1 | tr -d ' ')
    readonly FREE_SPACE_MARGIN_BYTES=$((2 * 1024 * 1024 * 1024))
    if (( available_bytes < swap_size_bytes + FREE_SPACE_MARGIN_BYTES )); then
        echo "error: insufficient free space for $swap_size plus a 2 GiB margin" >&2
        exit 1
    fi

    swap_fstype=$(findmnt -no FSTYPE --target "$storage_target")
    if [[ "$swap_fstype" == btrfs ]]; then
        if ! command -v btrfs >/dev/null 2>&1; then
            echo "Installing btrfs-progs..."
            sudo pacman -S --needed btrfs-progs
        fi

        if ! sudo test -d "$SWAP_DIR"; then
            echo "Creating a Btrfs subvolume at $SWAP_DIR..."
            sudo btrfs subvolume create "$SWAP_DIR"
        fi
        sudo chmod 0700 "$SWAP_DIR"

        echo "Creating a $swap_size Btrfs swap file..."
        if ! sudo btrfs filesystem mkswapfile \
                --size "$swap_size" \
                --uuid clear \
                "$SWAP_PATH"; then
            sudo rm -f -- "$SWAP_PATH"
            echo "error: failed to create the Btrfs swap file" >&2
            exit 1
        fi
    else
        sudo install -d -m0700 "$SWAP_DIR"
        echo "Creating a $swap_size swap file on $swap_fstype..."
        if ! sudo fallocate -l "$swap_size" "$SWAP_PATH"; then
            size_mib=$(((swap_size_bytes + 1024 * 1024 - 1) / (1024 * 1024)))
            sudo dd if=/dev/zero of="$SWAP_PATH" bs=1M count="$size_mib" status=progress
        fi
        sudo chmod 0600 "$SWAP_PATH"
        if ! sudo mkswap "$SWAP_PATH"; then
            sudo rm -f -- "$SWAP_PATH"
            echo "error: failed to format the swap file" >&2
            exit 1
        fi
    fi
    sudo chmod 0600 "$SWAP_PATH"
fi

if [[ "$swap_is_active" == false ]]; then
    echo "Enabling disk swap..."
    sudo swapon "$SWAP_PATH"
fi

if [[ "$fstab_has_entry" == true ]]; then
    echo "$FSTAB_PATH already contains the swap entry."
else
    echo "Adding $SWAP_PATH to $FSTAB_PATH..."
    printf '\n%s none swap defaults,pri=10 0 0\n' "$SWAP_PATH" | sudo tee -a "$FSTAB_PATH" >/dev/null
fi

if [[ -e /sys/module/zswap/parameters/enabled ]]; then
    temp_unit=$(mktemp)
    trap 'rm -f "$temp_unit"' EXIT

    cat >"$temp_unit" <<'EOF'
[Unit]
Description=Enable zswap before activating swap devices
DefaultDependencies=no
Before=swap-swapfile.swap swap.target
ConditionPathExists=/sys/module/zswap/parameters/enabled

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'printf Y > /sys/module/zswap/parameters/enabled'
RemainAfterExit=yes

[Install]
WantedBy=sysinit.target
EOF

    if ! sudo test -f "$ZSWAP_UNIT_PATH" || ! sudo cmp -s "$temp_unit" "$ZSWAP_UNIT_PATH"; then
        echo "Installing $ZSWAP_UNIT_PATH..."
        sudo install -Dm0644 "$temp_unit" "$ZSWAP_UNIT_PATH"
    else
        echo "$ZSWAP_UNIT_PATH is already up to date."
    fi

    sudo systemctl daemon-reload
    sudo systemctl enable --now "$ZSWAP_UNIT_NAME"
fi

echo
echo "Configured swap devices:"
swapon --show

if [[ -r /sys/module/zswap/parameters/enabled ]]; then
    printf 'zswap enabled: '
    cat /sys/module/zswap/parameters/enabled
fi

echo
echo "Disk swap setup is complete."
echo "This does not configure resume/hibernation."
