#!/bin/bash
pavucontrol &
sleep 0.3
swaymsg "[app_id=\"pavucontrol\"] floating enable, resize set 800 600, move position center, move up 396px"
