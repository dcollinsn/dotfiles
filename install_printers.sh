#!/usr/bin/env bash
# Recreate the saved CUPS 2.x profiles on Manjaro/Arch, even while offline.
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=printers/printers.conf
source "$SCRIPT_DIR/printers/printers.conf"

as_root() {
    if (( EUID == 0 )); then "$@"; else sudo "$@"; fi
}
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
[[ -e /etc/manjaro-release || -e /etc/arch-release ]] || die 'this installer supports Manjaro/Arch only'
command -v pacman >/dev/null || die 'pacman is not installed'
command -v systemctl >/dev/null || die 'systemd is not available'
for file in printers/profiles/HP-M607.ppd printers/profiles/HP-4001.ppd printers/printers.conf m607-store-only.sh printers/m607-store-only.ipp printers/m607-validate-storage.ipp; do
    [[ -r "$SCRIPT_DIR/$file" ]] || die "missing saved file: $file"
done
if (( EUID != 0 )); then sudo -v; fi
as_root pacman -S --needed cups cups-filters ipp-usb avahi brlaser
as_root systemctl enable --now cups.service avahi-daemon.service ipp-usb.service

as_root lpadmin -p "$BROTHER_QUEUE" -E -v "$BROTHER_URI" -m "$BROTHER_MODEL" -D 'Brother HL-2270DW' -o printer-is-shared=false
for index in 1 2; do
    queue_var="M607_${index}_QUEUE"
    uri_var="M607_${index}_URI"
    as_root lpadmin -p "${!queue_var}" -E -v "${!uri_var}" \
        -P "$SCRIPT_DIR/printers/profiles/HP-M607.ppd" \
        -D "HP LaserJet M607 ($index)" -o printer-is-shared=false \
        -o cupsPrintQuality=High -o print-quality-default=5 \
        -o printer-resolution-default=1200dpi -o print-color-mode-default=monochrome
done
as_root lpadmin -p "$HP_4001_QUEUE" -E -v "$HP_4001_URI" \
    -P "$SCRIPT_DIR/printers/profiles/HP-4001.ppd" -D 'HP LaserJet Pro 4001' \
    -o printer-is-shared=false -o ColorModel=Gray -o print-color-mode-default=monochrome
as_root lpadmin -d "$DEFAULT_QUEUE"

# User defaults override system defaults, so normalize both M607s here too.
user_options() {
    lpoptions -d "$DEFAULT_QUEUE"
    for queue in "$M607_1_QUEUE" "$M607_2_QUEUE"; do
        lpoptions -p "$queue" -o cupsPrintQuality=High -o print-quality=5 -o printer-resolution=1200dpi
    done
}
if (( EUID == 0 )) && [[ -n ${SUDO_USER:-} && $SUDO_USER != root ]]; then
    sudo -u "$SUDO_USER" -- bash -c \
        'lpoptions -d "$1"; for queue in "$2" "$3"; do lpoptions -p "$queue" -o cupsPrintQuality=High -o print-quality=5 -o printer-resolution=1200dpi; done' \
        bash "$DEFAULT_QUEUE" "$M607_1_QUEUE" "$M607_2_QUEUE"
else
    user_options
fi

as_root install -d /usr/local/bin /usr/local/share/dotfiles-printers/printers
as_root install -m 644 "$SCRIPT_DIR/printers/printers.conf" /usr/local/share/dotfiles-printers/printers/
as_root install -m 644 "$SCRIPT_DIR/printers/m607-store-only.ipp" "$SCRIPT_DIR/printers/m607-validate-storage.ipp" /usr/local/share/dotfiles-printers/printers/
as_root install -m 755 "$SCRIPT_DIR/m607-store-only.sh" /usr/local/bin/m607-store-only
printf '\nInstalled queues (printers may be offline):\n'
lpstat -v "$BROTHER_QUEUE" "$M607_1_QUEUE" "$M607_2_QUEUE" "$HP_4001_QUEUE"
printf '\nDefault: %s\nStore a PDF: m607-store-only document.pdf\n' "$DEFAULT_QUEUE"
