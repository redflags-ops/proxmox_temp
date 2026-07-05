#!/usr/bin/env bash
# create-debian12-template.sh — tạo Proxmox template Debian 12 (cloud-init) từ cloud image.
# Clone ra chạy ngay, tự set user/ssh-key/IP qua cloud-init. Chạy TRÊN host (root).
# Dùng:  bash create-debian12-template.sh [VMID] [NAME]
#        CIUSER=admin SSHKEYS=~/.ssh/id_ed25519.pub bash create-debian12-template.sh
set -euo pipefail

### ================= CONFIG =================
VMID="${1:-9001}"
NAME="${2:-debian12-tmpl}"
STORAGE="local-lvm"
BRIDGE="vmbr0"
CORES=2
MEMORY=2048
DISK_GB=20
CIUSER="${CIUSER:-debian}"                       # user mặc định trong clone
SSHKEYS="${SSHKEYS:-$HOME/.ssh/authorized_keys}" # public key đẩy vào clone
### =========================================

IMG_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
IMG="/var/lib/vz/template/iso/debian-12-genericcloud-amd64.qcow2"

qm status "$VMID" &>/dev/null && { echo "!! VMID $VMID đã tồn tại." >&2; exit 1; }

[[ -f "$IMG" ]] || { echo "[*] Tải Debian 12 cloud image..."; \
  curl -fL --connect-timeout 15 -o "$IMG" "$IMG_URL"; }

qm create "$VMID" --name "$NAME" --ostype l26 \
  --machine q35 --cpu host --cores "$CORES" --sockets 1 \
  --memory "$MEMORY" --balloon 0 \
  --net0 "virtio,bridge=${BRIDGE}" \
  --scsihw virtio-scsi-single \
  --serial0 socket --vga serial0 \
  --agent enabled=1

qm importdisk "$VMID" "$IMG" "$STORAGE"
qm set "$VMID" --scsi0 "${STORAGE}:vm-${VMID}-disk-0,discard=on,ssd=1,iothread=1"
qm set "$VMID" --ide2 "${STORAGE}:cloudinit"
qm set "$VMID" --boot order=scsi0
qm disk resize "$VMID" scsi0 "${DISK_GB}G"

qm set "$VMID" --ciuser "$CIUSER" --ipconfig0 ip=dhcp
[[ -f "$SSHKEYS" ]] && qm set "$VMID" --sshkeys "$SSHKEYS" || \
  echo "!! Không thấy $SSHKEYS — clone sẽ không có SSH key, đặt --sshkeys sau."

qm template "$VMID"

cat <<EOF

[✓] Template $VMID ($NAME) xong. Clone + dùng:
  qm clone $VMID 120 --name web01 --full
  qm set 120 --ipconfig0 ip=192.168.1.50/24,gw=192.168.1.1   # hoặc để dhcp
  qm start 120
Cấu hình giờ + software trong clone (ssh vào rồi chạy):
  sudo bash set-timezone.sh && sudo bash install-software.sh
EOF
