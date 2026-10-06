#!/usr/bin/env bash

set -euo pipefail

# Work around LibreOffice bug 141578 on Plasma Wayland.  The KF6/Qt6 VCL
# backends currently mis-scale parts of the UI when monitors use different
# scale factors.  LibreOffice's GTK3 backend handles that arrangement better.
#
# Usage:
#   ./manjaro_libreoffice_multimonitor_fix.sh          # install/update
#   ./manjaro_libreoffice_multimonitor_fix.sh status
#   ./manjaro_libreoffice_multimonitor_fix.sh undo
#
# Override automatic light/dark icon selection if desired:
#   LIBREOFFICE_ICON_THEME=breeze_svg ./manjaro_libreoffice_multimonitor_fix.sh

readonly APP_ID=libreoffice-kde-multimonitor
readonly MARKER='X-Dotfiles-LibreOffice-MultimonitorFix=true'
readonly XDG_BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"
readonly XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
readonly WRAPPER="$XDG_BIN_HOME/libreoffice-kde-multimonitor"
readonly APPLICATIONS_DIR="$XDG_DATA_HOME/applications"
readonly STATE_DIR="$XDG_STATE_HOME/$APP_ID"
readonly BACKUP_DIR="$STATE_DIR/desktop-backups"
readonly DESKTOP_LIST="$STATE_DIR/desktop-files"
readonly ICON_STATE="$STATE_DIR/icon-state"
readonly REGISTRY_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/libreoffice/4/user/registrymodifications.xcu"
readonly REGISTRY_PATH='/org.openoffice.Office.Common/Misc'
readonly REGISTRY_PROP=SymbolStyle

die() {
    echo "error: $*" >&2
    exit 1
}

libreoffice_is_running() {
    pgrep -u "$(id -u)" -x soffice.bin >/dev/null 2>&1
}

require_manjaro_tools() {
    command -v pacman >/dev/null 2>&1 ||
        die "pacman was not found; this script is intended for Manjaro/Arch"
    command -v perl >/dev/null 2>&1 || die "perl is required"
}

ensure_libreoffice() {
    if [[ ! -x /usr/bin/libreoffice ]]; then
        command -v sudo >/dev/null 2>&1 || die "sudo is required to install LibreOffice"
        echo "LibreOffice is not installed; installing libreoffice-fresh..."
        sudo pacman -S --needed libreoffice-fresh
    fi

    if ! pacman -Qq gtk3 >/dev/null 2>&1; then
        command -v sudo >/dev/null 2>&1 || die "sudo is required to install GTK3"
        echo "Installing the GTK3 runtime..."
        sudo pacman -S --needed gtk3
    fi

    [[ -f /usr/lib/libreoffice/program/libvclplug_gtk3lo.so ]] ||
        die "LibreOffice's GTK3 VCL plugin is missing; reinstall the installed libreoffice package"
}

detect_icon_theme() {
    local requested=${LIBREOFFICE_ICON_THEME:-auto}
    local variant=breeze
    local background=''
    local red green blue

    if [[ "$requested" != auto ]]; then
        printf '%s\n' "$requested"
        return
    fi

    if command -v kreadconfig6 >/dev/null 2>&1; then
        background=$(kreadconfig6 --file kdeglobals --group 'Colors:Window' \
            --key BackgroundNormal 2>/dev/null || true)
    fi

    IFS=, read -r red green blue <<<"$background"
    if [[ "$red" =~ ^[0-9]+$ && "$green" =~ ^[0-9]+$ && "$blue" =~ ^[0-9]+$ ]] &&
        (( red + green + blue < 384 )); then
        variant=breeze_dark
    fi

    if [[ -f "/usr/lib/libreoffice/share/config/images_${variant}_svg.zip" ]]; then
        printf '%s_svg\n' "$variant"
    else
        printf '%s\n' "$variant"
    fi
}

read_icon_theme() {
    [[ -f "$REGISTRY_FILE" ]] || return 0
    LO_REGISTRY_PATH="$REGISTRY_PATH" LO_REGISTRY_PROP="$REGISTRY_PROP" perl -0777 -ne '
        my $path = quotemeta($ENV{LO_REGISTRY_PATH});
        my $prop = quotemeta($ENV{LO_REGISTRY_PROP});
        if (m{<item\s+oor:path="$path"[^>]*>\s*<prop\s+oor:name="$prop"[^>]*>\s*<value[^>]*>([^<]*)</value>\s*</prop>\s*</item>}s) {
            print $1;
        }
    ' "$REGISTRY_FILE"
}

