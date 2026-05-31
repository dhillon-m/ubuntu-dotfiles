#!/usr/bin/env bash
# Ubuntu 24.04 dotfiles installer
# Recreates the full Sway/Wayland desktop on a fresh Ubuntu 24.04 install.
# Run as your normal user (not root) — sudo is called internally where needed.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOLD='\033[1m'; RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
heading() { echo -e "\n${BOLD}${BLUE}── $* ─────────────────────────────────────${NC}"; }

# Symlink src → dst, backing up any existing non-link
link_file() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        mv "$dst" "${dst}.bak.$(date +%s)"
        warn "Backed up existing $(basename "$dst")"
    fi
    ln -sf "$src" "$dst"
}

# Symlink a whole directory (replaces dst with a symlink to src dir)
link_dir() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        mv "$dst" "${dst}.bak.$(date +%s)"
        warn "Backed up existing $(basename "$dst")/"
    fi
    ln -sfn "$src" "$dst"
}

# ── 1. External repositories ─────────────────────────────────────────────────
setup_repos() {
    heading "Repositories"

    # universe contains keyd, gtklock, and many other needed packages
    sudo add-apt-repository -y universe

    if ! apt-cache policy 2>/dev/null | grep -q "papirus"; then
        sudo add-apt-repository -y ppa:papirus/papirus
        info "Added Papirus PPA"
    fi

    if ! apt-cache policy 2>/dev/null | grep -q "fastfetch"; then
        sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch
        info "Added fastfetch PPA"
    fi

    # Microsoft .NET repo
    if ! dpkg -l dotnet-sdk-8.0 &>/dev/null; then
        local tmp; tmp=$(mktemp)
        wget -q -O "$tmp" https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb
        sudo dpkg -i "$tmp"; rm "$tmp"
        info "Added Microsoft .NET repo"
    fi

    sudo apt-get update -q
    ok "Repositories ready"
}

# ── 2. APT packages ──────────────────────────────────────────────────────────
install_apt() {
    heading "APT packages"

    local pkgs=(
        # Wayland / Sway core
        sway swaybg swayidle fuzzel grim slurp wl-clipboard
        waybar mako-notifier
        xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gnome

        # Terminal + shell
        kitty fish

        # Qt theming
        qt5ct qt5-style-kvantum qt5-style-kvantum-themes qt5-style-kvantum-l10n
        qt6ct qt6-style-kvantum qt6-wayland qtwayland5
        qt5-gtk-platformtheme qt6-gtk-platformtheme

        # Display / input utilities
        ddcutil i2c-tools keyd read-edid

        # CLI tools
        btop fastfetch micro chafa jq curl wget git

        # Media
        vlc ffmpeg imagemagick

        # Audio (Pipewire stack)
        pipewire pipewire-pulse wireplumber pavucontrol

        # Bluetooth
        blueman bluez

        # Build tools + Python
        build-essential cmake meson ninja-build
        python3 python3-pip python3.12-venv python3-dev pipx

        # .NET 8
        dotnet-sdk-8.0

        # System fonts
        fonts-noto-color-emoji fonts-noto-core fonts-ubuntu

        # Theming build dep
        sassc

        # Apps
        gamemode thunar nautilus vlc
    )

    sudo apt-get install -y --no-install-recommends "${pkgs[@]}" \
        || warn "Some packages may have failed — check output above"

    # gtklock: try apt, suggest source build if unavailable
    if ! sudo apt-get install -y gtklock 2>/dev/null; then
        warn "gtklock not in apt repos. Build from: https://github.com/jovanlanik/gtklock"
    fi

    # Vesktop (Discord client) — download latest .deb from GitHub releases
    if ! dpkg -l vesktop &>/dev/null; then
        local vd_ver
        vd_ver=$(curl -s https://api.github.com/repos/Vencord/Vesktop/releases/latest \
                  | grep '"tag_name"' | cut -d'"' -f4 | tr -d 'v')
        local vd_deb="vesktop_${vd_ver}_amd64.deb"
        wget -q --show-progress \
            -O "/tmp/$vd_deb" \
            "https://github.com/Vencord/Vesktop/releases/download/v${vd_ver}/$vd_deb" \
            && sudo dpkg -i "/tmp/$vd_deb" && rm "/tmp/$vd_deb" \
            && ok "Vesktop installed" \
            || warn "Vesktop install failed — download manually from https://github.com/Vencord/Vesktop/releases"
    else
        info "Vesktop already installed"
    fi

    ok "APT packages installed"
}

