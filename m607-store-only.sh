#!/usr/bin/env bash
# Submit directly to ipp-usb so CUPS does not discard HP's job-storage option.
set -Eeuo pipefail
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
usage() {
    cat <<'EOF'
Usage: m607-store-only [--printer 1|2] [--copies N] [--name TITLE] [--validate] FILE.pdf
Automatically selects the connected saved M607 when exactly one is present.
--validate checks the request without uploading the PDF or creating a job.
Stored jobs are public and are released from the printer's control panel.
EOF
}
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
if [[ -r "$SCRIPT_DIR/printers/printers.conf" ]]; then
    DATA_DIR=$SCRIPT_DIR
else
    DATA_DIR=/usr/local/share/dotfiles-printers
fi
# shellcheck source=printers/printers.conf
source "$DATA_DIR/printers/printers.conf"
printer=auto copies=1 title='' validate=false
while (( $# )); do
    case $1 in
        --printer|--copies|--name)
            (( $# >= 2 )) || die "$1 requires a value"
            case $1 in
                --printer) printer=$2 ;;
                --copies) copies=$2 ;;
                --name) title=$2 ;;
            esac
            shift 2 ;;
        --validate) validate=true; shift ;;
        --help|-h) usage; exit 0 ;;
        --) shift; break ;;
        -*) die "unknown option: $1" ;;
        *) break ;;
    esac
done
(( $# == 1 )) || { usage >&2; exit 1; }
[[ $printer == auto || $printer == 1 || $printer == 2 ]] || die '--printer must be 1 or 2'
[[ $copies =~ ^[1-9][0-9]*$ ]] || die '--copies must be a positive integer'
[[ -f $1 && -r $1 ]] || die "cannot read file: $1"
[[ $(head -c 5 -- "$1") == '%PDF-' ]] || die 'export the document as PDF first'
file=$(realpath -- "$1")
[[ -n $title ]] || title=$(basename -- "$file")
for tool in ippfind ipptool; do command -v "$tool" >/dev/null || die "missing $tool; run install_printers.sh"; done
uris=() queues=()
for index in 1 2; do
    [[ $printer == auto || $printer == "$index" ]] || continue
    service_var="M607_${index}_SERVICE"
    queue_var="M607_${index}_QUEUE"
    # Resolve the actual endpoint afresh; localhost ports vary across laptops.
    if found=$(ippfind -T 5 _ipp._tcp --local -N "${!service_var}" --print); then
        while IFS= read -r uri; do
            [[ -n $uri ]] || continue
            uris+=("$uri") queues+=("${!queue_var}")
        done <<< "$found"
    fi
done
(( ${#uris[@]} > 0 )) || die 'no matching M607 found; connect USB and check ipp-usb and Avahi'
(( ${#uris[@]} == 1 )) || die 'multiple M607s found; select --printer 1 or --printer 2'
printf 'Checking store-only on %s (%s)...\n' "${queues[0]}" "${uris[0]}"
options=(-T 30 -V 2.0 -t -d "copies=$copies" -d "job_name=$title")
ipptool "${options[@]}" "${uris[0]}" "$DATA_DIR/printers/m607-validate-storage.ipp" || die 'store-only validation failed; no file was submitted'
if $validate; then exit 0; fi
if ! ipptool "${options[@]}" -f "$file" "${uris[0]}" "$DATA_DIR/printers/m607-store-only.ipp"; then
    die 'submission failed or its response was lost; check the printer before retrying'
fi
printf 'Store-only request accepted. Check Retrieve from Device Memory on the printer.\n'
