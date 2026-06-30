#!/usr/bin/env bash
set -euo pipefail

GAP_HELPER="$HOME/.local/bin/hypr-gap-state.sh"
# shellcheck source=$HOME/.local/bin/hypr-gap-state.sh
# shellcheck disable=SC1091
source "$GAP_HELPER"

WIDTH=122
ROFI_CMD=(rofi -show drun -theme "$HOME/.config/rofi/custom/column-tco.rasi" -normal-window)
ROFI_PUSH_STATE_FILE="$HYPR_ROFI_PUSH_STATE_FILE"
ROFI_PUSH_RESTORED=0
ROFI_PUSH_SESSION_RESTORED=0

restore_rofi_push_session() {
  if (( ROFI_PUSH_SESSION_RESTORED )); then
    return 0
  fi

  hypr_with_ui_lock restore_rofi_push_state
  hypr_restore_rofi_blur_state
  ROFI_PUSH_SESSION_RESTORED=1
}

restore_rofi_push_state() {
  if (( ROFI_PUSH_RESTORED )); then
    return 0
  fi

  hypr_restore_workspace_state "$ROFI_PUSH_STATE_FILE"
  ROFI_PUSH_RESTORED=1
}

prepare_rofi_push_overlay() {
  local active_ws gaps_in gaps_out top right bottom left _rest new_left new_gaps_out

  hypr_stop_conky_rails_and_restore
  hypr_close_overview

  active_ws="$(hyprctl activeworkspace -j | jq -r '.name // (.id | tostring)')"
  gaps_in="$(hypr_get_workspace_gaps "$active_ws" "in")"
  gaps_out="$(hypr_get_workspace_gaps "$active_ws" "out")"

  read -r top right bottom left _rest <<<"$gaps_out"
  top=${top:-16}
  right=${right:-16}
  bottom=${bottom:-16}
  left=${left:-16}

  new_left=$((left + WIDTH))
  new_gaps_out="${top} ${right} ${bottom} ${new_left}"

  hypr_capture_workspace_state "$ROFI_PUSH_STATE_FILE" "$active_ws"
  if ! hypr_apply_workspace_gaps "$active_ws" "$gaps_in" "$new_gaps_out"; then
    rm -f "$ROFI_PUSH_STATE_FILE"
    return 1
  fi
}

if hypr_rofi_running; then
  hypr_with_ui_lock hypr_close_rofi_and_restore
  exit 0
fi

trap restore_rofi_push_session EXIT
hypr_capture_rofi_blur_state
hypr_apply_rofi_blur
hypr_with_ui_lock prepare_rofi_push_overlay

"${ROFI_CMD[@]}" || true
restore_rofi_push_session
