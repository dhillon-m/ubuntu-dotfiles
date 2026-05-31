source ~/.cache/wal/colors.sh

if status is-interactive
    set PATH $PATH /home/$USER/.local/bin

    anifetch ~/.config/wal/animations/current_animation.gif -r 15 -ca "--symbols braille --fg-only --colors 2"

    function wal
        command wal $argv -o ~/.config/wal/postscripts/animation.sh
    end

    set -x QT_QPA_PLATFORMTHEME qt5ct

    alias qbittorrent="~/.local/bin/qbittorrent.AppImage"
end
