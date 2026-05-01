#!/bin/bash

# Inside Proxmox VE shell, 9000 is the VMID
qm create 9000 --name paycore-base --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0

# Import disk
qm importdisk 9000 /tmp/jammy-server-cloudimg-amd64.img local-lvm

# Attach disk to VM first
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0

# NOW resize after disk is attached
qm resize 9000 scsi0 20G

# Configure cloud-init
qm set 9000 --ide2 local-lvm:cloudinit --boot c --bootdisk scsi0 --serial0 socket --vga serial0

# Set user, SSH key, network, DNS
qm set 9000 --ciuser ubuntu --sshkey ~/.ssh/paycore-host.pub --ipconfig0 ip=10.230.18.5/24,gw=10.230.18.42 --nameserver "8.8.8.8 1.1.1.1"

# Start VM
qm start 9000