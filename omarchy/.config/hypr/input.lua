-- Personal input settings ported from the legacy Hyprland config.

hl.config({
  input = {
    kb_layout = "us",
    kb_options = "caps:swapescape",
    repeat_rate = 40,
    repeat_delay = 300,
    numlock_by_default = true,
    sensitivity = 0.7,
    left_handed = false,
    follow_mouse = 1,
    float_switch_override_focus = false,

    touchpad = {
      disable_while_typing = true,
      natural_scroll = true,
      clickfinger_behavior = false,
      middle_button_emulation = true,
      tap_to_click = true,
      drag_lock = false,
    },
  },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
