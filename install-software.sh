#!/usr/bin/env bash
# install-software.sh — cài bộ công cụ network/diagnostic cho Debian 12
# (theo redflags-ops/debian-setup). Chạy TRONG guest (root/sudo).
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Cần chạy bằng root/sudo." >&2; exit 1; }
export DEBIAN_FRONTEND=noninteractive

PKGS=(iputils-ping traceroute dnsutils telnet nmap tcpdump net-tools curl wget netcat-openbsd)

echo "[*] apt update + upgrade..."
apt-get update -y
apt-get upgrade -y

echo "[*] Cài: ${PKGS[*]}"
apt-get install -y "${PKGS[@]}"

echo "[✓] Kiểm tra công cụ:"
for c in ping traceroute dig telnet nmap tcpdump netstat ifconfig curl wget nc; do
  if command -v "$c" >/dev/null 2>&1; then echo "  ok   $c"; else echo "  MISS $c"; fi
done
