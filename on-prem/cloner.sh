#!/bin/bash
set -euxo pipefail


CLONE_VMID=100
TEMPLATE=9000
CLONE_VM_NAME="paycore-on-prem"
STORAGE="local-lvm"

# We override the IP & Gateway we used for the template
STATIC_IP="192.168.123.10"
GATEWAY="192.168.123.2"
SSH_PUBKEY_PATH=$HOME/.ssh/paycore-host.pub

qm clone $TEMPLATE $CLONE_VMID --name $CLONE_VM_NAME --full true --storage $STORAGE

qm resize $CLONE_VMID scsi0 20G

qm set $CLONE_VMID --ciuser ubuntu --sshkey $SSH_PUBKEY_PATH --ipconfig0 ip=${STATIC_IP}/24,gw=${GATEWAY}

qm start $CLONE_VMID





