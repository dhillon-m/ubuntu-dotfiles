#!/bin/bash
anifetch --clear

THEME=$(cat ~/.cache/wal/last_used_theme 2>/dev/null | sed 's/\.json//' | xargs basename 2>/dev/null)
ANIM_DIR="$HOME/.config/wal/animations"

if [[ -f "$ANIM_DIR/$THEME.gif" ]]; then
    ln -sf "$ANIM_DIR/$THEME.gif" "$ANIM_DIR/current_animation.gif"
else
    ln -sf "$ANIM_DIR/luna.gif" "$ANIM_DIR/current_animation.gif"
fi

# Apply Vesktop/Discord theme (requires: pip install walcord)
if command -v walcord &>/dev/null; then
    walcord -t ~/.config/walcord/template.css
fi
