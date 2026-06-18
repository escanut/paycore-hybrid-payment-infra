# PayCore Hybrid B2B Payment Processing Middleware

A production-pattern hybrid cloud payment middleware. FastAPI runs on an on-premises Proxmox VM with no public IP. AWS Lambda processes transactions asynchronously and PATCHes status back to the VM through a WireGuard VPN tunnel. Merchants never interact with AWS directly.


This is not a tutorial scaffold. The infrastructure, secrets management, networking, deployment pipeline, financial data model, and observability stack are all built to production patterns.

---

## What This Is

PayCore accepts payment requests over HTTPS, tokenises the card number on arrival, writes the transaction to PostgreSQL, queues it to SQS (Simple Queue Service), and returns a queued status immediately. A Lambda function picks up the SQS message, archives the raw payload to S3 before any decision runs, applies fraud detection rules, and PATCHes the transaction status back to the on-premises API over the VPN.

The VM has no public IP. Lambda never touches the public internet to reach it. The only path in is the WireGuard tunnel through the EC2 node acting as the VPN gateway.

## Architecture


![Architecture Diagram](./Architecture.png)


### Network topology

| Node | WireGuard IP | Role |
|---|---|---|
| On-prem Proxmox VM | `10.10.0.1` | Runs Docker stack, initiates VPN tunnel |
| AWS EC2 node 0 | `10.10.0.2` | Primary WireGuard gateway, Elastic IP attached |

Lambda reaches the on-prem API at http://10.10.0.1 through the VPC route table (10.10.0.0/24 → EC2 ENI). The API port binds exclusively to the WireGuard interface. It is not reachable from the public internet.

A note on the networking decision

An earlier version of this project ran two EC2 nodes with a failover Lambda that moved the Elastic IP to a standby instance on primary failure. I removed it.

The gap was in the route table. The failover Lambda moved the Elastic IP but never updated the VPC route table entry, which stayed pointing at EC2 node 0's ENI. Traffic from Lambda would still hit the old interface after failover. That is not high availability, it is a more complicated single point of failure.

For a homelab simulation, a single EC2 gateway is the honest setup. At real enterprise scale, the right answer is AWS Site-to-Site VPN or AWS Transit Gateway with redundant tunnels. Both handle route propagation automatically. The operational cost of managing WireGuard HA yourself, patching, monitoring tunnel health, scripting route updates, testing failover paths, does not justify it when managed services exist for exactly this problem.

---

## What This Project Demonstrates

**Hybrid cloud networking** - WireGuard VPN bridging an on-premises VM to a VPC, with EC2 acting only as a VPN gateway. No application logic runs in EC2.

**Layered security**
- PAN (Primary Account Number) tokenisation - real card numbers never persist to the database or message queue
- JWT authentication for merchant API access
- API key isolation for Lambda-to-API callbacks (`X-API-Key` separate from JWT)
- AWS KMS (Key Management Service) encrypting both S3 objects and Secrets Manager entries
- `bcrypt_sha256` password hashing, bypassing bcrypt's 72-byte truncation vulnerability

**Serverless fraud detection** - Lambda validates every transaction, archives to S3 before the fraud decision runs, applies threshold rules, and PATCHes status back to the on-prem API
 
**Observability stack** - Prometheus scraping FastAPI, PostgreSQL, host metrics, and container metrics; Grafana dashboards and datasources provisioned as code; four alerting rules defined
 
**Infrastructure as code end-to-end** - Terraform manages all AWS resources with a modular layout; Ansible handles VM provisioning and application deployment from a single command
 

---

## Tech Stack

| Layer | Technology |
|---|---|
| API | FastAPI 0.111, Python 3.12, uvicorn |
| Database | PostgreSQL 17 (Docker) |
| ORM + Migrations | SQLAlchemy 2.0, Alembic |
| Auth | python-jose (JWT, HS256), passlib bcrypt_sha256 |
| Message queue | AWS SQS with DLQ (Dead Letter Queue) |
| Event processing | AWS Lambda (Python 3.12) |
| Alerting | AWS SNS (Simple Notification Service) |
| Audit storage | AWS S3 + SSE-KMS |
| Secrets | AWS Secrets Manager + KMS CMK |
| VPN | WireGuard (on-prem VM to AWS EC2) |
| Reverse proxy | nginx |
| Tunnel | Cloudflare Tunnel (cloudflared) |
| Containerisation | Docker Compose |
| Infrastructure | Terraform 1.14, AWS provider 6.22 |
| Configuration | Ansible, Ansible Vault |
| Hypervisor | Proxmox VE |
| Metrics collection | Prometheus 2.52 |
| Dashboards | Grafana 11.0 |
| Host metrics | node-exporter 1.8.1 |
| Container metrics | cAdvisor 0.49.1 |
| Database metrics | postgres-exporter 0.15.0 |
 
