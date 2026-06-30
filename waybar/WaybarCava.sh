#!/usr/bin/env bash
set -euo pipefail

# --- Cava Bars ---

bar="▁▂▃▄▅▆▇█"
dict="s/;//g"

bar_length=${#bar}
for ((i = 0; i < bar_length; i++)); do
    dict+=";s/$i/${bar:$i:1}/g"
done

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
config_file="${runtime_dir}/waybar-cava-${UID}.conf"
trap 'rm -f "$config_file"' EXIT

cat >"$config_file" <<'EOF'
[general]
framerate = 60
bars = 14

[input]
method = pulse
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
EOF

pkill -u "${USER:-$(id -un)}" -f "cava -p $config_file" 2>/dev/null || true

# --- Output ---
cava -p "$config_file" \
  | sed -u "$dict" \
  | awk '
      BEGIN { silent = "^▁+$" }
      $0 ~ silent { print ""; fflush(); next }
      { print; fflush() }
    '
