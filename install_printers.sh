#!/usr/bin/env bash

# Install Daniel's CUPS queues on a Manjaro/Arch system.
#
# The HP URIs use ipp-usb's stable DNS-SD service names instead of its
# temporary localhost ports (normally 60000+). New driverless queues must be
# connected and discoverable the first time this script is run so CUPS can
# query their capabilities. Existing queues can be updated while offline.

set -Eeuo pipefail

readonly BROTHER_QUEUE='Brother2270'
readonly BROTHER_URI='socket://192.168.1.244:9100'
readonly BROTHER_MODEL='drv:///brlaser.drv/br2270d.ppd'

readonly M607_1_QUEUE='IPP_HP_M607_1'
readonly M607_1_SERVICE='HP LaserJet M607 [7FE79E] (USB)'
readonly M607_1_URI='ipp://HP%20LaserJet%20M607%20%5B7FE79E%5D%20(USB)._ipp._tcp.local/'

readonly M607_2_QUEUE='IPP_HP_M607_2'
readonly M607_2_SERVICE='HP LaserJet M607 [7FB7A4] (USB)'
readonly M607_2_URI='ipp://HP%20LaserJet%20M607%20%5B7FB7A4%5D%20(USB)._ipp._tcp.local/'

readonly HP_4001_QUEUE='IPP_HP_4001'
readonly HP_4001_SERVICE='HP LaserJet Pro 4001 [D6CEFA] (USB)'
readonly HP_4001_URI='ipp://HP%20LaserJet%20Pro%204001%20%5BD6CEFA%5D%20(USB)._ipp._tcp.local/'

readonly DEFAULT_QUEUE="$HP_4001_QUEUE"

as_root() {
    if (( EUID == 0 )); then
        "$@"
    else
        sudo "$@"
    fi
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

if [[ ! -e /etc/manjaro-release && ! -e /etc/arch-release ]]; then
    die 'this installer supports Manjaro and other Arch-based systems only'
fi

command -v pacman >/dev/null || die 'pacman is not installed'
command -v systemctl >/dev/null || die 'systemd is not available'

if (( EUID != 0 )); then
    sudo -v
fi

printf 'Installing printing packages...\n'
as_root pacman -S --needed cups cups-filters ipp-usb avahi nss-mdns brlaser

printf 'Starting CUPS, Avahi, and ipp-usb...\n'
as_root systemctl enable --now cups.service avahi-daemon.service ipp-usb.service

command -v lpadmin >/dev/null || die 'lpadmin was not installed with CUPS'
command -v lpstat >/dev/null || die 'lpstat was not installed with CUPS'
command -v lpoptions >/dev/null || die 'lpoptions was not installed with CUPS'
command -v ippfind >/dev/null || die 'ippfind was not installed with CUPS'

printf 'Configuring %s...\n' "$BROTHER_QUEUE"
as_root lpadmin \
    -p "$BROTHER_QUEUE" \
    -E \
    -v "$BROTHER_URI" \
    -m "$BROTHER_MODEL" \
    -D 'Brother HL-2270DW'

missing_queues=()

configure_ipp_queue() {
    local queue=$1
    local service=$2
    local uri=$3
    local description=$4
    local -a model_option=()

    # -m everywhere queries the printer to generate its driverless PPD. When
    # an existing queue's printer is absent, retain its current PPD and update
    # the stable URI and other queue properties only.
    if ippfind -T 10 _ipp._tcp -N "$service" -q; then
        model_option=(-m everywhere)
    elif lpstat -p "$queue" >/dev/null 2>&1; then
        printf 'Warning: %s is offline; retaining its existing driver data.\n' "$queue" >&2
    else
        printf 'Warning: cannot create %s until "%s" is connected.\n' \
            "$queue" "$service" >&2
        missing_queues+=("$queue")
        return
    fi

    printf 'Configuring %s...\n' "$queue"
    as_root lpadmin \
        -p "$queue" \
        -E \
        -v "$uri" \
        "${model_option[@]}" \
        -D "$description"
}

configure_ipp_queue \
    "$M607_1_QUEUE" \
    "$M607_1_SERVICE" \
    "$M607_1_URI" \
    'IPP Hewlett-Packard HP LaserJet M607'

configure_ipp_queue \
    "$M607_2_QUEUE" \
    "$M607_2_SERVICE" \
    "$M607_2_URI" \
    'IPP Hewlett-Packard HP LaserJet M607'

configure_ipp_queue \
    "$HP_4001_QUEUE" \
    "$HP_4001_SERVICE" \
    "$HP_4001_URI" \
    'IPP HP LaserJet Pro 4001'

if (( ${#missing_queues[@]} > 0 )); then
    printf '\nThe following new queues were not created because their printers were offline:\n' >&2
    printf '  %s\n' "${missing_queues[@]}" >&2
    printf 'Connect those printers and run this script again. Existing queues were updated.\n' >&2
    exit 1
fi

# Reproduce the current system and per-user defaults.
as_root lpadmin -d "$DEFAULT_QUEUE"

set_user_options() {
    lpoptions -d "$DEFAULT_QUEUE"
    lpoptions \
        -p "$M607_2_QUEUE" \
        -o print-quality=5 \
        -o printer-resolution=1200dpi
}

if (( EUID == 0 )) && [[ -n ${SUDO_USER:-} && $SUDO_USER != root ]]; then
    sudo -u "$SUDO_USER" -- bash -c \
        'lpoptions -d "$1"; lpoptions -p "$2" -o print-quality=5 -o printer-resolution=1200dpi' \
        bash "$DEFAULT_QUEUE" "$M607_2_QUEUE"
else
    set_user_options
fi

printf '\nInstalled queues:\n'
lpstat -v "$BROTHER_QUEUE" "$M607_1_QUEUE" "$M607_2_QUEUE" "$HP_4001_QUEUE"
printf 'Default: %s\n' "$DEFAULT_QUEUE"
