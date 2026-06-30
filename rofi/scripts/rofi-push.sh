#!/usr/bin/env bash
set -euo pipefail

GAP_HELPER="$HOME/.local/bin/hypr-gap-state.sh"
# shellcheck source=$HOME/.local/bin/hypr-gap-state.sh
source "$GAP_HELPER"

WIDTH=110
ROFI_CMD=(rofi -show drun -theme "$HOME/.config/rofi/custom/column-tco.rasi" -normal-window)
ROFI_PUSH_STATE_FILE="$HYPR_ROFI_PUSH_STATE_FILE"

# --- ACTIONS ---

# Toggle logic
if hypr_rofi_running; then
  hypr_close_rofi
  hypr_restore_workspace_state "$ROFI_PUSH_STATE_FILE"
  exit 0
fi

hypr_stop_conky_rails_and_restore
hypr_close_overview

# Calculate and apply new gaps
ACTIVE_WS="$(hyprctl activeworkspace -j | jq -r '.name // (.id | tostring)')"
GAPS_IN="$(hypr_get_workspace_gaps "$ACTIVE_WS" "in")"
GAPS_OUT="$(hypr_get_workspace_gaps "$ACTIVE_WS" "out")"

# Normalize GAPS_OUT to 4 values for left-side push
read -r top right bottom left _rest <<<"$GAPS_OUT"
top=${top:-16}; right=${right:-16}; bottom=${bottom:-16}; left=${left:-16}

NEW_LEFT=$((left + WIDTH))
NEW_GAPS_OUT="${top} ${right} ${bottom} ${NEW_LEFT}"

hypr_capture_workspace_state "$ROFI_PUSH_STATE_FILE" "$ACTIVE_WS"
if ! hypr_apply_workspace_gaps "$ACTIVE_WS" "$GAPS_IN" "$NEW_GAPS_OUT"; then
  rm -f "$ROFI_PUSH_STATE_FILE"
  exit 1
fi

"${ROFI_CMD[@]}" || true
hypr_restore_workspace_state "$ROFI_PUSH_STATE_FILE"
