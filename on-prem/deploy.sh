#!/bin/bash
set -euxo pipefail


CLONE_VMID=100
TEMPLATE=9000
CLONE_VM_NAME="paycore-on-prem"
STORAGE="local-lvm"

# We override the IP & Gateway we used for the template
STATIC_IP="10.54.146.3"
GATEWAY="10.54.146.217"
SSH_PUBKEY_PATH=$HOME/.ssh/paycore-host.pub

qm clone $TEMPLATE $CLONE_VMID --name $CLONE_VM_NAME --full true --storage $STORAGE

qm set $CLONE_VMID --ciuser ubuntu --sshkey $SSH_PUBKEY_PATH --ipconfig0 ip=${STATIC_IP}/24,gw=${GATEWAY}

qm start $CLONE_VMID

echo "VM $CLONE_VMID started. Waiting for cloud-init to finish..."

# The STATIC_IP%/* is just a safety check
for i in $(seq 1 24); do
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@${STATIC_IP%/*} "echo ready" 2>/dev/null; then
        echo "VM is reacheable at ${STATIC_IP%/*}"
        exit 0
    fi
    echo "Attempt $i/24 -- waiting..."
    sleep 5
done

echo "ERROR: VM did not become reachable within 120s. Check: qm status $CLONE_VMID"
exit 1



