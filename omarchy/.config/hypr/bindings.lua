-- Personal bindings ported from the legacy Hyprland config.
-- Omarchy defaults remain enabled; conflicts are explicitly unbound first.

local conflicting_bindings = {
  "SUPER + W",             -- legacy config intentionally frees this key
  "SUPER + RETURN",        -- terminal uses the active terminal's working directory
  "SUPER + T",             -- file manager replaces floating/tiling toggle
  "SUPER + SHIFT + B",     -- private browser replaces the default browser
  "SUPER + G",              -- Signal replaces group toggle
  "SUPER + O",              -- Obsidian replaces pop-window
  "SUPER + SHIFT + O",      -- ChatGPT replaces Obsidian
  "SUPER + SHIFT + G",      -- Grok replaces Signal
  "SUPER + SHIFT + C",      -- Claude replaces Calendar
  "SUPER + SHIFT + D",      -- DeepSeek replaces Docker
  "SUPER + SHIFT + P",      -- Perplexity replaces Google Photos
  "SUPER + SHIFT + E",      -- Gmail replaces the default email web app
  "SUPER + SHIFT + W",      -- WhatsApp replaces Omawrite
  "SUPER + SHIFT + X",      -- X URL is supplied by this config
  "SUPER + SHIFT + Y",      -- YouTube URL is supplied by this config
  "SUPER + CTRL + E",       -- legacy config intentionally frees this key
  "SUPER + comma",          -- previous workspace replaces notification dismiss
}

for _, keys in ipairs(conflicting_bindings) do
  hl.unbind(keys)
end

-- Omarchy already binds SUPER + CTRL + X to `voxtype record toggle`.  These
-- submaps are active only while VoiceType is recording/transcribing or
-- injecting its result.  They prevent the still-held Ctrl/Super keys from
-- turning the dictated text into Hyprland shortcuts.
hl.define_submap("voxtype_recording", function()
  hl.bind("F12", hl.dsp.exec_cmd("voxtype record cancel"))
  hl.bind("F12", hl.dsp.submap("reset"))
end)

hl.define_submap("voxtype_suppress", function()
  for _, key in ipairs({
    "SUPER_L", "SUPER_R", "Control_L", "Control_R",
    "Alt_L", "Alt_R", "Shift_L", "Shift_R",
  }) do
    hl.bind(key, function() end)
  end

  -- Emergency exit if VoiceType is interrupted while preparing output.
  hl.bind("F12", hl.dsp.submap("reset"))
end)

-- Applications.
o.bind("SUPER + RETURN", "Terminal", "omarchy-launch-terminal")
o.bind("SUPER + T", "File manager", { omarchy = "nautilus" })
o.bind("SUPER + B", "Browser", { omarchy = "browser" })
o.bind("SUPER + SHIFT + B", "Browser (private)", { omarchy = "browser --private" })
o.bind("SUPER + M", "Music", { omarchy = "spotify" })
o.bind("SUPER + N", "Editor", { omarchy = "editor" })
o.bind("SUPER + SHIFT + T", "Activity", { tui = "btop" })
o.bind("SUPER + D", "Docker", { tui = "lazydocker" })
o.bind("SUPER + G", "Signal", { omarchy = "signal" })
o.bind("SUPER + O", "Obsidian", {
  launch = "obsidian -disable-gpu --enable-wayland-ime",
  focus = "^obsidian$",
})

o.bind("SUPER + ALT + V", "Clipboard", "omarchy-shell shell toggle omarchy.clipboard")
o.bind("SUPER + ALT + E", "Symbols", "omarchy-launch-walker -m symbols")

-- Web apps.
local webapps = {
  { "SUPER + SHIFT + O", "ChatGPT", "https://chatgpt.com" },
  { "SUPER + SHIFT + G", "Grok", "https://grok.com" },
  { "SUPER + SHIFT + C", "Claude", "https://claude.ai" },
  { "SUPER + SHIFT + D", "DeepSeek", "https://chat.deepseek.com" },
  { "SUPER + SHIFT + P", "Perplexity", "https://www.perplexity.ai/" },
  { "SUPER + SHIFT + E", "Email", "https://mail.google.com/mail" },
  { "SUPER + SHIFT + W", "WhatsApp", "https://web.whatsapp.com/", true },
  { "SUPER + SHIFT + X", "X", "https://x.com/" },
  { "SUPER + SHIFT + L", "LinkedIn", "https://www.linkedin.com/" },
  { "SUPER + SHIFT + H", "Hostinger", "https://hpanel.hostinger.com/" },
  { "SUPER + SHIFT + Y", "YouTube", "https://youtube.com/", true },
  { "SUPER + SHIFT + CTRL + C", "Cloudflare Dashboard", "https://dash.cloudflare.com" },
  { "SUPER + SHIFT + CTRL + D", "Discord", "https://discord.com/channels/@me" },
  { "SUPER + SHIFT + CTRL + L", "Linear", "https://linear.app/conception/inbox" },
  { "SUPER + SHIFT + CTRL + X", "X Post", "https://x.com/compose/post" },
  { "SUPER + SHIFT + SLASH", "Bitwarden", "https://vault.bitwarden.com/" },
}

for _, app in ipairs(webapps) do
  local keys, description, url, focus = table.unpack(app)
  o.bind(keys, description, { webapp = url, focus = focus })
end

-- Window and workspace controls.
o.bind("SUPER + Q", "Close active window", hl.dsp.window.close())
o.bind("SUPER + comma", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))
o.bind("SUPER + PERIOD", "Next workspace", hl.dsp.focus({ workspace = "e+1" }))

-- External-display workspaces replace Omarchy's bar-panel shortcuts.
for workspace = 1, 5 do
  local key = "SUPER + CTRL + code:" .. tostring(workspace + 9)
  hl.unbind(key)
  o.bind(
    key,
    "Switch to external workspace " .. tostring(workspace + 10),
    hl.dsp.focus({ workspace = tostring(workspace + 10) })
  )
end

local resize_bindings = {
  { "LEFT", -50, 0 },
  { "RIGHT", 50, 0 },
  { "UP", 0, -50 },
  { "DOWN", 0, 50 },
}

for _, binding in ipairs(resize_bindings) do
  local direction, x, y = table.unpack(binding)
  o.bind(
    "SUPER + SHIFT + CTRL + " .. direction,
    "Resize window " .. direction:lower(),
    hl.dsp.window.resize({ x = x, y = y, relative = true }),
    { repeating = true }
  )
end

local move_bindings = {
  { "LEFT", "l" },
  { "RIGHT", "r" },
  { "UP", "u" },
  { "DOWN", "d" },
}

for _, binding in ipairs(move_bindings) do
  local direction, dispatcher_direction = table.unpack(binding)
  hl.unbind("SUPER + CTRL + " .. direction)
  o.bind(
    "SUPER + CTRL + " .. direction,
    "Move window " .. direction:lower(),
    "hyprctl dispatch movewindow " .. dispatcher_direction,
    { repeating = true }
  )
end

-- Use the lightweight client when it is available; the Python CLI is a
-- compatible fallback for installations that do not ship pypr-client.
if o.cmd_present("pypr") then
  local pypr = o.cmd_present("pypr-client") and "pypr-client" or "pypr"
  hl.unbind("SUPER + SHIFT + RETURN")
  o.bind("SUPER + SHIFT + RETURN", "Dropdown terminal", pypr .. " toggle term")
  o.bind("SUPER + Z", "Desktop zoom", pypr .. " zoom")
end
