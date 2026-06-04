# Network Layer — `infra/terraform/modules/vpc`

Infrastructure as Code for the VOD Streaming Platform network layer.
Provisions a production-grade, three-tier AWS VPC with cost-optimised routing via VPC endpoints.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Three-Tier Subnet Design](#three-tier-subnet-design)
- [Routing Strategy](#routing-strategy)
- [VPC Endpoints — Cost Optimisation](#vpc-endpoints--cost-optimisation)
- [Security Group Design](#security-group-design)
- [NAT Gateway Strategy](#nat-gateway-strategy)
- [Module Inputs](#module-inputs)
- [Module Outputs](#module-outputs)
- [Usage](#usage)
- [Environment Differences](#environment-differences)

---

## Architecture Overview

```
Internet
    │
    ▼
[CloudFront + WAF]
    │
    ▼
┌─────────────────────────────────────────────────────┐
│  VPC  (e.g. 10.0.0.0/16)                           │
│                                                     │
│  ┌──────────────────────────────────────────────┐  │
│  │  Public Tier  (x3 AZs)                       │  │
│  │  ALB  │  NAT Gateway  │  Bastion (future)    │  │
│  └──────────────────────────────────────────────┘  │
│                      │                             │
│  ┌──────────────────────────────────────────────┐  │
│  │  App Tier  (x3 AZs)  — private               │  │
│  │  ECS Tasks  │  VPC Endpoints                 │  │
│  └──────────────────────────────────────────────┘  │
│                      │                             │
│  ┌──────────────────────────────────────────────┐  │
│  │  Data Tier  (x3 AZs)  — fully isolated       │  │
│  │  RDS PostgreSQL  │  ElastiCache Redis        │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

All subnets are spread across three Availability Zones for resilience.
The data tier has no route to the internet — access is permitted only
from the app tier via security group rules.

---

## Three-Tier Subnet Design

The VPC is divided into three tiers, each with a distinct trust level and
routing posture. This is a standard pattern for production web applications
and separates concerns at the network level rather than relying solely on
security group rules.

### Public Tier

| Property | Value |
|----------|-------|
| CIDR pattern | `cidrsubnet(vpc_cidr, 8, index)` — e.g. `10.0.0.0/24`, `10.0.1.0/24`, `10.0.2.0/24` |
| Route | `0.0.0.0/0 → Internet Gateway` |
| Resources | ALB, NAT Gateway, Elastic IP |
| `map_public_ip_on_launch` | `true` |

The public tier is the only tier that has a direct route to the internet.
The Application Load Balancer sits here to accept inbound traffic on ports
80 and 443. The NAT Gateway also lives here so private tier resources can
initiate outbound connections (e.g. pulling from ECR, calling Stripe) without
being directly reachable from the internet.

**Why not put ECS tasks here?** Running application containers in a public
subnet is an unnecessary exposure. If a container is compromised, an attacker
would have a public IP and direct internet access. Placing tasks in the
private app tier means any compromise is contained within the VPC.

### App Tier (Private)

| Property | Value |
|----------|-------|
| CIDR pattern | `cidrsubnet(vpc_cidr, 6, index + 4)` — larger blocks for task density |
| Route | `0.0.0.0/0 → NAT Gateway` |
| Resources | ECS tasks, VPC endpoint ENIs |
| `map_public_ip_on_launch` | `false` |

ECS tasks run here. The `/6` offset gives larger subnets than the public
tier — important because ECS assigns an ENI per task, so each running
container consumes one IP address from the subnet pool.

Outbound internet access (for pulling images, calling external APIs) goes
via the NAT Gateway in the public tier. Calls to AWS services go via VPC
endpoints instead, bypassing NAT entirely — see the cost section below.

### Data Tier (Private — Isolated)

| Property | Value |
|----------|-------|
| CIDR pattern | `cidrsubnet(vpc_cidr, 8, index + 100)` |
| Route | None — no internet route |
| Resources | RDS PostgreSQL, ElastiCache Redis |
| `map_public_ip_on_launch` | `false` |

The data tier has **no outbound internet route**. The route table is
intentionally empty beyond local VPC routing. RDS and ElastiCache are managed
services — they never need to initiate outbound connections. Removing the
route is defence-in-depth: even if a security group rule were misconfigured,
there is no network path for data to leave this tier to the internet.

Access from the app tier is controlled exclusively via security group rules
on specific ports (5432 for PostgreSQL, 6379 for Redis).

---

## Routing Strategy

Three separate route tables enforce the tier boundaries at the network level.

```
Public RT           → 0.0.0.0/0  via  Internet Gateway
Private App RT      → 0.0.0.0/0  via  NAT Gateway
                    → AWS services via VPC Endpoint (automatic, prefix list)
Private Data RT     → local only  (no default route)
```

The private app route table gains automatic S3 routing entries when the S3
Gateway endpoint is attached — AWS inserts a managed prefix list route that
points S3 traffic at the endpoint instead of the NAT Gateway. No manual
route entry is needed.

---

## VPC Endpoints — Cost Optimisation

One of the most overlooked cost levers in AWS networking is NAT Gateway
data processing charges. NAT Gateway costs **$0.045 per GB processed** in
`eu-west-2`. For a streaming platform, two traffic patterns hit this hard:

- **ECR image pulls** — every ECS deployment pulls Docker layers through NAT
  without an endpoint. A single 500 MB image across 10 deploys/day = ~$6/day
  just in NAT processing on one service.
- **CloudWatch Logs** — every log line from every container passes through
  NAT. At scale this becomes a meaningful cost.

### Endpoints Provisioned

| Endpoint | Type | Cost | Purpose |
|----------|------|------|---------|
| `com.amazonaws.{region}.s3` | Gateway | **Free** | S3 asset reads/writes, ECR layer storage |
| `com.amazonaws.{region}.ecr.api` | Interface | ~$7.30/mo | ECR authentication + image metadata |
| `com.amazonaws.{region}.ecr.dkr` | Interface | ~$7.30/mo | ECR image layer pulls |
| `com.amazonaws.{region}.logs` | Interface | ~$7.30/mo | CloudWatch Logs from ECS tasks |
| `com.amazonaws.{region}.secretsmanager` | Interface | ~$7.30/mo | Secrets at container startup |

**Gateway vs Interface — the difference:**

- **Gateway endpoints** (S3, DynamoDB) are free. They work by injecting a
  route into your route table that points to an AWS-managed prefix list.
  No ENI is created, no hourly charge.
- **Interface endpoints** create an ENI in your subnet with a private IP.
  They cost ~$0.01/hr per AZ plus $0.01/GB processed. For a dev environment
  running in one AZ they cost roughly $7.30/month each — still far cheaper
  than the NAT processing they displace on high-traffic paths like ECR.

### Why not an endpoint for every AWS service?

Interface endpoints have a per-hour cost per AZ. For services called
infrequently (e.g. ACM, Route 53, IAM) the NAT processing cost is negligible
and does not justify an additional endpoint. Only high-throughput paths
(ECR pulls, log shipping, secrets at startup) earn their own endpoint.

---

## Security Group Design

Security groups are defined in `modules/sec_grps` and follow two principles:

**Principle 1 — SG-to-SG references over CIDR ranges**

Rather than allowing traffic from a CIDR block (e.g. `10.0.4.0/22`), rules
reference the source security group ID directly. This means the rule tracks
the *identity* of the resource, not its IP address — important when ECS
assigns IPs dynamically per task.

**Principle 2 — Shells first, rules separate**

Because the ALB SG and ECS SG reference each other, defining rules inline
creates a circular dependency Terraform cannot resolve. All SGs are created
as empty shells first, then rules are attached using the standalone
`aws_vpc_security_group_ingress_rule` and `aws_vpc_security_group_egress_rule`
resources. This eliminates the cycle at the graph level.

```
Internet ──[443/80]──▶ ALB SG ──[container_port]──▶ ECS SG ──[5432]──▶ RDS SG
                                                          │──[6379]──▶ Redis SG
                                                          │──[443]───▶ VPCE SG
                                                          └──[443]───▶ 0.0.0.0/0 (NAT → internet)
```

RDS and Redis security groups have **no egress rules** — managed services
never initiate outbound connections.

---

## NAT Gateway Strategy

| Environment | NAT Gateways | Rationale |
|-------------|-------------|-----------|
| `dev` | 1 (in `public[0]`) | Cost saving — ~$32/mo vs ~$96/mo for 3 |
| `prod` | 3 (one per AZ) | AZ resilience — if `eu-west-2a` fails, tasks in `2b` and `2c` retain outbound access |

Controlled via the `single_nat_gateway` variable. The private app route
table count mirrors the NAT Gateway count so each AZ's tasks route to the
local NAT in production.

---

## Module Inputs

| Variable | Type | Description |
|----------|------|-------------|
| `vpc_cidr` | `string` | CIDR block for the VPC e.g. `10.0.0.0/16` |
| `project_name` | `string` | Used in all resource Name tags |
| `environment` | `string` | `dev` or `prod` |
| `aws_region` | `string` | AWS region — used in VPC endpoint service names |
| `cluster_name` | `string` | EKS cluster name for subnet tags (future use) |
| `single_nat_gateway` | `bool` | `true` for dev (1 NAT), `false` for prod (3 NAT) |
| `vpc_endpoint_sg_id` | `string` | Security group ID for Interface VPC endpoints |

---

## Module Outputs

| Output | Description |
|--------|-------------|
| `vpc_id` | VPC ID — passed to all other modules |
| `public_subnet_ids` | List of 3 public subnet IDs — used by ALB module |
| `private_app_subnet_ids` | List of 3 private app subnet IDs — used by ECS module |
| `private_data_subnet_ids` | List of 3 private data subnet IDs — used by RDS and Redis modules |
| `nat_gateway_ids` | NAT Gateway IDs |
| `vpc_cidr_block` | Resolved VPC CIDR — used by security group modules |

---

## Usage

```hcl
module "vpc" {
  source = "../../modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  aws_region         = var.aws_region
  vpc_cidr           = "10.0.0.0/16"
  single_nat_gateway = true   # set false for prod
  cluster_name       = "vod-platform-dev"
  vpc_endpoint_sg_id = module.sec_grps.vpc_endpoints_sg_id
}
```

---

## Environment Differences

| Configuration | Dev | Prod |
|---------------|-----|------|
| NAT Gateways | 1 | 3 (one per AZ) |
| VPC endpoints | S3, ECR ×2, Logs, Secrets | S3, ECR ×2, Logs, Secrets, STS, SSM |
| Subnet CIDR size | `/24` public, `/22` app | `/24` public, `/22` app |
| Multi-AZ RDS | No (single-AZ) | Yes (Multi-AZ standby) |
| ElastiCache nodes | 1 | 3 (cluster mode) |

---

*Managed by Terraform — do not modify AWS resources directly.*
*See `environments/dev/terraform.tfvars` for environment-specific values.*