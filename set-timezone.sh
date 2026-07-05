#!/usr/bin/env bash
# set-timezone.sh — đặt timezone Linux = GMT+7 (Asia/Ho_Chi_Minh) + bật NTP.
# Chạy TRONG guest (root/sudo).
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Cần chạy bằng root/sudo." >&2; exit 1; }

TZ_TARGET="Asia/Ho_Chi_Minh"

echo "[*] Trước:"; timedatectl | grep -iE "time zone|synchronized"

timedatectl set-timezone "$TZ_TARGET"
timedatectl set-ntp true
hwclock --systohc 2>/dev/null || true   # container không có RTC → bỏ qua

echo "[✓] Sau:"; timedatectl | grep -iE "time zone|synchronized"
date