---

## Repository Structure

```
paycore-hybrid-payment-infra/
├── app/
│   ├── backend/
│   │   ├── routers/          # payments, transactions, auth, health, accounts
│   │   ├── services/         # auth_service, tokeniser, ledger_service, dependencies
│   │   ├── db_models/        # user, transaction, account, ledger, idempotency
│   │   ├── response_schemas/ # Pydantic request/response models
│   │   ├── alembic/          # migration versions + env.py
│   │   ├── main.py           # FastAPI app, CORS, Prometheus instrumentator, router registration
│   │   ├── config.py         # Pydantic BaseSettings, env var loading
│   │   ├── database.py       # engine, session factory, Base
│   │   └── logger.py         # JSON structured logging
│   ├── nginx/conf.d/         # nginx reverse proxy config (API + Grafana)
│   ├── monitoring/
│   │   ├── prometheus/       # prometheus.yml scrape config, alerts.yml
│   │   └── grafana/
│   │       └── provisioning/ # datasources + dashboard JSON, provisioned as code
│   ├── docker-compose.yml    # db, api, nginx, cloudflared + full monitoring stack
│   └── setup.sh              # fetch secrets + bring up stack
│
├── aws-infra/
│   ├── dev/                  # environment entry point (main.tf, variables.tf)
│   └── modules/
│       ├── compute/          # Lambda validator, IAM role, Secrets Manager
│       ├── kms/              # KMS key + alias
│       ├── messaging/        # SQS queue, DLQ, SNS topic
│       ├── storage/          # S3 bucket, versioning, KMS encryption
│       └── vpn_networking/   # VPC, subnet, EC2 WireGuard node, EIP
│
├── on-prem/
│   ├── ansible/
│   │   ├── configure.yml     # WireGuard setup on on-prem VM
│   │   ├── deploy_app.yml    # git pull, secrets fetch, docker compose up
│   │   ├── wg0.conf.j2       # Jinja2 WireGuard config template
│   │   └── inventory.ini     # Ansible targets
│   └── cloner.sh             # Clone Proxmox template to working VM
│
└── template/
    ├── stage1.sh             # Create base VM from Ubuntu cloud image
    ├── stage2.sh             # Shutdown + convert to immutable template
    └── ansible/
        └── provision-base.yml  # Docker, WireGuard tools, SSH hardening
```

---
## Data Model
 
Four database tables:
 
**`users`** - merchant accounts. Username is the primary key, `merchant_id` is a unique prefixed UUID (`Merchant-XXXXXXXX`) used across all downstream tables.
 
**`transaction`** - one row per payment. Stores the token (UUID), masked PAN, amount, currency, status (`queued` → `processed` or `flagged`), and merchant reference.
 
**`accounts`** - per-merchant accounts scoped to a currency. A merchant must create an NGN account before submitting NGN payments. Currency isolation enforced at the data layer.
 
**`ledger_entry`** - double-entry ledger. Every payment creates a credit entry against the merchant's account. Balance is computed by summing entries:
 
```python
def get_balance(db: Session, account_id: str):
    rows = db.execute(
        select(LedgerEntry).where(LedgerEntry.account_id == account_id)
    ).scalars().all()
 
    balance = 0.0
    for row in rows:
        if row.movement_direction == LedgerMovement.credit:
            balance += row.amount
        else:
            balance -= row.amount
 
    return balance
```
 
**`idempotency_keys`** - stores the serialised response body against a client-supplied `Idempotency-Key` header. If the same key arrives twice from the same merchant, the stored response returns without touching the database a second time. Prevents duplicate charges on network retries.
 

---

## Monitoring Stack
 
