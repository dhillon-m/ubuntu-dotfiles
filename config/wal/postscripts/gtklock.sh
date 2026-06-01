#!/bin/bash
# Substitute HOME path in rendered gtklock CSS files.
# wal doesn't have a $HOME variable, so templates use HOME_PLACEHOLDER.
WAL_CACHE="$HOME/.cache/wal"
for f in "$WAL_CACHE"/gtklock*.css; do
    [[ -f "$f" ]] && sed -i "s|HOME_PLACEHOLDER|$HOME|g" "$f"
done
