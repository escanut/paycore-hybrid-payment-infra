
VMID=9000

# Enable QEMU guest agent communication on Proxmox host
qm set $VMID --agent 1

# Gracefully shut down the VM
qm shutdown $VMID

# Wait for VM to fully stop before proceeding
while [ "$(qm status ${VMID} | awk '{print $2}')" != "stopped" ]; do
    sleep 2
done

# Convert the stopped VM into an immutable template
qm template $VMID