# ── 3. Snap packages ─────────────────────────────────────────────────────────
install_snaps() {
    heading "Snap packages"
    snap install code --classic  || true
    snap install firefox         || true
    snap install spotify         || true
    ok "Snaps installed"
}

# ── 4. Python packages ───────────────────────────────────────────────────────
install_python() {
    heading "Python packages"
    # Ubuntu 24.04 enforces PEP 668 — use pipx for CLI tools, pip with
    # --break-system-packages only for libraries needed by scripts
    pipx install pywal        || pipx upgrade pywal
    pipx install autotiling   || pipx upgrade autotiling
    pipx install anifetch-cli || pipx upgrade anifetch-cli
    pipx install netorbit     || pipx upgrade netorbit
    # pillow is a library imported directly by setwallpaper — inject into pipx
    # envs that need it, and also install for the user python environment
    pip3 install --user --break-system-packages pillow i3ipc python-xlib
    ok "Python packages installed"
}

# ── 5. Iosevka Nerd Fonts ────────────────────────────────────────────────────
install_fonts() {
    heading "Iosevka Nerd Fonts"
    local font_dir="$HOME/.local/share/fonts"
    mkdir -p "$font_dir"

    if fc-list | grep -qi "iosevka nerd font"; then
        info "Iosevka Nerd Font already installed — skipping"
        return
    fi

    local nf_ver
    nf_ver=$(curl -s https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest \
              | grep '"tag_name"' | cut -d'"' -f4)
    info "Downloading Nerd Fonts $nf_ver (Iosevka + IosevkaTerm)"

    for font in Iosevka IosevkaTerm; do
        wget -q --show-progress \
            -O "/tmp/${font}.tar.xz" \
            "https://github.com/ryanoasis/nerd-fonts/releases/download/${nf_ver}/${font}.tar.xz"
        tar -xf "/tmp/${font}.tar.xz" -C "$font_dir" --wildcards '*.ttf' 2>/dev/null || true
        rm "/tmp/${font}.tar.xz"
    done

    fc-cache -f "$font_dir"
    ok "Iosevka Nerd Fonts installed"
}

# ── 6. Gruvbox-Material-Dark GTK theme ───────────────────────────────────────
install_theme() {
    heading "Gruvbox-Material-Dark theme"
    local theme_dir="$HOME/.local/share/themes/Gruvbox-Material-Dark"

    if [[ ! -d "$theme_dir" ]]; then
        local tmp; tmp=$(mktemp -d)
        git clone --depth 1 https://github.com/Fausto-Korpsvart/Gruvbox-GTK-Theme "$tmp/theme"
        mkdir -p "$theme_dir"
        cp -r "$tmp/theme/themes/Gruvbox-Material-Dark/." "$theme_dir/"
        rm -rf "$tmp"
        ok "GTK theme installed"
    else
        info "GTK theme already present — skipping"
    fi

    # Apply via gsettings (works in GNOME; Sway uses gtk-3.0/settings.ini directly)
    gsettings set org.gnome.desktop.interface gtk-theme         'Gruvbox-Material-Dark'
    gsettings set org.gnome.desktop.interface icon-theme        'Gruvbox-Material-Dark'
    gsettings set org.gnome.desktop.interface color-scheme      'prefer-dark'
    gsettings set org.gnome.desktop.interface font-name         'Iosevka Nerd Font Propo 11'
    gsettings set org.gnome.desktop.interface monospace-font-name 'Iosevka Nerd Font 12'
    gsettings set org.gnome.desktop.interface document-font-name 'Iosevka Nerd Font Propo 11'
    gsettings set org.gnome.desktop.interface cursor-theme      'DMZ-White'
    ok "Theme applied"
}

