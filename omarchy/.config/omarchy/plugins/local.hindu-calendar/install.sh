#!/usr/bin/env bash
# Install this user-owned Omarchy plugin without touching /usr/share/omarchy.
# Run as: bash install.sh
set -euo pipefail

source_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
plugin_root="$config_home/omarchy/plugins"
plugin_link="$plugin_root/local.hindu-calendar"
user_config="$config_home/omarchy/hindu-calendar.json"
venv_dir="$data_home/omarchy-hindu-calendar/venv"

mkdir -p "$plugin_root" "$(dirname "$user_config")" "$(dirname "$venv_dir")"

if [[ -e "$plugin_link" || -L "$plugin_link" ]]; then
  if [[ -L "$plugin_link" && $(readlink -f "$plugin_link") == "$source_dir" ]]; then
    echo "Plugin link already installed: $plugin_link"
  else
    echo "Refusing to replace existing plugin path: $plugin_link" >&2
    exit 1
  fi
else
  ln -s "$source_dir" "$plugin_link"
  echo "Linked plugin: $plugin_link"
fi

if [[ ! -e "$user_config" ]]; then
  cp "$source_dir/config.example.json" "$user_config"
  echo "Created configuration template: $user_config"
fi

if command -v uv >/dev/null 2>&1; then
  uv venv "$venv_dir"
  uv pip install --python "$venv_dir/bin/python" -r "$source_dir/requirements.txt"
else
  python3 -m venv "$venv_dir"
  "$venv_dir/bin/python" -m pip install -r "$source_dir/requirements.txt"
fi

echo
echo "Set your exact location in: $user_config"
echo "Then, from a running Omarchy session, run:"
echo "  omarchy-shell shell rescanPlugins"
echo "  omarchy plugin enable local.hindu-calendar --section center --index 1"
echo "  omarchy plugin disable omarchy.clock"
echo
echo "The built-in clock is disabled only after the new widget is known to the shell."
