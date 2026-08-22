-- Start Pyprland with the repository-managed configuration.

if o.cmd_present("pypr") then
  local config = (os.getenv("HOME") or "") .. "/.config/hypr/pyprland.toml"
  o.launch_on_start("pypr --config " .. o.shell_quote(config))
end
