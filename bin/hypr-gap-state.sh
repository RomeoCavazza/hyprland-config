#!/usr/bin/env bash

HYPR_CONKY_STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/conky-left-gap.base"
# shellcheck disable=SC2034 # Sourced by rofi-push.sh.
HYPR_ROFI_PUSH_STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/rofi-push.state"
HYPR_UI_LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/hypr-ui-overlays.lock"
HYPR_GAPS_OUT_FALLBACK="16 16 16 16"
HYPR_ROFI_BLUR_SIZE=14
HYPR_ROFI_BLUR_PASSES=8

hypr_with_ui_lock() {
  local lock_dir lock_fd status

  lock_dir="$(dirname "$HYPR_UI_LOCK_FILE")"
  mkdir -p "$lock_dir"

  exec {lock_fd}>"$HYPR_UI_LOCK_FILE"
  flock -x "$lock_fd"

  if "$@"; then
    status=0
  else
    status=$?
  fi

  flock -u "$lock_fd" || true
  exec {lock_fd}>&-
  return "$status"
}

hypr_normalize_gap_values() {
  tr ',' ' ' <<<"$1" | xargs
}

hypr_get_global_gap_fallback() {
  local option="$1"
  local fallback="$2"
  local data custom value

  data="$(hyprctl getoption "$option" -j 2>/dev/null || true)"
  custom="$(jq -r '.custom // empty' <<<"$data")"
  if [[ -n "$custom" ]]; then
    hypr_normalize_gap_values "$custom"
    return 0
  fi

  value="$(jq -r '.int // empty' <<<"$data")"
  if [[ "$value" =~ ^[0-9]+$ ]]; then
    printf '%s %s %s %s\n' "$value" "$value" "$value" "$value"
    return 0
  fi

  printf '%s\n' "$fallback"
}

hypr_get_workspace_gaps() {
  local workspace="$1"
  local type="$2"
  local field="gaps${type^}"
  local option="general:gaps_${type}"
  local fallback value

  fallback=$([[ "$type" == "in" ]] && echo "8 8 8 8" || echo "16 16 16 16")

  value="$(hyprctl workspacerules -j 2>/dev/null | jq -r --arg ws "$workspace" --arg field "$field" '
    map(select(.workspaceString == $ws)) | .[0][$field] |
    if type == "array" then map(tostring) | join(" ") else empty end
  ' 2>/dev/null || true)"

  if [[ -n "$value" ]]; then
    printf '%s\n' "$value"
    return 0
  fi

  hypr_get_global_gap_fallback "$option" "$fallback"
}

hypr_list_target_workspaces() {
  {
    hyprctl workspacerules -j 2>/dev/null | jq -r '.[]?.workspaceString // empty' 2>/dev/null || true
    hyprctl workspaces -j 2>/dev/null | jq -r '.[] | (.name // (.id | tostring))' 2>/dev/null || true
    hyprctl activeworkspace -j 2>/dev/null | jq -r '.name // (.id | tostring) // empty' 2>/dev/null || true
  } | awk 'NF && !seen[$0]++'
}

hypr_apply_workspace_gaps() {
  local workspace="$1"
  local gaps_in="$2"
  local gaps_out="$3"

  hyprctl -r keyword workspace "${workspace}, gapsin:${gaps_in}, gapsout:${gaps_out}" >/dev/null 2>&1
}

hypr_capture_workspace_state() {
  local state_file="$1"
  shift

  : >"$state_file"

  local workspace gaps_in gaps_out
  for workspace in "$@"; do
    [[ -n "$workspace" ]] || continue
    gaps_in="$(hypr_get_workspace_gaps "$workspace" in)"
    gaps_out="$(hypr_get_workspace_gaps "$workspace" out)"
    printf '%s, gapsin:%s, gapsout:%s\n' "$workspace" "$gaps_in" "$gaps_out" >>"$state_file"
  done
}

