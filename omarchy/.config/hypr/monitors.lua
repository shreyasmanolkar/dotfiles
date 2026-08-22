-- Monitor layout adapted from hypr/.config/hypr/monitors.conf.
-- The current hardware enumerates the old eDP-1 panel as eDP-2.
-- eDP-2 is the laptop panel on the right; HDMI-A-1 is the external display
-- on the left. The laptop starts at x=1920 because the external display is
-- 1920 logical pixels wide at scale 1. Its y=360 offset aligns the bottom
-- edges: 360 + (1440 / 2) = 1080.

local laptop = "eDP-2"
local external = "HDMI-A-1"

hl.monitor({
  output = external,
  mode = "1920x1080@60",
  position = "0x0",
  scale = 1,
})

hl.monitor({
  output = laptop,
  mode = "2560x1440@165",
  position = "1920x200",
  scale = 2,
})

for workspace = 1, 5 do
  hl.workspace_rule({ workspace = tostring(workspace), monitor = laptop })
  hl.workspace_rule({ workspace = tostring(workspace + 10), monitor = external })
end
