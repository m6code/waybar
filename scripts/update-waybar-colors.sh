#!/usr/bin/env bash
#
# update-waybar-colors.sh
#
# Regenerates a wallust color palette from the current (or given) wallpaper
# and reloads Waybar so its colors match. Meant to be called manually, or
# hooked into whatever sets your wallpaper (swww, hyprpaper, feh, nitrogen...)
# so it runs automatically every time the wallpaper changes.
#
# Usage:
#   ./update-waybar-colors.sh                # auto-detect current wallpaper
#   ./update-waybar-colors.sh /path/to/img.jpg

set -euo pipefail

WAYBAR_COLORS="$HOME/.config/waybar/colors.css"

# --- 1. figure out the current wallpaper -----------------------------------
detect_wallpaper() {
  # swww (most common on Hyprland/Sway setups)
  if command -v swww >/dev/null 2>&1 && pgrep -x swww-daemon >/dev/null 2>&1; then
    swww query 2>/dev/null | grep -oP 'image: \K.*' | head -n1
    return
  fi

  # hyprpaper
  if command -v hyprctl >/dev/null 2>&1 && pgrep -x hyprpaper >/dev/null 2>&1; then
    hyprctl hyprpaper listloaded 2>/dev/null | head -n1
    return
  fi

  # swaybg, invoked with an explicit -i path (readable from its cmdline)
  if pgrep -x swaybg >/dev/null 2>&1; then
    tr '\0' '\n' <"/proc/$(pgrep -x swaybg | head -n1)/cmdline" |
      grep -E '\.(jpe?g|png|webp|bmp)$' | head -n1
    return
  fi

  # feh writes ~/.fehbg with the last-used image
  if [ -f "$HOME/.fehbg" ]; then
    grep -oP "(?<=')[^']+\.(jpe?g|png|webp|bmp)(?=')" "$HOME/.fehbg" | head -n1
    return
  fi

  # nitrogen
  if [ -f "$HOME/.config/nitrogen/bg-saved.cfg" ]; then
    grep -oP '^file=\K.*' "$HOME/.config/nitrogen/bg-saved.cfg" | head -n1
    return
  fi
}

# WALLPAPER_PATH="${1:-$(detect_wallpaper || true)}"

WALLPAPER_PATH="${1:-$(detect_wallpaper || echo "$HOME/Pictures/wallpaper/wallpaper.jpg")}"

if [ -z "${WALLPAPER_PATH:-}" ] || [ ! -f "$WALLPAPER_PATH" ]; then
  echo "Couldn't auto-detect a wallpaper file." >&2
  echo "Pass the path explicitly: $0 $WALLPAPER_PATH" >&2
  exit 1
fi

# --- 2. make sure wallust is installed --------------------------------------
if ! command -v wallust >/dev/null 2>&1; then
  echo "wallust is not installed." >&2
  echo "Install it: https://codeberg.org/explosion-mental/wallust#installation" >&2
  echo "(Arch: pacman -S wallust | Cargo: cargo install wallust)" >&2
  exit 1
fi

# --- 3. generate the palette --------------------------------------------
echo "Generating palette from: $WALLPAPER_PATH"
wallust run "$WALLPAPER_PATH"

if [ ! -f "$WAYBAR_COLORS" ]; then
  echo "Expected $WAYBAR_COLORS to be written by wallust but it wasn't." >&2
  echo "Check that ~/.config/wallust/wallust.toml has the [templates.waybar] entry." >&2
  exit 1
fi

# --- 4. reload waybar --------------------------------------------------
if pgrep -x waybar >/dev/null 2>&1; then
  # Waybar doesn't hot-reload @import'd CSS, so restart it.
  killall waybar
  sleep 0.2
  setsid waybar >/dev/null 2>&1 &
  disown
fi

echo "Done. Waybar colors updated from $WALLPAPER_PATH"
