#!/bin/bash
set -euxo pipefail


# We install wireGuard
apt-get update -y
apt-get install -y wireguard


# Generate unique keypair for this instance
wg genkey | tee /etc/wireguard/private.key | wg pubkey > /etc/wireguard/public.key
chmod 600 /etc/wireguard/private.key

# Create the wg0.conf file
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = ${wg_interface_address}
ListenPort = 51820
PrivateKey = ${wg_private_key}

[Peer]
PublicKey = ${wg_peer_public_key}
AllowedIPS = ${wg_peer_allowed_ips}
EOF

chmod 600 /etc/wireguard/wg0.conf

# sysctl for kernel level tuning
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# systemctl for services and apps
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0



