# Dotfiles

A collection of Linux desktop environment configurations, optimized for productivity and aesthetics.

## What's Included

This repository contains configurations for:

- **🪟 Hyprland** - Modern tiling Wayland compositor with custom keybindings and window management
- **🐚 Bash** - Enhanced shell configuration with useful aliases and auto-tmux integration
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

### Install Dependencies

```bash
# Essential tools
sudo pacman -S git stow

# Hyprland and related packages
sudo pacman -S hyprland waybar starship tmux alacritty kitty

# Optional: File manager
sudo pacman -S walker
```

## Quick Installation

1. **Clone the repository** to your home directory:
   ```bash
   git clone git@github.com:shreyasmanolkar/dotfiles.git ~/dotfiles
   cd ~/dotfiles
   ```

2. **Install all configurations** using GNU Stow:
   ```bash
   stow .
   ```

3. **Install tmux plugins** (if using tmux):
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
- Manual save: `Ctrl+a`
- Manual restore: `Ctrl+e`

## Individual Package Installation

To install only specific configurations:

```bash
# Install only Hyprland configs
stow hypr

# Install only terminal configs
stow alacritty kitty

# Install only shell configs
stow bashrc starship tmux
```

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
stow .
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
- Ensure you're running on Wayland: `echo $XDG_SESSION_TYPE`
- Check NVIDIA drivers if using NVIDIA GPU
- Verify all dependencies are installed

### Tmux Plugins Not Working
```bash
# Reinstall plugins
~/.config/tmux/plugins/tpm/bin/install_plugins
```

### 

