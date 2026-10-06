#!/usr/bin/env bash

set -euo pipefail

# Sort after typical distribution and local sysctl snippets.
readonly CONFIG_PATH=/etc/sysctl.d/99-zz-dotfiles-sysrq-oom.conf
readonly SYSRQ_SIGNAL_BIT=64

if ! command -v sudo >/dev/null 2>&1; then
    echo "error: sudo is required" >&2
    exit 1
fi

if [[ ! -r /proc/sys/kernel/sysrq ]]; then
    echo "error: this kernel does not expose kernel.sysrq" >&2
    exit 1
fi

current=$(< /proc/sys/kernel/sysrq)
if [[ ! "$current" =~ ^(0[xX][0-9a-fA-F]+|[0-9]+)$ ]]; then
    echo "error: unexpected kernel.sysrq value: $current" >&2
    exit 1
fi

# A value of 1 is the special setting that enables every SysRq function.
# Otherwise preserve all existing permissions and add bit 64, which permits
# process signalling, including the SysRq-f OOM-killer command.
if (( current == 1 )); then
    desired=1
else
    desired=$((current | SYSRQ_SIGNAL_BIT))
fi

temp_config=$(mktemp)
trap 'rm -f "$temp_config"' EXIT
printf 'kernel.sysrq = %d\n' "$desired" >"$temp_config"

if ! sudo test -f "$CONFIG_PATH" || ! sudo cmp -s "$temp_config" "$CONFIG_PATH"; then
    echo "Installing $CONFIG_PATH..."
    sudo install -Dm0644 "$temp_config" "$CONFIG_PATH"
else
    echo "$CONFIG_PATH is already up to date."
fi

sudo sysctl -w "kernel.sysrq=$desired"

effective=$(< /proc/sys/kernel/sysrq)
if (( effective != 1 && (effective & SYSRQ_SIGNAL_BIT) == 0 )); then
    echo "error: SysRq process signalling did not become active" >&2
    exit 1
fi

echo
echo "Emergency OOM handling is enabled."
echo "If the machine becomes unresponsive, press Alt+PrintScreen+F."
echo "Some laptop keyboards also require holding Fn."