write_icon_theme() {
    local theme=$1
    local temp_registry

    mkdir -p "$(dirname "$REGISTRY_FILE")"
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' \
            '<oor:items xmlns:oor="http://openoffice.org/2001/registry" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"></oor:items>' \
            >"$REGISTRY_FILE"
        chmod 600 "$REGISTRY_FILE"
    fi

    temp_registry=$(mktemp)
    ICON_THEME="$theme" LO_REGISTRY_PATH="$REGISTRY_PATH" LO_REGISTRY_PROP="$REGISTRY_PROP" \
        perl -0777 -pe '
            BEGIN {
                $entry = qq{<item oor:path="$ENV{LO_REGISTRY_PATH}"><prop oor:name="$ENV{LO_REGISTRY_PROP}" oor:op="fuse"><value>$ENV{ICON_THEME}</value></prop></item>};
                $path = quotemeta($ENV{LO_REGISTRY_PATH});
                $prop = quotemeta($ENV{LO_REGISTRY_PROP});
            }
            if (!s{<item\s+oor:path="$path"[^>]*>\s*<prop\s+oor:name="$prop"[^>]*>.*?</prop>\s*</item>}{$entry}s) {
                s{</oor:items>}{$entry</oor:items>} or die "invalid LibreOffice registry file\n";
            }
        ' "$REGISTRY_FILE" >"$temp_registry"

    if command -v xmllint >/dev/null 2>&1; then
        xmllint --noout "$temp_registry"
    fi
    install -m0600 "$temp_registry" "$REGISTRY_FILE"
    rm -f "$temp_registry"
}

remove_icon_theme() {
    local temp_registry
    [[ -f "$REGISTRY_FILE" ]] || return 0

    temp_registry=$(mktemp)
    LO_REGISTRY_PATH="$REGISTRY_PATH" LO_REGISTRY_PROP="$REGISTRY_PROP" perl -0777 -pe '
        BEGIN {
            $path = quotemeta($ENV{LO_REGISTRY_PATH});
            $prop = quotemeta($ENV{LO_REGISTRY_PROP});
        }
        s{<item\s+oor:path="$path"[^>]*>\s*<prop\s+oor:name="$prop"[^>]*>.*?</prop>\s*</item>}{}s;
    ' "$REGISTRY_FILE" >"$temp_registry"
    if command -v xmllint >/dev/null 2>&1; then
        xmllint --noout "$temp_registry"
    fi
    install -m0600 "$temp_registry" "$REGISTRY_FILE"
    rm -f "$temp_registry"
}

install_wrapper() {
    local temp_wrapper
    mkdir -p "$XDG_BIN_HOME"
    temp_wrapper=$(mktemp)
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        'set -euo pipefail' \
        '' \
        '# GTK3 avoids the mixed-DPI Wayland bug in LibreOffice KF6/Qt6.' \
        'export SAL_USE_VCLPLUGIN=gtk3' \
        'exec /usr/bin/libreoffice "$@"' \
        >"$temp_wrapper"
    install -m0755 "$temp_wrapper" "$WRAPPER"
    rm -f "$temp_wrapper"
}

