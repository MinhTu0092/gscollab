#!/bin/bash
set -euo pipefail

echo "
-------------------------------------------------------------
            INSTALLING REQUIRED PACKAGES
-------------------------------------------------------------
"

apt update -y
apt upgrade -y
apt install -y qemu-system qemu-utils cloud-utils

echo "
---------------------------------------------------------
            Made by Nissalop2

            Username = root
            Password = root
----------------------------------------------------------
"

# =============================
# Ubuntu 22.04 VM (Auto Setup)
# =============================

clear
cat << "EOF"
================================================
  _    _  ____  _____ _____ _   _  _____ ____   ______     ________
 | |  | |/ __ \|  __ \_   _| \ | |/ ____|  _ \ / __ \ \   / /___  /
 | |__| | |  | | |__) || | |  \| | |  __| |_) | |  | \ \_/ /   / / 
 |  __  | |  | |  ___/ | | |   \ | | |_ |  _ <| |  | |\   /   / /  
 | |  | | |__| | |    _| |_| |\  | |__| | |_) | |__| | | |   / /__ 
 |_|  |_|\____/|_|   |_____|_| \_|\_____|____/ \____/  |_|  /_____|
                                                                  
                POWERED BY HOPINGBOYZ & NISSALOP2
================================================
EOF

# =============================
# Configurable Variables
# =============================
VM_DIR="$HOME/vm"
IMG_FILE="$VM_DIR/ubuntu-cloud.img"
SEED_FILE="$VM_DIR/seed.iso"
MEMORY=319488     # 4GB RAM (safe for non-KVM VPS)
CPUS=89         # Lower CPU count since no hardware accel
SSH_PORT=24
DISK_SIZE=100G   # Smaller disk for VPS storage
HOSTNAME="notfleppygamer"

mkdir -p "$VM_DIR"
cd "$VM_DIR"

# =============================
# VM Image Setup
# =============================
if [ ! -f "$IMG_FILE" ]; then
    echo "[INFO] VM image not found, creating new VM..."
    wget -q https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -O "$IMG_FILE"
    qemu-img resize "$IMG_FILE" "$DISK_SIZE"

    # Cloud-init config with custom hostname + root login
    cat > user-data <<EOF
#cloud-config
hostname: ${HOSTNAME}
manage_etc_hosts: true
disable_root: false
ssh_pwauth: true
chpasswd:
  list: |
    root:root
  expire: false
growpart:
  mode: auto
  devices: ["/"]
  ignore_growroot_disabled: false
resize_rootfs: true
runcmd:
 - growpart /dev/vda 1 || true
 - resize2fs /dev/vda1 || true
 - sed -ri "s/^#?PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config
 - systemctl restart ssh
EOF

    cat > meta-data <<EOF
instance-id: iid-local01
local-hostname: ${HOSTNAME}
EOF

    cloud-localds "$SEED_FILE" user-data meta-data
    echo "[INFO] VM setup complete!"
else
    echo "[INFO] VM image found, skipping setup..."
fi

# =============================
# Start VM (Force Software Mode)
# =============================
echo "[INFO] Starting VM in SOFTWARE mode (no KVM)..."

exec qemu-system-x86_64 \
    -accel tcg -cpu qemu64 \
    -m "$MEMORY" \
    -smp "$CPUS" \
    -drive file="$IMG_FILE",format=qcow2,if=virtio \
    -drive file="$SEED_FILE",format=raw,if=virtio \
    -boot order=c \
    -device virtio-net-pci,netdev=n0 \
    -netdev user,id=n0,hostfwd=tcp::"$SSH_PORT"-:22 \
    -nographic -serial mon:stdio
