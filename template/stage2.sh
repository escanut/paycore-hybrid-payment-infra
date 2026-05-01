# Enable QEMU guest agent communication on Proxmox host
qm set 9000 --agent 1

# Gracefully shut down the VM
qm shutdown 9000

# Wait for VM to fully stop before proceeding
while [ "$(qm status 9000 | awk '{print $2}')" != "stopped" ]; do
    sleep 2
done

# Convert the stopped VM into an immutable template
qm template 9000