# ── 7. Link dotfiles ─────────────────────────────────────────────────────────
link_dotfiles() {
    heading "Dotfiles"

    # Directory links (whole dir becomes a symlink)
    link_dir "${REPO}/config/sway"    "$HOME/.config/sway"
    link_dir "${REPO}/config/kitty"   "$HOME/.config/kitty"
    link_dir "${REPO}/config/fuzzel"  "$HOME/.config/fuzzel"
    link_dir "${REPO}/config/mako"    "$HOME/.config/mako"
    link_dir "${REPO}/config/waybar"  "$HOME/.config/waybar"
    link_dir "${REPO}/config/gtklock" "$HOME/.config/gtklock"
    link_dir "${REPO}/config/micro"   "$HOME/.config/micro"
    link_dir "${REPO}/config/Kvantum" "$HOME/.config/Kvantum"
    link_dir "${REPO}/config/walcord" "$HOME/.config/walcord"

    # wal sub-dirs (don't replace the whole ~/.config/wal — wal writes cache there)
    mkdir -p "$HOME/.config/wal"
    link_dir "${REPO}/config/wal/templates"    "$HOME/.config/wal/templates"
    link_dir "${REPO}/config/wal/colorschemes" "$HOME/.config/wal/colorschemes"
    link_dir "${REPO}/config/wal/postscripts"  "$HOME/.config/wal/postscripts"
    mkdir -p "$HOME/.config/wal/animations"
    info "Place .gif files in ~/.config/wal/animations/ (e.g. luna.gif, auar.gif)"

    # Individual files
    link_file "${REPO}/config/fish/config.fish"       "$HOME/.config/fish/config.fish"
    link_file "${REPO}/config/gtk-3.0/settings.ini"   "$HOME/.config/gtk-3.0/settings.ini"
    link_file "${REPO}/config/gtk-4.0/settings.ini"   "$HOME/.config/gtk-4.0/settings.ini"
    link_file "${REPO}/config/btop/btop.conf"          "$HOME/.config/btop/btop.conf"
    link_file "${REPO}/config/qt5ct/qt5ct.conf"        "$HOME/.config/qt5ct/qt5ct.conf"

    # fish_variables: copy once (fish manages this file at runtime)
    if [[ ! -f "$HOME/.config/fish/fish_variables" ]]; then
        cp "${REPO}/config/fish/fish_variables" "$HOME/.config/fish/fish_variables"
    fi

    # setwallpaper script
    mkdir -p "$HOME/.local/bin"
    link_file "${REPO}/local/bin/setwallpaper" "$HOME/.local/bin/setwallpaper"
    chmod +x "$HOME/.local/bin/setwallpaper"

    # gtklock style: substitute HOME path (CSS can't use env vars)
    local gtklock_dst="$HOME/.config/gtklock/style.css"
    # The symlinked style.css uses HOME_PLACEHOLDER; render a real copy
    if [[ -f "${REPO}/config/gtklock/style.css" ]]; then
        mkdir -p "$HOME/.config/gtklock"
        sed "s|HOME_PLACEHOLDER|$HOME|g" "${REPO}/config/gtklock/style.css" \
            > "$HOME/.config/gtklock/style.css"
        info "Rendered gtklock style.css with HOME=$HOME"
    fi

    ok "Dotfiles linked"
}