Five services added to the Docker Compose stack alongside the application:
 
**prometheus-fastapi-instrumentator** - instruments FastAPI at startup, exposes `/metrics`. Prometheus scrapes it every 10 seconds. Gives request count, latency histograms, and error rates per endpoint.
 
**node-exporter** - host-level metrics. Runs with `pid: host` and bind-mounts `/proc`, `/sys`, and `/` read-only to see the host process tree from inside the container.
 
**cAdvisor** - per-container resource usage. Reads directly from the Docker daemon. Requires `privileged: true`.
 
**postgres-exporter** - PostgreSQL internals. Connection counts, query duration, table sizes.
 
**Grafana** - provisioned entirely through code. Datasource pointing at Prometheus and the dashboard JSON are mounted via Docker volumes at startup. No manual UI setup required on redeploy.
 
Four alerts defined in `alerts.yml`:
 
| Alert | Condition | Severity |
|---|---|---|
| APIDown | `up{job="fastapi"} == 0` for 1m | critical |
| PostgreSQLDown | `up{job="postgres"} == 0` for 1m | critical |
| HostHighCPU | CPU above 85% for 5m | warning |
| HostLowDisk | Root filesystem below 15% free for 5m | critical |
 
Alertmanager is not deployed in the dev setup. Alerts are defined but have no delivery target. In production this routes to PagerDuty or an SNS topic.
 
---

## Local Environment

 
```
Windows 11 Host
└── VMware Workstation Pro
    ├── Ubuntu 22.04 (control plane - NAT)
    │     Terraform, Ansible, AWS CLI, Docker
    │     All commands in this README run here
    │
    └── Proxmox VE (NAT)
          └── paycore-on-prem VM  (192.168.123.10)
                Docker Compose stack - FastAPI, PostgreSQL, nginx, cloudflared,
                Prometheus, Grafana, node-exporter, cAdvisor, postgres-exporter
```

The on-prem VM has no public IP. Cloudflare Tunnel handles inbound public traffic. AWS Lambda reaches the VM through the WireGuard VPN - the EC2 nodes act as the VPN gateway.

---

## Prerequisites

**On your control machine (Ubuntu 22.04 in this setup):**

- AWS CLI v2, configured with credentials that have permissions to provision the resources in `aws-infra/`
- Terraform `~> 1.14`
- Ansible (`ppa:ansible/ansible`, not the snap)
- `jq`
- WireGuard tools (`wireguard-tools`) for key generation

**AWS account:**
- SQS, Lambda, S3, SNS, KMS, Secrets Manager, EC2, VPC - all used

**Cloudflare:**
- A domain managed in Cloudflare
- A Zero Trust tunnel token (free tier works)

---

## Deployment Overview


**1. Build the Proxmox golden image**
```bash
# Run inside Proxmox shell
bash template/stage1.sh
ansible-playbook -i template/ansible/inventory.ini template/ansible/provision-base.yml
bash template/stage2.sh
```

**2. Clone the template to a working VM**
```bash
# Run inside Proxmox shell
bash on-prem/cloner.sh
```

**3. Generate WireGuard key pairs**
```bash
# Run once per node (on-prem VM + EC2)
wg genkey | tee privatekey | wg pubkey > publickey
```

**4. Provision AWS infrastructure**
```bash
cd aws-infra/dev
terraform init
terraform apply -var-file="dev.tfvars"
```

**5. Configure WireGuard and deploy the application**
```bash
bash on-prem/ansible/run.sh
```

This runs `configure.yml` (WireGuard setup) then `deploy_app.yml` (secrets fetch, git pull, docker compose up, health check). Does not exit clean until `http://10.10.0.1:80/api/health` returns `200`.


---

## Testing

Once deployed and `https://your-domain.xyz/api/health` returns `200`:

### Register and authenticate
 
```bash
# Register
curl -X POST https://your-domain.xyz/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username": "testmerchant", "password": "securepassword123"}'
 
# Expected: {"message": "User registered successfully", "merchant_id": "Merchant-XXXXXXXX"}
 
# Login
curl -X POST https://your-domain.xyz/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "testmerchant", "password": "securepassword123"}'
 
# Expected: {"access_token": "<jwt>", "token_type": "bearer"}
```
 
