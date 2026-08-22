# Dotfiles

A collection of Linux desktop environment configurations, optimized for productivity and aesthetics.

## What's Included

This repository contains configurations for:

- **🪟 Hyprland** - Modern tiling Wayland compositor with custom keybindings and window management
- **🐚 Bash** - Enhanced shell configuration with useful aliases and tmux support
- **⚡ Tmux** - Terminal multiplexer with plugins for session persistence and navigation
- **🚀 Starship** - Fast, customizable shell prompt with git integration
- **🖥️ Terminal Emulators**:
  - **Alacritty** - GPU-accelerated terminal emulator
  - **Kitty** - Feature-rich terminal with GPU acceleration
- **🎨 Waybar** - Modern status bar for Wayland compositors
- **📁 Walker** - File manager with custom themes

## System Requirements

- **Arch Linux** (or compatible distribution)
- **Hyprland** (Wayland compositor)
- **Git** and **GNU Stow** for installation

For Omarchy 4, use the `omarchy` package described below. The legacy `hypr`,
`waybar`, and `walker` packages are retained for non-Omarchy setups and are
not part of the active Omarchy installation.

### Install Dependencies

```bash
# Essential tools
sudo pacman -S git stow

# Tools used by the Omarchy-compatible packages
sudo pacman -S starship tmux kitty

# Optional terminals
sudo pacman -S alacritty
```

## Omarchy 4 Installation

The Omarchy session uses Lua Hyprland configuration and a Quickshell bar. Do
not run `stow .`, because the legacy Hyprland `.conf` files and Waybar files
would conflict with that architecture.

1. **Clone the repository** to your home directory:
   ```bash
   git clone git@github.com:shreyasmanolkar/dotfiles.git ~/dotfiles
   cd ~/dotfiles
   ```

2. **Back up existing files that will be replaced:**
   ```bash
   stamp=$(date +%Y%m%d-%H%M%S)
   mkdir -p ~/.config/dotfiles-backups/$stamp
   for path in ~/.bashrc ~/.config/alacritty/alacritty.toml ~/.config/kitty/kitty.conf \
     ~/.config/starship.toml ~/.config/tmux/tmux.conf ~/.config/Cursor/User/settings.json \
     ~/.config/Cursor/User/keybindings.json ~/.config/hypr/autostart.lua \
     ~/.config/hypr/bindings.lua ~/.config/hypr/hyprland.lua \
     ~/.config/hypr/hyprsunset.conf ~/.config/hypr/input.lua \
     ~/.config/hypr/looknfeel.lua ~/.config/hypr/monitors.lua; do
     [ -e "$path" ] || continue
     target=~/.config/dotfiles-backups/$stamp/${path#$HOME/}
     mkdir -p "$(dirname "$target")"
     mv "$path" "$target"
   done
   ```

3. **Install the Omarchy-compatible packages:**
   ```bash
   stow --target="$HOME" omarchy bashrc alacritty kitty starship tmux Cursor
   ```

4. **Install Pyprland** (used by the dropdown terminal and desktop zoom
   bindings):
   ```bash
   uv tool install pyprland
   ```

   The Omarchy package starts Pyprland with the repository-managed
   `~/.config/hypr/pyprland.toml` file.

The `omarchy` package maps the repository’s Hyprland preferences to the
current Lua layout, including this machine’s `eDP-2` and `HDMI-A-1` displays.
If the monitor arrangement changes, edit `omarchy/.config/hypr/monitors.lua`
before reloading Hyprland.

5. **Install tmux plugins** (if using tmux):
   ```bash
   # Install TPM (Tmux Plugin Manager)
   git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm
   
   # Start tmux and install plugins
   tmux
   # Press Ctrl+j + I to install all plugins
   ```

## Tmux Plugin Setup

This configuration includes several useful tmux plugins:

- **TPM** - Tmux Plugin Manager
- **tmux-sensible** - Sensible tmux defaults
- **tmux-yank** - Copy to system clipboard
- **tmux-resurrect** - Save/restore tmux sessions
- **tmux-continuum** - Automatic session saving
- **vim-tmux-navigator** - Seamless vim/tmux navigation

### Manual Plugin Installation

If you encounter the error `'~/.config/tmux/plugins/tpm/tpm' returned 127`:

1. **Install TPM first:**
   ```bash
   git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm
   ```

2. **Reload tmux configuration:**
   ```bash
   tmux source-file ~/.config/tmux/tmux.conf
   ```

3. **Install plugins:**
   - Press `Ctrl+j` then `I` (prefix + I)
   - Wait for all plugins to install

### Plugin Management

- **Install plugins**: `Prefix + I`
- **Update plugins**: `Prefix + U`
- **Uninstall plugins**: `Prefix + alt + u`
- **Reload plugins**: `Prefix + r`

### Session Persistence

The configuration includes automatic session saving:
- Sessions are saved every 5 minutes
- Sessions are restored on tmux startup
- Manual save: `Prefix + Ctrl-s`
- Manual restore: `Prefix + Ctrl-r`

## Individual Package Installation

To install only specific configurations:

```bash
# Install the Omarchy-compatible Hyprland configs
stow --target="$HOME" omarchy

# Install only terminal configs
stow --target="$HOME" alacritty kitty

# Install only shell configs
stow --target="$HOME" bashrc starship tmux
```

The legacy `hypr` package uses the pre-Omarchy `.conf` layout and should
not be installed into an Omarchy 4 session. Waybar and Walker are also kept as
legacy packages; the installed Omarchy setup uses its Quickshell shell instead.

## Customization

### Adding New Configurations

1. Create a new directory for your configuration:
   ```bash
   mkdir new-app
   ```

2. Add your configuration files with proper directory structure:
   ```bash
   new-app/
   └── .config/
       └── new-app/
           └── config.conf
   ```

3. Install with stow:
   ```bash
   stow new-app
   ```

### Modifying Existing Configurations

- **Hyprland**: Edit files in `~/.config/hypr/`
- **Bash**: Edit `~/.bashrc`
- **Tmux**: Edit `~/.config/tmux/tmux.conf`
- **Starship**: Edit `~/.config/starship.toml`

## Updating

To update your dotfiles:

```bash
cd ~/dotfiles
git pull origin main
stow --target="$HOME" omarchy bashrc alacritty kitty starship tmux Cursor
```

## Troubleshooting

### Stow Conflicts
If you encounter conflicts with existing files:
```bash
# Backup existing files first
mv ~/.bashrc ~/.bashrc.backup

# Then install
stow bashrc
```

### Hyprland Issues
- Omarchy 4 loads `~/.config/hypr/hyprland.lua`; validate changes with
  `hyprctl reload` followed by `hyprctl configerrors`.
- Ensure you're running on Wayland: `echo $XDG_SESSION_TYPE`
- Check NVIDIA drivers if using NVIDIA GPU
- Verify all dependencies are installed

### Tmux Plugins Not Working
```bash
# Reinstall plugins
~/.config/tmux/plugins/tpm/bin/install_plugins
```

### 
