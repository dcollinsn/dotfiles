#!/usr/bin/env bash

set -euo pipefail

if (( EUID == 0 )); then
    echo "error: run this script as the desktop user, without sudo" >&2
    exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
    echo "error: pacman was not found; this script is intended for Manjaro" >&2
    exit 1
fi

if ! pacman -Qq firefox >/dev/null 2>&1; then
    echo "Manjaro's native Firefox package is not installed; installing it now..."
    sudo pacman -S --needed firefox
fi

if ! command -v systemd-run >/dev/null 2>&1; then
    echo "error: systemd-run is required but was not found" >&2
    exit 1
fi

readonly BIN_DIR="$HOME/.local/bin"
readonly WRAPPER_PATH="$BIN_DIR/firefox-limited"
readonly DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly APPLICATIONS_DIR="$DATA_HOME/applications"
readonly LOCAL_DESKTOP="$APPLICATIONS_DIR/firefox.desktop"

system_desktop=
for candidate in \
    /usr/share/applications/firefox.desktop \
    /usr/local/share/applications/firefox.desktop; do
    if [[ -f "$candidate" ]]; then
        system_desktop=$candidate
        break
    fi
done

if [[ -z "$system_desktop" ]]; then
    system_desktop=$(pacman -Ql firefox 2>/dev/null | awk '$2 ~ /\/share\/applications\/firefox\.desktop$/ { print $2; exit }')
fi

if [[ -z "$system_desktop" || ! -f "$system_desktop" ]]; then
    echo "error: could not locate Firefox's desktop file" >&2
    exit 1
fi

temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

cat >"$temp_dir/firefox-limited" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

if [[ -x /usr/lib/firefox/firefox ]]; then
    firefox_bin=/usr/lib/firefox/firefox
else
    firefox_bin=$(command -v firefox || true)
fi

if [[ -z "${firefox_bin:-}" ]]; then
    echo "error: Firefox is not installed" >&2
    exit 127
fi

# All Firefox subprocesses from the first launch stay in this transient cgroup.
# MemoryHigh throttles/reclaims first; MemoryMax is the hard physical-RAM limit.
exec systemd-run \
    --user \
    --collect \
    --service-type=exec \
    --unit="firefox-limited-$$" \
    --property=MemoryHigh=45% \
    --property=MemoryMax=60% \
    --property=MemorySwapMax=25% \
    --property=OOMPolicy=kill \
    -- \
    "$firefox_bin" "$@"
EOF

mkdir -p "$BIN_DIR" "$APPLICATIONS_DIR"

if [[ ! -f "$WRAPPER_PATH" ]] || ! cmp -s "$temp_dir/firefox-limited" "$WRAPPER_PATH"; then
    echo "Installing $WRAPPER_PATH..."
    install -m0755 "$temp_dir/firefox-limited" "$WRAPPER_PATH"
else
    echo "$WRAPPER_PATH is already up to date."
fi

desktop_source=$system_desktop
if [[ -f "$LOCAL_DESKTOP" ]]; then
    desktop_source=$LOCAL_DESKTOP
fi

awk -v launcher="$WRAPPER_PATH" '
    BEGIN {
        escaped = launcher
        gsub(/\\/, "\\\\", escaped)
        gsub(/"/, "\\\"", escaped)
        replacement = "Exec=\"" escaped "\""
    }
    /^Exec=[^[:space:]]*\/firefox([[:space:]]|$)/ || /^Exec=firefox([[:space:]]|$)/ {
        arguments = $0
        sub(/^Exec=[^[:space:]]+/, "", arguments)
        $0 = replacement arguments
        changed++
    }
    { print }
    END {
        if (changed == 0) {
            exit 3
        }
    }
' "$desktop_source" >"$temp_dir/firefox.desktop" || awk_status=$?

if [[ ${awk_status:-0} -eq 3 ]] && grep -Fq "Exec=\"$WRAPPER_PATH\"" "$desktop_source"; then
    cp "$desktop_source" "$temp_dir/firefox.desktop"
elif [[ ${awk_status:-0} -ne 0 ]]; then
    echo "error: no native Firefox Exec entries were found in $desktop_source" >&2
    exit "${awk_status:-1}"
fi

if command -v desktop-file-validate >/dev/null 2>&1; then
    desktop-file-validate "$temp_dir/firefox.desktop"
fi

if [[ ! -f "$LOCAL_DESKTOP" ]] || ! cmp -s "$temp_dir/firefox.desktop" "$LOCAL_DESKTOP"; then
    echo "Installing $LOCAL_DESKTOP..."
    install -m0644 "$temp_dir/firefox.desktop" "$LOCAL_DESKTOP"
else
    echo "$LOCAL_DESKTOP is already up to date."
fi

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APPLICATIONS_DIR"
fi

echo
echo "Firefox will now use a cgroup with these limits:"
echo "  MemoryHigh:    45% of physical RAM"
echo "  MemoryMax:     60% of physical RAM"
echo "  MemorySwapMax: 25% of configured swap"
echo "  OOMPolicy:     kill the Firefox cgroup"

if pgrep -x firefox >/dev/null 2>&1; then
    echo
    echo "Firefox is currently running. Quit it completely before the next launch"
    echo "so that all of its processes enter the limited cgroup."
fi
