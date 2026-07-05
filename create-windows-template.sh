#!/usr/bin/env bash
# create-windows-template.sh — tạo VM Windows base để làm TEMPLATE (clone ra nhiều máy).
# KHÔNG gắn GPU: template dùng để clone; GPU passthrough add riêng cho từng clone.
# Chạy TRÊN Proxmox host (root): bash create-windows-template.sh [VMID] [NAME]
set -euo pipefail

### ================= CONFIG =================
VMID="${1:-9000}"
NAME="${2:-win2022-tmpl}"
CORES=4
MEMORY=8192                        # MB
DISK_GB=60
STORAGE="local-lvm"
BRIDGE="vmbr0"
WIN_ISO="local:iso/en-us_windows_server_2022_updated_feb_2026_x64_dvd_09efea0d.iso"
### =========================================

VIRTIO_PATH="/var/lib/vz/template/iso/virtio-win.iso"
VIRTIO_ISO="local:iso/virtio-win.iso"

qm status "$VMID" &>/dev/null && { echo "!! VMID $VMID đã tồn tại." >&2; exit 1; }

if ! pvesm list local | grep -q "virtio-win.iso"; then
  echo "[*] Tải virtio-win.iso..."
  curl -fL --connect-timeout 15 -o "$VIRTIO_PATH" \
    https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso \
    || { echo "!! Tải lỗi — tự bỏ ISO vào $VIRTIO_PATH rồi chạy lại." >&2; exit 1; }
fi

qm create "$VMID" \
  --name "$NAME" --ostype win11 \
  --machine q35 --bios ovmf \
  --cpu host --cores "$CORES" --sockets 1 --numa 1 \
  --memory "$MEMORY" --balloon 0 \
  --scsihw virtio-scsi-single \
  --scsi0 "${STORAGE}:${DISK_GB},discard=on,iothread=1,ssd=1,cache=none,aio=io_uring" \
  --efidisk0 "${STORAGE}:0,efitype=4m,pre-enrolled-keys=0" \
  --net0 "virtio,bridge=${BRIDGE}" \
  --vga std \
  --agent enabled=1 \
  --ide2 "${WIN_ISO},media=cdrom" \
  --ide3 "${VIRTIO_ISO},media=cdrom" \
  --boot order="ide2;scsi0"

cat <<EOF

[✓] VM $VMID ($NAME) tạo xong. Các bước biến thành template:
  1. qm start $VMID → cài Windows. Ở bước chọn ổ đĩa không thấy disk → "Load driver"
     → CD virtio-win, thư mục vioscsi\\2k22\\amd64.
  2. Trong Windows: chạy virtio-win-guest-tools.exe (net+balloon+guest-agent),
     Windows Update, cấu hình chung mày muốn có sẵn trong mọi clone.
  3. QUAN TRỌNG — sysprep để generalize (không thì clone trùng SID/hostname):
       C:\\Windows\\System32\\Sysprep\\sysprep.exe /generalize /oobe /shutdown
  4. Gỡ ISO:  qm set $VMID --ide2 none --ide3 none
  5. Template: qm template $VMID
  6. Clone:   qm clone $VMID 120 --name may-moi --full
     Cần GPU?  qm set 120 --hostpci0 0000:02:00,pcie=1
EOF
