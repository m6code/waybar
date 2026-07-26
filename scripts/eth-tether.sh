#!/bin/bash

# --- HELPER: AUTO-DETECT USB TETHER INTERFACE ---
get_usb_interface() {
  ip -o link show | awk -F': ' '$2 ~ /^(enx|enp.*u)/ && $3 ~ /LOWER_UP/ {print $2; exit}'
}

# --- HELPER: GET BYTES ---
get_bytes() {
  local iface=$1
  local type=$2
  if [ -z "$iface" ]; then
    echo 0
    return
  fi
  cat /sys/class/net/"$iface"/statistics/${type}_bytes 2>/dev/null || echo 0
}

# --- HELPER: FORMAT SPEED ---
format_speed() {
  local speed=$1
  if [ -z "$speed" ] || [ "$speed" -le 0 ]; then
    echo "0 B/s"
    return
  fi
  if [ "$speed" -gt 1048576 ]; then
    awk "BEGIN {printf \"%.1f MB/s\", $speed/1048576}"
  elif [ "$speed" -gt 1024 ]; then
    awk "BEGIN {printf \"%.1f KB/s\", $speed/1024}"
  else
    echo "${speed} B/s"
  fi
}

IFACE=$(get_usb_interface)

if [ -z "$IFACE" ]; then
  echo '{"text":"", "tooltip":"Disconnected", "class":"disconnected"}'
  exit 0
fi

# Check it actually has an IP before reporting live stats
HAS_IP=$(ip -4 addr show "$IFACE" 2>/dev/null | grep -c "inet ")
if [ "$HAS_IP" -eq 0 ]; then
  echo "{\"text\":\"󰈁 ${IFACE} (No IP)\", \"tooltip\":\"${IFACE}\", \"class\":\"linked\"}"
  exit 0
fi

RX1=$(get_bytes "$IFACE" rx)
TX1=$(get_bytes "$IFACE" tx)
sleep 1
RX2=$(get_bytes "$IFACE" rx)
TX2=$(get_bytes "$IFACE" tx)

RX_SPEED=$((RX2 - RX1))
TX_SPEED=$((TX2 - TX1))
[ "$RX_SPEED" -lt 0 ] && RX_SPEED=0
[ "$TX_SPEED" -lt 0 ] && TX_SPEED=0

RX_FMT=$(format_speed "$RX_SPEED")
TX_FMT=$(format_speed "$TX_SPEED")

echo "{\"text\":\" ⌄ ${RX_FMT} ⌃ ${TX_FMT} 󰈁\", \"tooltip\":\"${IFACE}\", \"class\":\"connected\"}"
