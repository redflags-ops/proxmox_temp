# proxmox_temp

Bộ script tạo nhanh VM/template trên Proxmox + cấu hình cơ bản cho guest.

## Scripts — chạy TRÊN Proxmox host (root)

| Script | Việc |
|---|---|
| `create-windows-template.sh` | Tạo VM Windows Server 2022 base (virtio, không GPU) để **clone**. Cần sysprep trước khi `qm template`. |
| `create-win-gpu-vm.sh` | Tạo VM Windows hiệu năng cao **có GPU passthrough** (workstation, không phải template). |
| `create-debian12-template.sh` | Tạo template Debian 12 **cloud-init** từ cloud image — clone ra tự cấu hình user/ssh/IP. |

## Scripts — chạy TRONG guest (root/sudo)

| Script | Việc |
|---|---|
| `set-timezone.sh` | Đặt giờ GMT+7 (`Asia/Ho_Chi_Minh`) + bật NTP. |
| `install-software.sh` | Cài bộ network/diagnostic tools (ping, traceroute, dig, nmap, tcpdump, net-tools, curl, wget, nc...). |

## Quy trình mẫu

```bash
# --- Trên host ---
bash create-debian12-template.sh 9001 debian12-tmpl
qm clone 9001 120 --name web01 --full
qm start 120

# --- Trong guest (ssh vào clone) ---
sudo bash set-timezone.sh
sudo bash install-software.sh
```

## Ghi chú

- **Template không gắn GPU**: passthrough chỉ 1 VM dùng được. Cần GPU thì add cho từng
  clone: `qm set <id> --hostpci0 0000:02:00,pcie=1`.
- Windows dùng **virtio-scsi/net** → phải "Load driver" từ CD `virtio-win` lúc cài
  (script tự tải + gắn sẵn).
- Sửa `VMID`, `STORAGE`, `BRIDGE`, `WIN_ISO`... trong khối CONFIG đầu mỗi script cho khớp môi trường.
