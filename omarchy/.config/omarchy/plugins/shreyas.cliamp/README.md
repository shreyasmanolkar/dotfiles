# Cliamp Controller

A persistent Omarchy top-bar controller for [Cliamp](https://www.cliamp.stream/).
It starts Cliamp's headless daemon automatically—no terminal or Cliamp TUI
window is needed—and opens a native Omarchy panel for transport, seeking,
volume, shuffle/repeat, local playlists, and source access.

## Use

- Left-click the bar item to open the controller.
- Middle-click it to play or pause.
- Right-click it to make sure the background player is running.
- Click anywhere on the track progress bar to seek.
- Click a local playlist to load it; if Cliamp is offline, it starts directly
  with that playlist playing.
- Use the Sources section to switch the controller-owned daemon between its
  default source, radio, Spotify, and YouTube. A separately launched Cliamp
  session is left alone rather than being stopped or replaced.

The panel also supports `J`/`L` for previous/next, `P` for play/pause, `S` for
shuffle, `R` for repeat, and `O` to open Cliamp.

All transport buttons invoke Cliamp directly, so they work even if the panel
was opened from a different monitor's top bar.

## Requirements

- `cliamp` must be on `PATH`.
- The plugin starts `cliamp --daemon` automatically. It records only the PID
  of that daemon under `~/.local/state/omarchy/`, so source switches never
  stop a Cliamp player you launched yourself.
- Local playlists are read from `~/.config/cliamp/playlists/` through
  `cliamp playlist list`.

## Validate and enable

Omarchy intentionally rejects symlinked plugin folders, so this plugin must
be copied from the dotfiles repository rather than deployed by `stow`:

```bash
rm -rf ~/.config/omarchy/plugins/shreyas.cliamp
cp -a ~/dotfiles/omarchy/.config/omarchy/plugins/shreyas.cliamp \
  ~/.config/omarchy/plugins/shreyas.cliamp
omarchy plugin validate ~/.config/omarchy/plugins/shreyas.cliamp
omarchy restart shell
```

The repository's `shell.json` already places the widget in the right-hand
section of the top bar. Re-run the copy command after changing the plugin
source in this repository.
