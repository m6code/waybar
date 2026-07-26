#!/bin/bash
# ~/.config/waybar/scripts/battery-notify.sh
STATE_FILE="/tmp/waybar-battery-state"
CAPACITY=$(cat /sys/class/power_supply/BAT0/capacity)
STATUS=$(cat /sys/class/power_supply/BAT0/status)

# Determine current "tier" — this only changes at meaningful boundaries,
# not on every 1% capacity tick
if [ "$STATUS" = "Discharging" ] && [ "$CAPACITY" -le 25 ]; then
  TIER="critical"
elif [ "$STATUS" = "Discharging" ] && [ "$CAPACITY" -le 30 ]; then
  TIER="warning"
elif [ "$STATUS" = "Charging" ] && [ "$CAPACITY" -ge 100 ]; then
  TIER="full"
else
  TIER="normal"
fi

CURRENT="$STATUS:$TIER"
LAST=$(cat "$STATE_FILE" 2>/dev/null)
LAST_STATUS="${LAST%%:*}"

if [ "$CURRENT" != "$LAST" ]; then
  case "$TIER" in
  critical) notify-send -u critical "Very Low Battery" ;;
  warning) notify-send -u normal "Low Battery" ;;
  full) notify-send -u normal "Battery Full!" ;;
  normal)
    # only fire on an actual status flip, not every poll
    if [ -n "$LAST_STATUS" ] && [ "$LAST_STATUS" != "$STATUS" ]; then
      notify-send -u normal "Power Switch" "$STATUS"
    fi
    ;;
  esac
  echo "$CURRENT" >"$STATE_FILE"
fi