hypr_restore_workspace_state() {
  local state_file="$1"
  local legacy_fallback="${2:-16 16 16 16}"
  local line restored=1

  [[ -f "$state_file" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] || continue

    if [[ "$line" == *,\ gapsin:*\,\ gapsout:* ]]; then
      hyprctl -r keyword workspace "$line" >/dev/null 2>&1 || true
      restored=0
      continue
    fi

    legacy_fallback="$line"
  done <"$state_file"

  if (( restored )); then
    hyprctl keyword general:gaps_out "$legacy_fallback" >/dev/null 2>&1 || true
  fi

  rm -f "$state_file"
}

hypr_conky_rails_running() {
  pgrep -f 'conky -q -c.*conky-left' >/dev/null 2>&1 || \
    pgrep -f 'conky -q -c.*conky-right' >/dev/null 2>&1 || \
    pgrep -f 'conky -q -c.*conky\.txt' >/dev/null 2>&1 || \
    pgrep -f 'conky .*system_panel' >/dev/null 2>&1 || \
    pgrep -f 'conky .*network_panel' >/dev/null 2>&1
}

hypr_stop_conky_rails() {
  pkill -f 'conky -q -c.*conky-left' >/dev/null 2>&1 || true
  pkill -f 'conky -q -c.*conky-right' >/dev/null 2>&1 || true
  pkill -f 'conky -q -c.*conky\.txt' >/dev/null 2>&1 || true
  pkill -f 'conky .*system_panel' >/dev/null 2>&1 || true
  pkill -f 'conky .*network_panel' >/dev/null 2>&1 || true
}

hypr_restore_conky_gaps_if_needed() {
  if [[ -f "$HYPR_CONKY_STATE_FILE" ]]; then
    hypr_restore_workspace_state \
      "$HYPR_CONKY_STATE_FILE" \
      "$(hypr_get_global_gap_fallback "general:gaps_out" "$HYPR_GAPS_OUT_FALLBACK")"
  fi
}

hypr_stop_conky_rails_and_restore() {
  hypr_stop_conky_rails
  hypr_restore_conky_gaps_if_needed
}

hypr_restore_rofi_gaps_if_needed() {
  if [[ -f "$HYPR_ROFI_PUSH_STATE_FILE" ]]; then
    hypr_restore_workspace_state "$HYPR_ROFI_PUSH_STATE_FILE"
  fi
}

hypr_close_rofi() {
  pkill -x rofi >/dev/null 2>&1 || true
}

hypr_close_rofi_and_restore() {
  hypr_close_rofi
  hypr_restore_rofi_gaps_if_needed
}

hypr_rofi_running() {
  pgrep -x rofi >/dev/null 2>&1
}

hypr_getoption_int() {
  hyprctl getoption "$1" | awk '/int:/ {print $2; exit}'
}

hypr_capture_rofi_blur_state() {
  HYPR_ROFI_OLD_BLUR_SIZE="$(hypr_getoption_int decoration:blur:size)"
  HYPR_ROFI_OLD_BLUR_PASSES="$(hypr_getoption_int decoration:blur:passes)"
  HYPR_ROFI_OLD_BLUR_IGNORE_OPACITY="$(hypr_getoption_int decoration:blur:ignore_opacity)"
}

hypr_apply_rofi_blur() {
  hyprctl keyword decoration:blur:size "$HYPR_ROFI_BLUR_SIZE" >/dev/null 2>&1 || true
  hyprctl keyword decoration:blur:passes "$HYPR_ROFI_BLUR_PASSES" >/dev/null 2>&1 || true
  hyprctl keyword decoration:blur:ignore_opacity true >/dev/null 2>&1 || true
}

hypr_restore_rofi_blur_state() {
  hyprctl keyword decoration:blur:size "${HYPR_ROFI_OLD_BLUR_SIZE:-5}" >/dev/null 2>&1 || true
  hyprctl keyword decoration:blur:passes "${HYPR_ROFI_OLD_BLUR_PASSES:-5}" >/dev/null 2>&1 || true
  hyprctl keyword decoration:blur:ignore_opacity "${HYPR_ROFI_OLD_BLUR_IGNORE_OPACITY:-1}" >/dev/null 2>&1 || true
}

hypr_close_overview() {
  hyprctl dispatch overview:close all >/dev/null 2>&1 || true
}
