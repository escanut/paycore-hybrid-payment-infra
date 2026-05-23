#!/bin/bash

VMID=9000
USERNAME="ubuntu"
SSH_KEY=$HOME/.ssh/paycore-host.pub
VM_NAME="paycore-base"
IMG_LOC=/root/jammy-server-cloudimg-amd64.img
STATIC_IP="192.168.123.20"
GATEWAY="192.168.123.2"
SIZE="4G"

# Inside Proxmox VE shell, 9000 is the VMID
qm create $VMID --name $VM_NAME --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0

# Import disk
qm importdisk $VMID $IMG_LOC local-lvm

# Attach disk to VM first
qm set $VMID --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0

# NOW resize after disk is attached
qm resize $VMID scsi0 $SIZE

# Configure cloud-init
qm set $VMID --ide2 local-lvm:cloudinit --boot c --bootdisk scsi0 --serial0 socket --vga serial0

# Set user, SSH key, network, DNS
qm set $VMID --ciuser $USERNAME --sshkey $SSH_KEY --ipconfig0 "ip=${STATIC_IP}/24,gw=${GATEWAY}" --nameserver "8.8.8.8 1.1.1.1"

# Start VM
qm start $VMID