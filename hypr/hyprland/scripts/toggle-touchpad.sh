#!/usr/bin/env bash

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"
mkdir -p "$STATE_DIR"
STATE_FILE="$STATE_DIR/touchpad_state"

TOUCHPAD=$(hyprctl -j devices 2>/dev/null | jq -r '.mice[] | select(.name | contains("touchpad")) | .name' | head -1)

if [ -z "$TOUCHPAD" ]; then
    TOUCHPAD="asue120d:00-04f3:31fb-touchpad"
fi

if [ "$1" = "--restore" ]; then
    if [ -f "$STATE_FILE" ]; then
        CURRENT_STATE=$(cat "$STATE_FILE")
        if [ "$CURRENT_STATE" = "disabled" ]; then
            hyprctl eval "hl.device({ name = '$TOUCHPAD', enabled = false })" >/dev/null 2>&1
        else
            hyprctl eval "hl.device({ name = '$TOUCHPAD', enabled = true })" >/dev/null 2>&1
        fi
    fi
    exit 0
fi

# Determine current state: if state file exists, read it; otherwise assume enabled
if [ ! -f "$STATE_FILE" ]; then
    echo "enabled" > "$STATE_FILE"
fi

CURRENT_STATE=$(cat "$STATE_FILE")

if [ "$CURRENT_STATE" = "enabled" ]; then
    hyprctl eval "hl.device({ name = '$TOUCHPAD', enabled = false })" >/dev/null 2>&1
    echo "disabled" > "$STATE_FILE"
    notify-send -u low -a "Hyprland" -i touchpad-disabled "Touchpad" "Touchpad Disabled"
else
    hyprctl eval "hl.device({ name = '$TOUCHPAD', enabled = true })" >/dev/null 2>&1
    echo "enabled" > "$STATE_FILE"
    notify-send -u low -a "Hyprland" -i input-touchpad "Touchpad" "Touchpad Enabled"
fi
