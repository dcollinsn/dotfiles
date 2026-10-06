#!/usr/bin/env bash
set -euo pipefail

# Deactivate and reinitialize external displays that are detected but may not be
# driving a signal after dock attach or wake.
#
# Usage:
#   ./reset-external-displays.sh
#   ./reset-external-displays.sh DP-1 HDMI-1
#   ./reset-external-displays.sh --debug
#
# Run this as an executable or with bash, not by sourcing it from zsh.

sleep_seconds="${DISPLAY_RESET_SLEEP_SECONDS:-2}"
debug=0
restore_delay_seconds="${DISPLAY_RESTORE_DELAY_SECONDS:-1}"
dpms_reset="${DISPLAY_RESET_DPMS:-0}"
dpms_sleep_seconds="${DISPLAY_DPMS_RESET_SLEEP_SECONDS:-2}"
external_settle_seconds="${DISPLAY_EXTERNAL_SETTLE_SECONDS:-3}"

while (($# > 0)); do
  case "$1" in
    --debug)
      debug=1
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

is_internal_output() {
  case "$1" in
    eDP*|LVDS*|DSI*) return 0 ;;
    *) return 1 ;;
  esac
}

strip_ansi() {
  sed -E $'s/\x1b\\[[0-9;]*[[:alpha:]]//g'
}

external_outputs_from_xrandr() {
  xrandr --query |
    awk '$2 == "connected" { print $1 }' |
    while IFS= read -r output; do
      if ! is_internal_output "$output"; then
        printf '%s\n' "$output"
      fi
    done
}

xrandr_state_for_outputs() {
  local output_list=" $* "

  xrandr --query |
    awk -v outputs="$output_list" '
      $2 == "connected" {
        output=$1
        active=(outputs ~ (" " output " "))
        primary=0
        position=""
        for (i = 3; i <= NF; i++) {
          if ($i == "primary") {
            primary=1
          }
          if (match($i, /^([0-9]+)x([0-9]+)([+-][0-9]+)([+-][0-9]+)$/, geometry)) {
            x=geometry[3]
            y=geometry[4]
            sub(/^\+/, "", x)
            sub(/^\+/, "", y)
            position=x "x" y
          }
        }
        next
      }
      active && $2 ~ /\*/ {
        mode=$1
        refresh=$2
        sub(/\*/, "", refresh)
        sub(/\+.*/, "", refresh)
        print output, mode, refresh, position, primary
      }
    '
}

xrandr_middle_output() {
  xrandr --query |
    awk '
      $2 == "connected" {
        output=$1
        for (i = 3; i <= NF; i++) {
          if (match($i, /^([0-9]+)x([0-9]+)([+-][0-9]+)([+-][0-9]+)$/, geometry)) {
            width=geometry[1]
            x=geometry[3]
            print x + (width / 2), output
          }
        }
      }
    ' |
    sort -n |
    awk '{ outputs[++count]=$2 } END { if (count) print outputs[int((count + 1) / 2)] }'
}

xrandr_main_output() {
  xrandr --query |
    awk '
      $2 == "connected" {
        # Prefer the laptop panel as the fixed reference display.  If this is a
        # desktop, fall back to the output currently marked primary.
        rank=2
        if ($1 ~ /^(eDP|LVDS|DSI)/) {
          rank=0
        }
        for (i = 3; i <= NF; i++) {
          if ($i == "primary" && rank > 1) {
            rank=1
          }
        }
        print rank, $1
      }
    ' |
    sort -n -k1,1 -k2,2 |
    awk 'NR == 1 { print $2 }'
}

xrandr_widths_for_outputs() {
  local requested_outputs=" $* "

  xrandr --query |
    awk -v requested="$requested_outputs" '
      function flush() {
        if (selected && active_width) {
          print output, active_width
        }
      }
      $2 == "connected" {
        flush()
        output=$1
        selected=(requested ~ (" " output " "))
        active_width=""
        next
      }
      selected && $1 ~ /^[0-9]+x[0-9]+$/ {
        if ($0 ~ /\*/) {
          split($1, dimensions, "x")
          active_width=dimensions[1]
        }
      }
      END { flush() }
    '
}

