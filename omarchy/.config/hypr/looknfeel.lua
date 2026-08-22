-- Personal appearance settings ported from the legacy Hyprland config.

hl.config({
  cursor = {
    -- Keep the magnified view attached to the mouse cursor.
    zoom_detached_camera = false,
  },
  decoration = {
    rounding = 6,
  },
})

-- Pyprland scratchpad: match the Omarchy clipboard card's border.
hl.window_rule({
  match = { class = "kitty-dropterm" },
  border_size = 2,
  border_color = "rgb(cdd6f4) rgba(595959aa)",
})

-- Keep the idle lock and screensaver from interrupting active media viewing.
-- YouTube web apps include youtube.com in their Chromium app id; regular
-- YouTube tabs end their title with " - YouTube".
o.window("^(vlc|.*youtube\\.com.*)$", { idle_inhibit = "focus" })
o.window({ title = "^.+ - YouTube$" }, { idle_inhibit = "focus" })