# ── 8. System config (/etc) ──────────────────────────────────────────────────
setup_system() {
    heading "System config"

    sudo mkdir -p /etc/keyd
    sudo cp "${REPO}/etc/keyd/default.conf" /etc/keyd/default.conf
    sudo systemctl enable --now keyd
    ok "keyd configured and enabled"

    sudo cp "${REPO}/etc/udev/rules.d/60-ddcutil-i2c.rules" /etc/udev/rules.d/
    sudo cp "${REPO}/etc/udev/hwdb.d/99-mouse-remap.hwdb"   /etc/udev/hwdb.d/
    sudo systemd-hwdb update
    sudo udevadm trigger
    ok "udev rules applied"

    sudo cp "${REPO}/etc/modprobe.d/bluetooth.conf" /etc/modprobe.d/
    ok "modprobe bluetooth config applied"

    if [[ -d /opt/Jackett ]]; then
        sudo cp "${REPO}/etc/systemd/system/jackett.service" /etc/systemd/system/
        sudo systemctl enable --now jackett
        ok "Jackett service enabled"
    else
        warn "Jackett not at /opt/Jackett — see README for install instructions"
    fi
}

# ── 9. Default shell ─────────────────────────────────────────────────────────
setup_shell() {
    heading "Default shell"
    local fish_path; fish_path=$(command -v fish)
    if [[ "$SHELL" != "$fish_path" ]]; then
        grep -qF "$fish_path" /etc/shells || echo "$fish_path" | sudo tee -a /etc/shells
        chsh -s "$fish_path"
        ok "Default shell set to fish"
    else
        info "fish already default"
    fi
}

# ── 10. Initial pywal theme ──────────────────────────────────────────────────
apply_wal() {
    heading "pywal theme"
    if command -v wal &>/dev/null; then
        wal --theme luna -o "$HOME/.config/wal/postscripts/animation.sh" 2>/dev/null \
            && ok "pywal luna theme applied" \
            || warn "wal failed (needs Wayland session). Run: wal --theme luna"
    else
        warn "wal not in PATH yet — run 'wal --theme luna' after next login"
    fi
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo -e "${BOLD}Ubuntu 24.04 Dotfiles Installer${NC}"
    echo ""

    local skip_apt=false skip_snaps=false skip_fonts=false skip_repos=false
    for arg in "$@"; do
        case "$arg" in
            --skip-repos)  skip_repos=true ;;
            --skip-apt)    skip_apt=true ;;
            --skip-snaps)  skip_snaps=true ;;
            --skip-fonts)  skip_fonts=true ;;
            --dotfiles-only)
                skip_repos=true; skip_apt=true; skip_snaps=true; skip_fonts=true ;;
        esac
    done

    $skip_repos  || setup_repos
    $skip_apt    || install_apt
    $skip_snaps  || install_snaps
    install_python
    $skip_fonts  || install_fonts
    install_theme
    link_dotfiles
    setup_system
    setup_shell
    apply_wal

    heading "Done — hardware-specific steps required"
    cat <<'EOF'

  1. Display outputs — edit ~/.config/sway/config
     Run:  swaymsg -t get_outputs
     Set the correct output names, positions, scales, and workspace assignments.

  2. Wallpaper script — edit ~/.local/bin/setwallpaper
     Update the MONITORS dict to match your display names and resolutions.

  3. Lock screen — re-render gtklock style.css with correct output names:
     The installed style.css uses "DP-3" and "HDMI-A-1" — edit to match yours.

  4. GPU bar widget — edit ~/.config/waybar/main/scripts/gpu.sh
     Run:  lspci | grep -i vga
     Update DISCRETE_PCI to your discrete GPU's PCI address.

  5. ProtonVPN — install from https://protonvpn.com/support/linux-ubuntu-vpn-setup/

  6. Jackett — download from https://github.com/Jackett/Jackett/releases
     Extract to /opt/Jackett, then re-run:  sudo systemctl enable --now jackett

  7. qBittorrent AppImage — download from https://www.qbittorrent.org/download
     Place at ~/.local/bin/qbittorrent.AppImage

  8. Wallpapers — place images in ~/.config/sway/ or run:
     setwallpaper <image-path>

  Log out and back in to a Sway session to apply everything.
EOF
}

main "$@"
