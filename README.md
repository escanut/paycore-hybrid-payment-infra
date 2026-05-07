# PayCore NG

A hybrid payment platform infrastructure that simulates B2B payment processing middleware. It connects an on-premises Proxmox VM to AWS over a self-managed WireGuard VPN, with a serverless transaction pipeline on the AWS side. The design follows PCI DSS-aligned principles around network segmentation, secrets management, and audit logging.

---

## How It Works

The on-premises VM handles the application layer. AWS handles the transaction pipeline and provides a highly available VPN endpoint. The two sides communicate exclusively over an encrypted WireGuard tunnel. Nothing in the transaction path touches the public internet directly.

---

## On-Premises

The on-prem environment runs on a Proxmox VE instance hosted inside VMware on a Windows workstation. The network adapter is set to bridged mode and Hyper-V is disabled so Proxmox gets direct hardware access. The development workspace is WSL2 Ubuntu on the same machine.

The deployed VM runs the full application stack:

- **Frontend** -- Static HTML/CSS/JS, used for demonstration
- **Backend** -- Python FastAPI
- **Database** -- PostgreSQL
- **Secrets** -- HashiCorp Vault
- **Runtime** -- FastAPI and PostgreSQL run as Docker containers via Docker Compose

The VM dials out to AWS over WireGuard on UDP 51820 and forwards transactions to an SQS queue.

---

## AWS

All AWS infrastructure is provisioned with Terraform using a modules-based layout.

**VPN Layer**

Two `t3.micro` EC2 instances (Ubuntu 22.04 LTS) sit in separate Availability Zones inside a single VPC. Each is a WireGuard peer to the on-prem VM. One Elastic IP is associated with the primary instance and is the address the on-prem peer targets.

If the primary instance fails two consecutive EC2 status checks (one check per minute), a CloudWatch alarm fires a Lambda function. The Lambda first confirms the primary is genuinely down before acting. If it is, it moves the Elastic IP to the standby instance. The on-prem peer keeps connecting to the same address with no config change required.

**Transaction Pipeline** (planned)

The on-prem backend publishes transactions to SQS. A Lambda function runs a fraud check on each message. Clean transactions are written to DynamoDB. Flagged transactions trigger an SNS notification to a configured email list. All raw transaction records are archived to S3 for audit purposes.

**Network Controls**

Traffic to S3 goes through a VPC Gateway Endpoint, keeping it off the public internet. CloudWatch Logs uses a VPC Interface Endpoint for internal delivery. A DynamoDB endpoint is planned once that service is built out.

---

## Repository Structure

```
paycore/
├── aws-infra/
│   ├── dev/                        # Dev environment entrypoint
│   │   ├── main.tf
│   │   ├── backend.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── outputs.tf
│   └── modules/
│       └── VPN_Networking/         # VPC, subnets, SGs, EIP, EC2s, Lambda failover
│           ├── network.tf
│           ├── variables.tf
│           ├── outputs.tf
│           └── scripts/
│               ├── wg_bootstrap.sh # EC2 user-data: WireGuard install and config
│               └── failover.py     # Lambda: moves EIP to standby on primary failure
├── on-prem/
│   ├── deploy.sh                   # Clones template VM and boots it on Proxmox
│   └── ansible/
│       ├── configure.yml           # Configures WireGuard on the deployed VM
│       ├── inventory.ini
│       ├── wg0.conf.j2             # Jinja2 template for wg0.conf
│       └── vars/
│           └── wg_vars.yml         # WireGuard keys and peer addresses
└── template/
    ├── stage1.sh                   # Creates Proxmox VM from Ubuntu cloud image
    ├── stage2.sh                   # Shuts VM down and converts it to a template
    └── ansible/
        ├── provision-base.yml      # Installs Docker, WireGuard tools, hardens SSH
        └── inventory.ini
```

---

## Golden Image Pipeline

The base VM is built from the official Ubuntu 22.04 LTS cloud image (`jammy-server-cloudimg-amd64`). The process runs in three steps.

**Stage 1 -- `template/stage1.sh`**
Runs inside the Proxmox shell. Creates a VM with VMID 9000, imports the cloud disk, resizes it to 4G, and configures cloud-init with a static IP, SSH key, and DNS resolvers. Starts the VM when done.

**Ansible -- `template/ansible/provision-base.yml`**
Connects to the running VM over SSH and installs: WireGuard tools, Docker Engine with the Compose plugin and Buildx, the QEMU guest agent, Python 3 with the Docker SDK, and standard system utilities. SSH password authentication is disabled.

**Stage 2 -- `template/stage2.sh`**
Enables the QEMU guest agent, shuts the VM down gracefully, and converts it to a Proxmox template. Every subsequent VM is cloned from this template, so the provisioning step only runs once.

---

## VM Deployment

`on-prem/deploy.sh` clones the template (VMID 9000) into a new VM (VMID 100), applies cloud-init overrides for user, SSH key, and static IP, starts the VM, and polls SSH on a 5-second interval until the VM is reachable or a 120-second timeout is hit.

`on-prem/ansible/configure.yml` then connects to the live VM and configures WireGuard: ensures the package is installed, renders `wg0.conf` from the Jinja2 template using values from `wg_vars.yml`, enables and starts the `wg-quick@wg0` systemd service, and runs `wg show` to confirm the tunnel is up.

---

## Infrastructure as Code

Terraform `>= 1.10` is required. The codebase uses the native S3 state locking syntax introduced in that version, but the remote backend is not active yet. State is stored locally in `aws-infra/dev/dev.tfstate`. Migration to S3 with native locking is planned once the pipeline layer is built.

The `dev/` environment passes VPC CIDR, region, per-EC2 WireGuard private keys, and the on-prem public key into the `VPN_Networking` module. All resources inherit `Environment`, `Project`, `Owner`, and `ManagedBy` tags from the provider-level `default_tags` block.

---

## Current Status

This project is in active development.

**Complete**

- Golden image pipeline: Proxmox VM template built from Ubuntu Jammy cloud image using `stage1.sh`, Ansible provisioning, and `stage2.sh`
- VM provisioning: `deploy.sh` clones the template and boots the VM; Ansible configures WireGuard on the live instance
- AWS `VPN_Networking` module: VPC, public subnets across two AZs, route tables, security groups, Elastic IP, two WireGuard EC2s, Lambda failover function, CloudWatch alarm, VPC endpoints for S3 and CloudWatch Logs
- WireGuard tunnel: on-prem VM is peered with the AWS EC2 over UDP 51820 and the EIP failover path is implemented

**Not yet built**

- FastAPI backend, PostgreSQL, and HashiCorp Vault on the on-prem VM
- Frontend static app
- SQS queue, fraud-check Lambda, DynamoDB, and SNS alerting
- S3 raw transaction archival
- Terraform remote backend with S3 native state locking
- VPC endpoint for DynamoDB

---

## Prerequisites

- Proxmox VE with shell access
- Ubuntu Jammy cloud image downloaded to the Proxmox host
- AWS CLI configured with sufficient IAM permissions
- Terraform >= 1.10
- Ansible >= 2.12
- WireGuard key pairs generated for the on-prem VM and both EC2 instances