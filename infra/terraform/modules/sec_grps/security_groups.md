# Security Group Module — `infra/terraform/modules/sec_grps`

Provisions all AWS Security Groups and associated ingress/egress rules for the
VOD Streaming Platform. It enforces least-privilege principles, SG-to-SG traffic flow between
every tier of the application stack.

---

## Table of Contents

- [Security Groups Provisioned](#security-groups-provisioned)
- [Traffic Flow Matrix](#traffic-flow-matrix)
- [Design Principles](#design-principles)
- [Circular Dependency — Problem and Solution](#circular-dependency--problem-and-solution)
- [Why No Egress on RDS and Redis](#why-no-egress-on-rds-and-redis)
- [Module Inputs](#module-inputs)
- [Module Outputs](#module-outputs)
- [Usage](#usage)
- [Related Modules](#related-modules)

---

## Security Groups Provisioned

| Resource | Name pattern | Purpose |
|----------|-------------|---------|
| `aws_security_group.alb_sg` | `{project}-{env}-alb-sg` | Application Load Balancer — internet-facing |
| `aws_security_group.ecs_service_sg` | `{project}-{env}-ecs-service-sg` | ECS task network interface |
| `aws_security_group.rds_sg` | `{project}-{env}-rds-sg` | RDS PostgreSQL in data tier |
| `aws_security_group.redis_sg` | `{project}-{env}-redis-sg` | ElastiCache Redis in data tier |
| `aws_security_group.vpc_endpoints_sg` | `{project}-{env}-vpce-sg` | Interface VPC endpoint ENIs |

All five SGs are created as **empty shells** with no inline rules. Rules are
attached via separate `aws_vpc_security_group_ingress_rule` and
`aws_vpc_security_group_egress_rule` resources. See
[Circular Dependency — Problem and Solution](#circular-dependency--problem-and-solution)
for the reasoning behind this pattern.

---

## Traffic Flow Matrix

Complete reference of every rule provisioned by this module.

### Ingress Rules

| Resource | Rule name | Source | Port | Protocol | Description |
|----------|-----------|--------|------|----------|-------------|
| `alb_sg` | `alb_http` | `0.0.0.0/0` | 80 | TCP | HTTP — redirects to HTTPS via ALB listener |
| `alb_sg` | `alb_https` | `0.0.0.0/0` | 443 | TCP | HTTPS from internet |
| `ecs_service_sg` | `ecs_from_alb` | `alb_sg` | `var.container_port` | TCP | Traffic from ALB only |
| `rds_sg` | `rds_from_ecs` | `ecs_service_sg` | 5432 | TCP | PostgreSQL from ECS tasks only |
| `redis_sg` | `redis_from_ecs` | `ecs_service_sg` | 6379 | TCP | Redis from ECS tasks only |
| `vpc_endpoints_sg` | `vpce_from_ecs` | `ecs_service_sg` | 443 | TCP | HTTPS from ECS tasks to AWS service endpoints |

### Egress Rules

| Resource | Rule name | Destination | Port | Protocol | Description |
|----------|-----------|-------------|------|----------|-------------|
| `alb_sg` | `alb_to_ecs` | `ecs_service_sg` | `var.container_port` | TCP | Forward to ECS tasks only |
| `ecs_service_sg` | `ecs_to_vpce` | `vpc_endpoints_sg` | 443 | TCP | ECR pulls, CloudWatch Logs, Secrets Manager |
| `ecs_service_sg` | `ecs_to_rds` | `rds_sg` | 5432 | TCP | PostgreSQL connections |
| `ecs_service_sg` | `ecs_to_redis` | `redis_sg` | 6379 | TCP | Redis connections |
| `ecs_service_sg` | `ecs_to_internet` | `0.0.0.0/0` | 443 | TCP | External APIs via NAT (Stripe, SendGrid) |
| `rds_sg` | _(none)_ | — | — | — | No egress — managed service |
| `redis_sg` | _(none)_ | — | — | — | No egress — managed service |
| `vpc_endpoints_sg` | _(none)_ | — | — | — | No egress — AWS-managed ENIs |

---

## Design Principles

### 1 — SG-to-SG references over CIDR ranges

Every rule that restricts access between internal resources uses a
`referenced_security_group_id` rather than a `cidr_ipv4` block.

**Why this matters for ECS specifically:** Fargate tasks are assigned a new
private IP on every deployment. A CIDR-based rule would need to cover the
entire app subnet (`10.0.16.0/22`) to remain valid across deployments —
which is far broader than necessary. By referencing the ECS security group ID
directly means the rule tracks the *identity* of the resource regardless of
what IP it holds at any given time.

```
# ❌ CIDR-based - allows anything in the entire subnet, not just ECS tasks
ingress {
  from_port   = 5432
  cidr_blocks = ["10.0.16.0/22"]
}

# ✅ SG reference - allows only resources attached to ecs_service_sg
resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs" {
  referenced_security_group_id = aws_security_group.ecs_service_sg.id
  from_port                    = 5432
}
```

### 2 — Explicit egress over open egress

The default AWS behaviour on a new security group is to allow all outbound
traffic (`0.0.0.0/0`, all ports). This module removes that default and
replaces it with explicit rules per destination. Every egress rule has a
named purpose in its `description` field.

The ALB is a good example — without scoping its egress it could theoretically
reach any IP on any port. The rule `alb_to_ecs` locks it to ECS tasks on
`container_port` only.

### 3 — No egress on managed services

RDS and ElastiCache Redis are AWS-managed services. They accept inbound
connections from the application tier and return responses on the same
connection — they never initiate outbound connections themselves. Omitting
egress rules on `rds_sg` and `redis_sg` is intentional and correct.

The VPC endpoint security group follows the same logic — Interface endpoints
are AWS-managed ENIs that only receive inbound HTTPS from your resources.

---

## Circular Dependency — Problem and Solution

### The problem

`alb_sg` and `ecs_service_sg` need to reference each other:

- ALB egress → ECS SG (ALB forwards to ECS tasks)
- ECS ingress → ALB SG (ECS only accepts traffic from the ALB)

When rules are defined as **inline blocks** inside `aws_security_group`
resources, Terraform treats the rule as part of the resource itself. This
creates a hard graph dependency:

```
alb_sg (must exist first)  ←──  ecs_service_sg (must exist first)
     └── inline egress refs ecs_service_sg       └── inline ingress refs alb_sg
```

Terraform cannot determine which resource to create first and throws:

```
Error: Cycle: module.sec_grp.aws_security_group.vpc_endpoints_sg,
              module.sec_grp.aws_security_group.ecs_service_sg,
              module.sec_grp.aws_security_group.alb_sg
```

### The solution — shells first, rules separate

Create all SGs as empty shells with no inline rules. Since empty SGs have
no cross-references, Terraform can create them all in parallel. Rules are
then attached using the standalone rule resources, which only depend on the
SG IDs (not on each other):

```
Phase 1 — parallel, no dependencies:
  aws_security_group.alb_sg          (empty)
  aws_security_group.ecs_service_sg  (empty)
  aws_security_group.rds_sg          (empty)
  aws_security_group.redis_sg        (empty)
  aws_security_group.vpc_endpoints_sg (empty)

Phase 2 — rules applied after shells exist:
  aws_vpc_security_group_ingress_rule.ecs_from_alb   → references alb_sg.id
  aws_vpc_security_group_egress_rule.alb_to_ecs      → references ecs_service_sg.id
  ... (all other rules)
```

### Argument name differences

The standalone rule resources use different argument names from inline blocks.
Mixing them up causes a `terraform validate` error:

| Inline block argument | Standalone resource argument |
|-----------------------|------------------------------|
| `protocol` | `ip_protocol` |
| `cidr_blocks = ["x.x.x.x/x"]` | `cidr_ipv4 = "x.x.x.x/x"` |
| `security_groups = [sg.id]` | `referenced_security_group_id = sg.id` |

---

## Why No Egress on RDS and Redis

Terraform's `aws_security_group` resource adds an implicit allow-all egress
rule by default. To remove it without specifying an explicit replacement, set
an empty egress block or simply omit egress rules entirely when using the
standalone rule resources.

For this module, `rds_sg` and `redis_sg` have **zero egress rules**. This is
defence-in-depth: even if RDS or ElastiCache were somehow compromised, there
is no security group rule permitting outbound connections to any destination.
Combined with the data tier having no default route in its route table (see
[Network Layer README](../vpc/README.md)), data-tier resources have two
independent layers preventing outbound traffic.

---

## Module Inputs

| Variable | Type | Description |
|----------|------|-------------|
| `vpc_id` | `string` | VPC ID from the `vpc` module output |
| `project_name` | `string` | Used in all resource Name tags |
| `environment` | `string` | `dev` or `prod` |
| `container_port` | `number` | ECS container port — used for ALB → ECS rules |

---

## Module Outputs

| Output | Description | Consumed by |
|--------|-------------|-------------|
| `alb_sg_id` | ALB security group ID | `alb` module |
| `ecs_service_sg_id` | ECS task security group ID | `ecs` module |
| `rds_sg_id` | RDS security group ID | `rds` module |
| `redis_sg_id` | ElastiCache security group ID | `redis` module |
| `vpc_endpoints_sg_id` | VPC endpoint security group ID | `vpc` module |

---

## Usage

```hcl
module "sec_grps" {
  source = "../../modules/sec_grps"

  vpc_id         = module.vpc.vpc_id
  project_name   = var.project_name
  environment    = var.environment
  container_port = 3000
}

# Consuming outputs in other modules
module "ecs" {
  source = "../../modules/ecs"

  ecs_service_sg_id = module.sec_grps.ecs_service_sg_id
  alb_sg_id         = module.sec_grps.alb_sg_id
  ...
}

module "rds" {
  source = "../../modules/rds"

  rds_sg_id = module.sec_grps.rds_sg_id
  ...
}
```

---

## Related Modules

| Module | Relationship |
|--------|-------------|
| [`vpc`](../vpc/README.md) | Provides `vpc_id` and subnet CIDRs — must be applied before this module |
| [`alb`](../alb/README.md) | Consumes `alb_sg_id` |
| [`ecs`](../ecs/README.md) | Consumes `ecs_service_sg_id` |
| [`rds`](../rds/README.md) | Consumes `rds_sg_id` |
| [`redis`](../redis/README.md) | Consumes `redis_sg_id` |
| [`vpc` endpoints](../vpc/README.md#vpc-endpoints--cost-optimisation) | Consumes `vpc_endpoints_sg_id` |

---

*Managed by Terraform - do not modify security group rules directly in the AWS console.*
*Manual changes will be overwritten on the next `terraform apply`.*