### Create a merchant account
 
A currency account is required before submitting payments in that currency.
 
```bash
curl -X POST "https://your-domain.xyz/api/accounts/?currency=NGN" \
  -H "Authorization: Bearer <token>"
 
# Expected: {"id": "<uuid>", "merchant_id": "Merchant-XXXXXXXX", "currency": "NGN", ...}
```
 
### Submit a payment
 
```bash
curl -X POST https://your-domain.xyz/api/payments/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -H "Idempotency-Key: unique-key-001" \
  -d '{"pan": "4111111111111111", "amount": 5000, "currency": "NGN"}'
 
# Expected: {"status": "queued", "token": "<uuid>", "masked_pan": "**** **** **** 1111", ...}
```
 
Poll the transaction after a few seconds:
 
```bash
curl https://your-domain.xyz/api/transactions/<token> \
  -H "Authorization: Bearer <token>"
 
# Expected: "status": "processed"
```
 
### Check your balance
 
```bash
curl https://your-domain.xyz/api/accounts/balance/NGN \
  -H "Authorization: Bearer <token>"
 
# Expected: {"account_id": "<uuid>", "currency": "NGN", "balance": 5000.0}
```
 
### Trigger fraud detection
 
```bash
curl -X POST https://your-domain.xyz/api/payments/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"pan": "4111111111111111", "amount": 15000000, "currency": "NGN"}'
```
 
Expected: transaction status becomes `flagged`, SNS email alert fires, raw payload archived to S3.
 
```bash
aws s3 ls s3://<your-bucket>/transactions/
aws s3 cp s3://<your-bucket>/transactions/<token>.json -
```

### Fraud rule reference

| Rule | Condition | Result |
|---|---|---|
| High-value transaction | `amount > 10,000,000 NGN` | `flagged` + SNS alert |
| Unsupported currency | Not in `[NGN, USD, EUR]` | `flagged` + SNS alert |
| Everything else | Passes both checks | `processed` |
 
---

## Adapting This for Your Own Project

The core pattern - on-premises app server + WireGuard VPN to AWS + Lambda async processing - is reusable. Replace these values:
 
| Component | This project | Replace with |
|---|---|---|
| WireGuard subnet | `10.10.0.0/24` | Any private range |
| On-prem VM IP | `192.168.123.10` | Your server LAN IP |
| SQS / SNS / S3 / KMS names | `paycore-*` | Your project name |
| Secrets Manager prefix | `paycore/internal/*` | Your project prefix |
| CORS origin | `victorojeje.xyz` | Your domain |
| DB name | `paycore` | Your project name |
 
The Alembic migration pattern, JWT dependency injection, Lambda callback auth, Docker Compose dependency chain, ledger service, idempotency handling, and Prometheus scrape config are all portable as-is.

---

## Known Limitations
These are intentional trade-offs for a dev/homelab environment.
 
**Local Terraform state** - `dev.tfstate` is on disk. Production uses an S3 backend with DynamoDB state locking.
 
**Single WireGuard gateway, no automated failover** - one EC2 node, no standby. See the networking note above for why the dual-node setup was removed and what the production-grade alternative looks like.
 
**Alertmanager not deployed** - alerts are defined in `alerts.yml` but have no delivery target in dev. Production routes to PagerDuty or SNS.
 
**S3 Object Lock disabled** - `force_destroy = true` for fast teardown. Production uses `COMPLIANCE` mode with a minimum 365-day retention period, consistent with PCI DSS Requirement 10.7.
 
**Secrets Manager `recovery_window_in_days = 0`** - immediate deletion enabled for fast iteration. Production minimum is 7 days.
 
**No settlement or reconciliation layer** - PayCore validates and processes payment events and tracks ledger movements. It does not maintain settlement records, run reconciliation jobs, or move funds. A production payment platform needs double-entry bookkeeping at a deeper level, a reconciliation engine, and settlement logic on top of this.
 
**Single-region** - no cross-region S3 replication or multi-region SQS setup.

---

## Contact

**Victor Ogechukwu Ojeje**
Cloud & DevOps Engineer

- LinkedIn: https://www.linkedin.com/in/victorojeje/
- Blog: https://dev.to/escanut
- Email: ojejevictor@gmail.com 