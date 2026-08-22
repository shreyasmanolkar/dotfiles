#!/usr/bin/env bash
# Run from the QML widget.  The install script creates .venv beside this
# plugin; retaining the python3 fallback gives a clear JSON error instead of
# breaking the Omarchy shell while the dependency is being installed.
set -euo pipefail

plugin_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
config_path="${HINDU_CALENDAR_CONFIG:-$config_home/omarchy/hindu-calendar.json}"
python_bin="$data_home/omarchy-hindu-calendar/venv/bin/python"
if [[ ! -x "$python_bin" ]]; then python_bin="$plugin_dir/.venv/bin/python"; fi
if [[ ! -x "$python_bin" ]]; then python_bin=python3; fi

exec "$python_bin" "$plugin_dir/engine/panchang.py" --config "$config_path" "$@"
