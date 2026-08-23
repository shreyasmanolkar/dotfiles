# Pomodoro & Murut Timer for Omarchy

A compact, persistent Omarchy bar timer for focused work. It lives in the top bar, always shows the remaining time, and opens a small native control panel on click.

The default is a **25-minute Pomodoro**. Traditional presets treat one **Murut (Muhūrta)** as 48 minutes: ⅛ (6 min), ¼ (12 min), ½ (24 min), ¾ (36 min), and 1 Murut (48 min).

## Use

- Left click the bar timer to open its controls.
- Middle click starts, pauses, or resumes; right click resets the selected duration.
- In the panel, use **Space** to start/pause, **R** to reset, and **1–6** to select a duration.
- A normal Omarchy notification marks completion. There is no polling process or external dependency.

The timer stores its selected preset, state, held remainder, wall-clock deadline, completed-session totals, and a compact 365-day focus history in `~/.local/state/omarchy/pomodoro.json`. A running timer therefore stays accurate through sleep and shell restarts, while the dashboard retains today's focus, all-time totals, streak, average session, and the seven-day trend.

## Install / validate

When this dotfiles package is installed with Stow, the plugin directory and `shell.json` are linked automatically. To rescan a running shell after a manual install:

```bash
omarchy-shell shell rescanPlugins
omarchy plugin validate ~/dotfiles/omarchy/.config/omarchy/plugins/local.pomodoro
node ~/dotfiles/omarchy/.config/omarchy/plugins/local.pomodoro/tests/test_timer_model.js
```

The repository’s `shell.json` pins `local.pomodoro` into the right side of the top bar. The implementation is entirely user-owned; it never modifies `/usr/share/omarchy`.
