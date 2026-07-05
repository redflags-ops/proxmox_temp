#!/usr/bin/env bash
# create-win-gpu-vm.sh — tạo VM Windows hiệu năng cao + GPU passthrough trên Proxmox.
# Chạy TRÊN Proxmox host (root). Đổi biến trong khối CONFIG rồi: bash create-win-gpu-vm.sh [VMID] [NAME]
set -euo pipefail

### ================= CONFIG =================
VMID="${1:-103}"
NAME="${2:-win-perf}"
CORES=12
SOCKETS=1
MEMORY=32768                       # MB — cố định, tắt balloon
DISK_GB=100
STORAGE="local-lvm"
BRIDGE="vmbr0"
GPU_PCI="0000:02:00"               # cả .0 (VGA) + .1 (audio) — 3060
WIN_ISO="local:iso/en-us_windows_server_2022_updated_feb_2026_x64_dvd_09efea0d.iso"

# CPU pinning (tùy chọn): pin VM vào core riêng, tách khỏi k8s. Xem topology bằng: lscpu
# Để trống = không pin. Ví dụ 12 core cuối: AFFINITY="10-21"
AFFINITY=""
### =========================================

VIRTIO_PATH="/var/lib/vz/template/iso/virtio-win.iso"
VIRTIO_ISO="local:iso/virtio-win.iso"

# --- Sanity checks ---
if qm status "$VMID" &>/dev/null; then
  echo "!! VMID $VMID đã tồn tại. Đổi VMID hoặc 'qm destroy $VMID' trước." >&2; exit 1
fi
if ! lspci -nnk -d 10de: | grep -q "vfio-pci"; then
  echo "!! GPU chưa bind vfio-pci — passthrough sẽ fail. Kiểm tra /etc/modprobe.d/vfio.conf" >&2; exit 1
fi

# --- virtio-win driver ISO (cần cho virtio-scsi/net khi cài Windows) ---
if ! pvesm list local | grep -q "virtio-win.iso"; then
  echo "[*] Chưa có virtio-win.iso — đang tải..."
  curl -fL --connect-timeout 15 -o "$VIRTIO_PATH" \
    https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso \
    || { echo "!! Tải chậm/lỗi. Tự tải ISO rồi bỏ vào $VIRTIO_PATH, chạy lại." >&2; exit 1; }
fi

# --- Tạo VM ---
CREATE_ARGS=(
  --name "$NAME"
  --ostype win11                   # bật full Hyper-V enlightenments cho Windows
  --machine q35 --bios ovmf
  --cpu host                       # lộ hết instruction set của CPU thật (AES/AVX...)
  --cores "$CORES" --sockets "$SOCKETS"
  --numa 1
  --memory "$MEMORY" --balloon 0   # RAM cố định, không bơm-xả
  --scsihw virtio-scsi-single
  --scsi0 "${STORAGE}:${DISK_GB},discard=on,iothread=1,ssd=1,cache=none,aio=io_uring"
  --efidisk0 "${STORAGE}:0,efitype=4m,pre-enrolled-keys=0"
  --net0 "virtio,bridge=${BRIDGE}"
  --vga std                        # giữ để xem console lúc cài; gỡ sau (xem note)
  --hostpci0 "${GPU_PCI},pcie=1"
  --agent enabled=1
  --ide2 "${WIN_ISO},media=cdrom"
  --ide3 "${VIRTIO_ISO},media=cdrom"
  --boot order="ide2;scsi0"
)
[[ -n "$AFFINITY" ]] && CREATE_ARGS+=( --affinity "$AFFINITY" )

qm create "$VMID" "${CREATE_ARGS[@]}"
qm set "$VMID" --onboot 1 >/dev/null   # tự bật khi host boot

cat <<EOF

[✓] VM $VMID ($NAME) tạo xong.
    Start: qm start $VMID  → mở noVNC console để cài.

LÚC CÀI WINDOWS:
  - Tới bước chọn ổ đĩa mà KHÔNG thấy disk → "Load driver" → trỏ vào CD virtio-win
    → thư mục vioscsi\\w11\\amd64 (hoặc 2k22). Chọn xong disk hiện ra.
  - Sau khi vào Windows: mở CD virtio-win chạy virtio-win-guest-tools.exe
    (cài virtio net + balloon + qemu-guest-agent một lượt).

TỐI ƯU PERFORMANCE SAU KHI CÀI (làm thêm, không bắt buộc):
  1. GPU dùng MSI interrupt (giảm latency): trong Windows chạy MSI util hoặc set
     HKLM\\SYSTEM\\CurrentControlSet\\Enum\\PCI\\...\\Device Parameters\\Interrupt Management\\MessageSignaledInterruptProperties\\MSISupported = 1
  2. Cài xong driver Nvidia + remote xong → gỡ VGA ảo cho 3060 làm màn hình chính:
     qm set $VMID --vga none   (nhớ có Sunshine/RDP trước khi gỡ, mất noVNC)
  3. Hugepages (RAM nhanh nhất, cần cấu hình host): thêm hugepagesz=1G hugepages=32
     vào kernel cmdline, rồi: qm set $VMID --hugepages 1024
  4. Nếu chỉ chạy 1-2 VM nặng: cân nhắc governor 'performance' cho các core đã pin.
EOF
