#!/bin/bash
source ~/.cache/wal/colors.sh

TREE=$(swaymsg -t get_tree)

WINDOWS=$(echo "$TREE" | python3 -c "
import json, sys

def find_windows(node, workspace=None):
    results = []
    if node.get('type') == 'workspace':
        workspace = node.get('name', '?')
    is_window = (
        node.get('type') in ('con', 'floating_con') and
        not node.get('nodes') and
        not node.get('floating_nodes') and
        node.get('name')
    )
    if is_window:
        app = node.get('app_id') or node.get('window_properties', {}).get('class', '?')
        title = node.get('name', '')
        results.append((workspace, node['id'], app, title))
    for child in node.get('nodes', []) + node.get('floating_nodes', []):
        results.extend(find_windows(child, workspace))
    return results

tree = json.loads(sys.stdin.read())
windows = find_windows(tree)
for ws, wid, app, title in windows:
    print(f'{app} | {title[:50]}')
")

CHOICE=$(echo "$WINDOWS" | fuzzel --dmenu \
    --anchor=top-left --x-margin=5 --y-margin=5 --width=60 --minimal-lines --lines=20 \
    --font="Iosevka Nerd Font Propo:size=12" \
    --background="${background}ff" --text-color="${color4}ff" \
    --match-color="${color1}ff" --border-color="${color4}ff" \
    --selection-color="${color4}ff" --selection-text-color="${background}ff" \
    --selection-match="${color1}ff" --prompt="  Windows: ")

[[ -z "$CHOICE" ]] && exit 0

APP=$(echo "$CHOICE" | cut -d'|' -f1 | xargs)
WS=$(echo "$CHOICE"  | cut -d'|' -f3 | xargs)

swaymsg "workspace $WS"
swaymsg "[app_id=\"$APP\"] focus"
