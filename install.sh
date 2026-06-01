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

# ── 0. Bootstrap essentials ──────────────────────────────────────────────────
bootstrap() {
    heading "Bootstrap"
    sudo apt-get update -q
    sudo apt-get install -y curl wget git
    ok "Bootstrap done"
}

# ── 1. External repositories ─────────────────────────────────────────────────
setup_repos() {
    heading "Repositories"

    # universe contains gtklock and many other needed packages
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
        ddcutil i2c-tools read-edid

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

    # Vesktop (Discord client) — AppImage in ~/.local/bin/
    local vd_dst="$HOME/.local/bin/vesktop.AppImage"
    if [[ ! -f "$vd_dst" ]]; then
        local vd_ver
        vd_ver=$(curl -s https://api.github.com/repos/Vencord/Vesktop/releases/latest \
                  | grep '"tag_name"' | cut -d'"' -f4 | tr -d 'v')
        wget -q --show-progress \
            -O "$vd_dst" \
            "https://github.com/Vencord/Vesktop/releases/download/v${vd_ver}/Vesktop-${vd_ver}.AppImage" \
            && chmod +x "$vd_dst" \
            && ok "Vesktop AppImage installed to $vd_dst" \
            || warn "Vesktop install failed — download manually from https://github.com/Vencord/Vesktop/releases"
    else
        info "Vesktop AppImage already present"
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

# ── 3b. Build waybar from source ─────────────────────────────────────────────
build_waybar() {
    heading "waybar (build from source)"

    # Ubuntu 24.04 ships waybar 0.9.24 which has broken :hover on non-button modules.
    # Building from HEAD of master gives 0.10+ where this is fixed.
    sudo apt-get install -y \
        libgtk-3-dev libgtkmm-3.0-dev libsigc++-2.0-dev \
        libpulse-dev \
        libnl-3-dev libnl-genl-3-dev \
        libdbusmenu-gtk3-dev \
        libfmt-dev libspdlog-dev \
        libupower-glib-dev \
        libplayerctl-dev \
        libevdev-dev libinput-dev libudev-dev \
        libxkbregistry-dev

    local tmp; tmp=$(mktemp -d)
    git clone --depth 1 https://github.com/Alexays/Waybar "$tmp/waybar"
    meson setup --buildtype=release \
        -Dmpd=disabled \
        -Dgps=disabled \
        -Dlibevdev=disabled \
        "$tmp/waybar" "$tmp/waybar/build"
    ninja -C "$tmp/waybar/build"
    sudo ninja -C "$tmp/waybar/build" install
    sudo ldconfig
    rm -rf "$tmp"
    ok "waybar $(waybar --version 2>&1 | head -1) installed"
}

# ── 3c. Build fuzzel from source ─────────────────────────────────────────────
build_fuzzel() {
    heading "fuzzel (build from source)"

    sudo apt-get install -y \
        libwayland-dev wayland-protocols libxkbcommon-dev \
        libcairo2-dev libpango1.0-dev libpixman-1-dev \
        libpng-dev libjpeg-dev libwebp-dev librsvg2-dev \
        libdbus-1-dev scdoc pkg-config

    # Ubuntu 24.04 ships pixman 0.42.2; fuzzel needs >= 0.46.0 — build it first
    local pixman_ver
    pixman_ver=$(pkg-config --modversion pixman-1 2>/dev/null || echo "0")
    if [[ "$(printf '%s\n' "0.46.0" "$pixman_ver" | sort -V | head -1)" != "0.46.0" ]]; then
        info "Building pixman from source (system has $pixman_ver, need >= 0.46.0)"
        local tmp_px; tmp_px=$(mktemp -d)
        git clone --depth 1 https://gitlab.freedesktop.org/pixman/pixman.git "$tmp_px/pixman"
        meson setup --buildtype=release "$tmp_px/pixman" "$tmp_px/pixman/build"
        ninja -C "$tmp_px/pixman/build"
        sudo ninja -C "$tmp_px/pixman/build" install
        sudo ldconfig
        rm -rf "$tmp_px"
        ok "pixman built and installed"
    fi

    local tmp; tmp=$(mktemp -d)
    git clone --depth 1 https://codeberg.org/dnkl/fuzzel "$tmp/fuzzel"
    meson setup --buildtype=release "$tmp/fuzzel" "$tmp/fuzzel/build"
    ninja -C "$tmp/fuzzel/build"
    sudo ninja -C "$tmp/fuzzel/build" install
    rm -rf "$tmp"
    ok "fuzzel $(fuzzel --version 2>&1) installed"
}

# ── 4. Python packages ───────────────────────────────────────────────────────
install_python() {
    heading "Python packages"
    # Ubuntu 24.04 enforces PEP 668 — use pipx for CLI tools, pip with
    # --break-system-packages only for libraries needed by scripts
    pipx install pywal        || pipx upgrade pywal
    pipx install autotiling   || pipx upgrade autotiling
    pipx install anifetch-cli || pipx upgrade anifetch-cli
    # pillow is a library imported directly by setwallpaper
    pip3 install --user --break-system-packages pillow i3ipc python-xlib
    pipx ensurepath
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
        # Find the dark variant (name may vary slightly between repo versions)
        local src
        src=$(find "$tmp/theme/themes" -maxdepth 1 -type d -iname "*gruvbox*dark*" | head -1)
        if [[ -z "$src" ]]; then
            warn "Could not find Gruvbox-Material-Dark in repo — available themes:"
            ls "$tmp/theme/themes/" || true
            rm -rf "$tmp"
        else
            mkdir -p "$theme_dir"
            cp -r "$src/." "$theme_dir/"
            rm -rf "$tmp"
            ok "GTK theme installed from $src"
        fi
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
    # gtklock uses machine-specific configs (see config/gtklock/machines/)
    # so we manage it as individual files rather than a directory symlink.
    # Remove any old whole-dir symlink from previous installs.
    [[ -L "$HOME/.config/gtklock" ]] && rm "$HOME/.config/gtklock"
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

    # Machine-specific sway config (displays, workspaces, waybar launch)
    local machine_conf="${REPO}/config/sway/machines/$(hostname).conf"
    if [[ -f "$machine_conf" ]]; then
        link_file "$machine_conf" "$HOME/.config/sway/local.conf"
        ok "Machine config linked for $(hostname)"
    else
        warn "No machine config for $(hostname) — create ${machine_conf} from an existing example"
        warn "Display, workspace, and waybar config will be missing until you do"
    fi

    # setwallpaper script
    mkdir -p "$HOME/.local/bin"
    link_file "${REPO}/local/bin/setwallpaper" "$HOME/.local/bin/setwallpaper"
    chmod +x "$HOME/.local/bin/setwallpaper"

    # Machine-specific gtklock config (output names, style path)
    # Repo: config/gtklock/machines/<hostname>.ini  →  rendered to ~/.config/gtklock/config.ini
    # Style CSS is generated by wal; config.ini points at ~/.cache/wal/gtklock-<hostname>.css
    local gtklock_machine="${REPO}/config/gtklock/machines/$(hostname).ini"
    if [[ -f "$gtklock_machine" ]]; then
        mkdir -p "$HOME/.config/gtklock"
        sed "s|HOME_PLACEHOLDER|$HOME|g" "$gtklock_machine" > "$HOME/.config/gtklock/config.ini"
        ok "gtklock config rendered for $(hostname)"
    else
        warn "No gtklock machine config for $(hostname) — create ${gtklock_machine} from an existing example"
    fi

    ok "Dotfiles linked"
}

# ── 8. System config (/etc) ──────────────────────────────────────────────────
setup_system() {
    heading "System config"

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

    bootstrap
    $skip_repos  || setup_repos
    $skip_apt    || install_apt
    $skip_snaps  || install_snaps
    build_waybar
    build_fuzzel
    install_python
    $skip_fonts  || install_fonts
    install_theme
    link_dotfiles
    setup_system
    setup_shell
    apply_wal

    heading "Done — hardware-specific steps required"
    cat <<'EOF'

  1. Machine config — auto-linked from config/sway/machines/<hostname>.conf
     If a warning appeared above, create that file for this machine.
     Run:  swaymsg -t get_outputs   (inside a Sway session) to find output names.

  2. Wallpaper script — edit ~/.local/bin/setwallpaper
     Update the MONITORS dict to match your display names and resolutions.

  3. Lock screen — machine-specific config auto-rendered from config/gtklock/machines/<hostname>.ini
     If a warning appeared above, create that file from an existing example.
     The CSS is generated by wal (window selectors must match your output names).
     Add a machine CSS template at config/wal/templates/gtklock-<hostname>.css if needed.

  4. GPU bar widget (AMD discrete) — edit ~/.config/waybar/main/scripts/gpu.sh
     Run:  lspci | grep -i vga
     Update DISCRETE_PCI to your discrete GPU's PCI address.
     Intel integrated GPU is detected automatically via RC6 residency.

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