install_desktop_overrides() {
    local vendor target base backup name temp_desktop temp_list validation_output
    local found=false

    mkdir -p "$APPLICATIONS_DIR" "$BACKUP_DIR"
    temp_list=$(mktemp)

    for vendor in /usr/share/applications/libreoffice-*.desktop; do
        [[ -e "$vendor" ]] || continue
        grep -Eq '^Exec=(/usr/bin/)?(libreoffice|soffice)([[:space:]]|$)' "$vendor" || continue
        found=true
        name=${vendor##*/}
        target="$APPLICATIONS_DIR/$name"
        backup="$BACKUP_DIR/$name"
        base=$vendor

        if [[ -f "$target" ]] && ! grep -Fxq "$MARKER" "$target"; then
            if ! cmp -s "$target" "$vendor"; then
                cp -p "$target" "$backup"
                base=$backup
            fi
        elif [[ -f "$backup" ]]; then
            base=$backup
        fi

        temp_desktop=$(mktemp --suffix=.desktop)
        DESKTOP_WRAPPER="$WRAPPER" FIX_MARKER="$MARKER" perl -pe '
            if (!$marked && /^\[Desktop Entry\]\s*$/) {
                $_ .= "$ENV{FIX_MARKER}\n";
                $marked = 1;
            }
            if (/^Exec=(?:\/usr\/bin\/)?(?:libreoffice|soffice)(?=\s|$)/) {
                s{^Exec=(?:/usr/bin/)?(?:libreoffice|soffice)}{Exec="$ENV{DESKTOP_WRAPPER}"};
            }
        ' "$base" >"$temp_desktop"
        if command -v desktop-file-validate >/dev/null 2>&1; then
            if ! validation_output=$(desktop-file-validate "$temp_desktop" 2>&1); then
                printf '%s\n' "$validation_output" >&2
                rm -f "$temp_desktop" "$temp_list"
                die "generated an invalid desktop file for $name"
            fi
        fi
        install -m0644 "$temp_desktop" "$target"
        rm -f "$temp_desktop"
        printf '%s\n' "$name" >>"$temp_list"
    done

    [[ "$found" == true ]] || die "no LibreOffice desktop files were found"
    install -m0600 "$temp_list" "$DESKTOP_LIST"
    rm -f "$temp_list"
    command -v update-desktop-database >/dev/null 2>&1 &&
        update-desktop-database "$APPLICATIONS_DIR"
}

setup() {
    local previous_theme icon_theme
    require_manjaro_tools
    ensure_libreoffice
    libreoffice_is_running &&
        die "close every LibreOffice window before installing this fix"

    mkdir -p "$STATE_DIR"
    if [[ ! -f "$ICON_STATE" ]]; then
        previous_theme=$(read_icon_theme)
        printf 'previous=%s\n' "${previous_theme:-__ABSENT__}" >"$ICON_STATE"
    fi

    icon_theme=$(detect_icon_theme)
    [[ -f "/usr/lib/libreoffice/share/config/images_${icon_theme}.zip" ]] ||
        die "LibreOffice icon theme '$icon_theme' is not installed"

    install_wrapper
    install_desktop_overrides
    write_icon_theme "$icon_theme"
    printf 'installed=%s\n' "$icon_theme" >"$ICON_STATE.tmp"
    grep '^previous=' "$ICON_STATE" >"$ICON_STATE.new"
    cat "$ICON_STATE.tmp" >>"$ICON_STATE.new"
    install -m0600 "$ICON_STATE.new" "$ICON_STATE"
    rm -f "$ICON_STATE.tmp" "$ICON_STATE.new"

    echo "Installed the LibreOffice mixed-DPI workaround."
    echo "VCL backend: gtk3"
    echo "Icon theme: $icon_theme"
    echo "Launcher: $WRAPPER"
    echo "New LibreOffice launches from the KDE menu now use the fix."
}

undo() {
    local name target backup previous installed current
    libreoffice_is_running &&
        die "close every LibreOffice window before undoing this fix"

    if [[ -f "$DESKTOP_LIST" ]]; then
        while IFS= read -r name; do
            [[ -n "$name" ]] || continue
            target="$APPLICATIONS_DIR/$name"
            backup="$BACKUP_DIR/$name"
            if [[ -f "$target" ]] && grep -Fxq "$MARKER" "$target"; then
                if [[ -f "$backup" ]]; then
                    install -m0644 "$backup" "$target"
                else
                    rm -f "$target"
                fi
            fi
        done <"$DESKTOP_LIST"
    fi

    if [[ -f "$ICON_STATE" ]]; then
        previous=$(sed -n 's/^previous=//p' "$ICON_STATE")
        installed=$(sed -n 's/^installed=//p' "$ICON_STATE")
        current=$(read_icon_theme)
        if [[ "$current" == "$installed" ]]; then
            if [[ "$previous" == __ABSENT__ ]]; then
                remove_icon_theme
            elif [[ -n "$previous" ]]; then
                write_icon_theme "$previous"
            fi
        else
            echo "Keeping icon theme '$current' because it changed after setup."
        fi
    fi

    rm -f "$WRAPPER"
    rm -rf "$STATE_DIR"
    command -v update-desktop-database >/dev/null 2>&1 &&
        update-desktop-database "$APPLICATIONS_DIR"
    echo "Removed the LibreOffice mixed-DPI workaround."
}

status() {
    local icon_theme backend=unknown
    icon_theme=$(read_icon_theme)
    [[ -x "$WRAPPER" ]] && backend=gtk3
    echo "Wrapper: $([[ -x "$WRAPPER" ]] && echo installed || echo absent)"
    echo "VCL backend selected by fix: $backend"
    echo "LibreOffice icon theme: ${icon_theme:-auto}"
    if [[ -f "$DESKTOP_LIST" ]]; then
        echo "Managed desktop files: $(wc -l <"$DESKTOP_LIST")"
    else
        echo "Managed desktop files: 0"
    fi
}

case ${1:-setup} in
    setup|install)
        setup
        ;;
    undo|remove|uninstall)
        undo
        ;;
    status)
        status
        ;;
    *)
        die "usage: ${0##*/} [setup|status|undo]"
        ;;
esac