xrandr_dock_layout_args() {
  local main_output="$1"
  shift

  local output
  local width
  local total_width=0
  local closest_output
  local farthest_output
  local -A widths=()
  local layout_args=()

  if (($# != 2)); then
    echo "The dock layout requires exactly two external displays." >&2
    return 1
  fi

  # Output 1 is the external display that should border the internal panel.
  # Reverse the physical placement so output 2 is farthest left.
  closest_output="$1"
  farthest_output="$2"

  while read -r output width; do
    widths["$output"]="$width"
  done < <(xrandr_widths_for_outputs "$@")

  for output in "$@"; do
    if [[ -z "${widths[$output]:-}" ]]; then
      echo "Could not determine the active width for $output; not applying a layout." >&2
      return 1
    fi
    total_width=$((total_width + widths[$output]))
  done

  # Anchor the far-left external at zero and move the internal display right
  # by the combined external width.  The nearer external is the primary
  # display, so it owns the taskbar.
  layout_args=(
    --output "$main_output" --auto --pos "${total_width}x0"
    --output "$farthest_output" --pos 0x0
    --output "$closest_output" --pos "${widths[$farthest_output]}x0" --primary
  )

  printf '%s\n' "${layout_args[@]}"
}

reset_with_xrandr() {
  local outputs=("$@")
  local output
  local xrandr_state
  local primary_output
  local layout_output
  local layout_args=()
  local restore_args=()
  local mode
  local rate
  local position
  local primary

  if ((${#outputs[@]} == 0)); then
    outputs=()
    while IFS= read -r output; do
      outputs+=("$output")
    done < <(external_outputs_from_xrandr)
  fi

  if ((${#outputs[@]} == 0)); then
    echo "No connected external displays found."
    return 1
  fi

  echo "Resetting external displays: ${outputs[*]}"

  xrandr_state="$(xrandr_state_for_outputs "${outputs[@]}")"
  primary_output="$(xrandr_main_output)"
  if [[ -z "$primary_output" ]]; then
    echo "Could not determine the main display." >&2
    return 1
  fi

  for output in "${outputs[@]}"; do
    xrandr --output "$output" --off
  done

  sleep "$sleep_seconds"

  for output in "${outputs[@]}"; do
    mode=""
    rate=""
    position=""
    primary=""
    while read -r saved_output saved_mode saved_rate saved_position saved_primary; do
      if [[ "$saved_output" == "$output" ]]; then
        mode="$saved_mode"
        rate="$saved_rate"
        position="$saved_position"
        primary="$saved_primary"
        break
      fi
    done <<< "$xrandr_state"

    if [[ -n "$mode" && -n "$rate" ]]; then
      restore_args+=(--output "$output" --mode "$mode" --rate "$rate")
    else
      restore_args+=(--output "$output" --auto)
    fi

  done

  if ! layout_output="$(xrandr_dock_layout_args "$primary_output" "${outputs[@]}")"; then
    return 1
  fi

  while IFS= read -r output; do
    layout_args+=("$output")
  done <<< "$layout_output"

  # --off/--auto is the connection toggle; the explicit positions make the
  # reconnected outputs tile immediately to the left of the main display.
  xrandr "${restore_args[@]}" "${layout_args[@]}"
}

kscreen_selected_outputs() {
  awk '
    function flush() {
      if (id && name !~ /^(eDP|LVDS|DSI)/) {
        candidates[++candidate_count]=name
        if (connected) {
          connected_outputs[++connected_count]=name
        }
      }
    }
    $1 == "Output:" {
      flush()
      id=$2
      name=$3
      connected=0
      next
    }
    $1 == "connected" {
      connected=1
    }
    END {
      flush()
      if (connected_count) {
        for (i = 1; i <= connected_count; i++) {
          print connected_outputs[i]
        }
      } else {
        for (i = 1; i <= candidate_count; i++) {
          print candidates[i]
        }
      }
    }
  '
}

kscreen_restore_commands() {
  local primary_output="$1"
  shift

  local requested_outputs=" $* "

  awk -v requested="$requested_outputs" -v primary_output="$primary_output" '
    function flush() {
      if (!selected) {
        return
      }

      print "output." name ".enable"

      if (mode != "") {
        print "output." name ".mode." mode
      }
      if (position) {
        print "output." name ".position." position
      }
      if (scale) {
        print "output." name ".scale." scale
      }
      if (priority) {
        print "output." name ".priority." priority
      }
      if (name == primary_output) {
        print "output." name ".primary"
      }
    }
    $1 == "Output:" {
      flush()
      id=$2
      name=$3
      selected=(requested ~ (" " name " ") || requested ~ (" " id " "))
      mode=""
      position=""
      scale=""
      priority=""
      next
    }
    selected && $1 == "priority" {
      priority=$2
    }
    selected && $1 == "Modes:" {
      for (i = 2; i <= NF; i++) {
        if ($i ~ /\*/) {
          split($i, parts, ":")
          mode=parts[1]
          break
        }
      }
    }
    selected && $1 == "Geometry:" {
      position=$2
    }
    selected && $1 == "Scale:" {
      scale=$2
    }
    END {
      flush()
    }
  '
}

kscreen_main_output() {
  awk '
    function flush() {
      if (!name || !connected) {
        return
      }
      rank=2
      if (name ~ /^(eDP|LVDS|DSI)/) {
        rank=0
      } else if (primary) {
        rank=1
      }
      print rank, name
    }
    $1 == "Output:" {
      flush()
      name=$3
      connected=0
      primary=0
      next
    }
    $1 == "connected" { connected=1 }
    $1 == "primary" { primary=1 }
    END { flush() }
  ' |
    sort -n -k1,1 -k2,2 |
    awk 'NR == 1 { print $2 }'
}

kscreen_desired_dock_layout_commands() {
  local main_output="$1"
  shift

  local requested_outputs=" $* "

  awk -v main_output="$main_output" -v requested="$requested_outputs" '
    function flush() {
      if (!name || !connected) {
        return
      }

      seen[name]=1
      modes[name]=mode
      scales[name]=scale
      widths[name]=width
    }
    function emit(output, position, primary) {
      print "output." output ".enable"
      if (modes[output] != "") {
        print "output." output ".mode." modes[output]
      }
      print "output." output ".position." position
      if (scales[output]) {
        print "output." output ".scale." scales[output]
      }
      if (primary) {
        print "output." output ".primary"
      }
    }
    $1 == "Output:" {
      flush()
      name=$3
      connected=0
      mode=""
      scale=""
      width=""
      next
    }
    $1 == "connected" {
      connected=1
    }
    $1 == "Modes:" {
      for (i = 2; i <= NF; i++) {
        if ($i ~ /\*/) {
          split($i, parts, ":")
          mode=parts[1]
          break
        }
      }
    }
    $1 == "Geometry:" {
      split($3, dimensions, "x")
      width=dimensions[1]
    }
    $1 == "Scale:" {
      scale=$2
    }
    END {
      flush()

      if (!seen[main_output]) {
        exit
      }

      count=split(substr(requested, 2, length(requested) - 2), outputs, " ")
      if (count != 2) {
        exit
      }

      total_width=0
      for (i = 1; i <= count; i++) {
        if (!seen[outputs[i]] || !widths[outputs[i]]) {
          exit
        }
        total_width += widths[outputs[i]]
      }

      # KScreen on Wayland rejects negative positions.  Reverse the two
      # externals: output 2 is farthest left, output 1 borders the internal
      # display and is primary (the taskbar display).
      emit(main_output, total_width ",0", 0)
      emit(outputs[2], "0,0", 0)
      emit(outputs[1], widths[outputs[2]] ",0", 1)
    }
  '
}

kscreen_middle_output() {
  awk '
    function flush() {
      if (name && connected && position && size) {
        split(position, pos, ",")
        split(size, dimensions, "x")
        print pos[1] + (dimensions[1] / 2), name
      }
    }
    $1 == "Output:" {
      flush()
      name=$3
      connected=0
      position=""
      size=""
      next
    }
    $1 == "connected" {
      connected=1
    }
    $1 == "Geometry:" {
      position=$2
      size=$3
    }
    END {
      flush()
    }
  ' |
    sort -n |
    awk '{ outputs[++count]=$2 } END { if (count) print outputs[int((count + 1) / 2)] }'
}

reset_with_kscreen_doctor() {
  local outputs=("$@")
  local restore_commands=()
  local main_restore_commands=()
  local closest_restore_commands=()
  local farthest_restore_commands=()
  local restore_command
  local output
  local kscreen_outputs
  local primary_output
  local primary_restore_output
  local staged_restore=0

  kscreen_outputs="$(kscreen-doctor --outputs | strip_ansi)"
  primary_output="$(printf '%s\n' "$kscreen_outputs" | kscreen_main_output)"
  primary_restore_output="$primary_output"

  if [[ -z "$primary_output" ]]; then
    echo "Could not determine the main display." >&2
    return 1
  fi

  if ((debug)); then
    printf '%s\n' "$kscreen_outputs"
  fi

  if ((${#outputs[@]} == 0)); then
    outputs=()
    while IFS= read -r output; do
      outputs+=("$output")
    done < <(printf '%s\n' "$kscreen_outputs" | kscreen_selected_outputs)
  fi

  if ((${#outputs[@]} == 2)); then
    # The first selected external is deliberately placed nearest the internal
    # display and made primary by the dock-layout commands below.
    primary_restore_output="${outputs[0]}"
  fi

  while IFS= read -r restore_command; do
    restore_commands+=("$restore_command")
  done < <(printf '%s\n' "$kscreen_outputs" | kscreen_desired_dock_layout_commands "$primary_output" "${outputs[@]}")

  if ((${#outputs[@]} == 0)); then
    echo "No connected external displays found."
    if ((debug)); then
      echo "No non-internal connected outputs were parsed from kscreen-doctor output." >&2
    fi
    return 1
  fi

  if ((${#restore_commands[@]} == 0)); then
    while IFS= read -r restore_command; do
      restore_commands+=("$restore_command")
    done < <(printf '%s\n' "$kscreen_outputs" | kscreen_restore_commands "$primary_output" "${outputs[@]}")
  fi

  if ((${#restore_commands[@]} == 0)); then
    echo "Could not parse saved display state for: ${outputs[*]}" >&2
    return 1
  fi

  if ((${#outputs[@]} == 2)); then
    for restore_command in "${restore_commands[@]}"; do
      case "$restore_command" in
        "output.${primary_output}."*)
          main_restore_commands+=("$restore_command")
          ;;
        "output.${outputs[0]}."*)
          closest_restore_commands+=("$restore_command")
          ;;
        "output.${outputs[1]}."*)
          farthest_restore_commands+=("$restore_command")
          ;;
      esac
    done

    if ((${#closest_restore_commands[@]} > 0 && ${#farthest_restore_commands[@]} > 0)); then
      staged_restore=1
    fi
  fi

  if ((debug)); then
    echo "Selected external outputs: ${outputs[*]}" >&2
    echo "Primary output after restore: ${primary_restore_output:-none}" >&2
    printf 'Restore command: %s\n' "${restore_commands[@]}" >&2
  fi

  echo "Resetting external displays with kscreen-doctor: ${outputs[*]}"

  for output in "${outputs[@]}"; do
    kscreen-doctor "output.${output}.disable"
  done

  sleep "$sleep_seconds"

  # DPMS is optional: some docks benefit from it, while others fail to train
  # two links after every display has been power-cycled.  It is therefore off
  # by default; set DISPLAY_RESET_DPMS=1 to opt in.
  if [[ "$dpms_reset" != "0" ]]; then
    echo "Cycling display power to reset external connections..."
    if ! kscreen-doctor --dpms off; then
      echo "Could not turn display power off; continuing with output reset." >&2
    fi
    sleep "$dpms_sleep_seconds"
    if ! kscreen-doctor --dpms on; then
      echo "Could not turn display power on; continuing with output reset." >&2
    fi
    sleep "$dpms_sleep_seconds"
  fi

  if ((staged_restore)); then
    # Configure each external in a separate KScreen transaction.  Bringing
    # both DP links up in one transaction can leave either one black after a
    # dock wake; the far-left display gets a full settle window before the
    # nearer (primary) display is enabled.
    echo "Restoring external displays one at a time..."

    if ((${#main_restore_commands[@]} > 0)); then
      kscreen-doctor "${main_restore_commands[@]}"
      sleep "$restore_delay_seconds"
    fi

    kscreen-doctor "${farthest_restore_commands[@]}"
    sleep "$external_settle_seconds"

    kscreen-doctor "${closest_restore_commands[@]}"
    sleep "$external_settle_seconds"
  else
    # Retain the generic path for layouts other than this two-external dock.
    for output in "${outputs[@]}"; do
      kscreen-doctor "output.${output}.enable"
    done

    sleep "$restore_delay_seconds"
    kscreen-doctor "${restore_commands[@]}"
  fi
}

main() {
  if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]] && command -v kscreen-doctor >/dev/null 2>&1; then
    reset_with_kscreen_doctor "$@"
    return
  fi

  if command -v xrandr >/dev/null 2>&1 && xrandr --query >/dev/null 2>&1; then
    reset_with_xrandr "$@"
    return
  fi

  if command -v kscreen-doctor >/dev/null 2>&1; then
    reset_with_kscreen_doctor "$@"
    return
  fi

  echo "Neither xrandr nor kscreen-doctor is available." >&2
  return 1
}

main "$@"
