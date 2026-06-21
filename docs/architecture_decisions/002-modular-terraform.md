# ADR-002: Modular Terraform Architecture

## Status
Accepted

## Date
19-05-2026

## Context
The platform infrastructure spans multiple AWS services: networking (VPC,
subnets, route tables, VPC endpoints), security (IAM, security groups),
compute (ECS, ALB), data (RDS, ElastiCache), delivery (CloudFront, S3,
Route 53), and observability (CloudWatch, monitoring). Writing all resources
in a single Terraform configuration would create a monolithic, untestable,
and environment-specific codebase that cannot be reused across dev and prod.

## Alternatives Considered

**Single flat Terraform configuration**
- All resources in one directory
- Simple to start, increasingly difficult to maintain
- No reuse between environments — changes to dev risk prod
- No clear ownership boundaries between infrastructure concerns

**Terraform modules (one per service boundary)** ✅ Selected
- As the platform evolved, modules were further decomposed where a single module began to own multiple infrastructure responsibilities. The original ECS module was split into dedicated service and task modules (ecs_service, ecs_task_transcoder, and ecs_task_video_service) to preserve single-responsibility boundaries and support independent lifecycle management of long-running services and event-driven workloads. 
- Modules are called from environment-specific roots (`environments/dev`,
  `environments/prod`) with environment-specific variable values
- Changes to one module do not affect others unless explicitly called
- Enables independent testing and targeted `terraform plan` scoping

## Decision
Organise all infrastructure as reusable Terraform modules under
`infra/terraform/modules/`. Each module exposes typed input variables and
outputs consumed by other modules, enforcing explicit dependency declaration.

```text
modules/
├── alb                  # Application Load Balancer + listener rules
├── cloudfront           # CDN distribution + origin access control
├── cloudwatch           # Log groups + metric filters + alarms
├── ecr                  # Container registries per service
├── ecs_service          # ECS cluster + long-running ECS services
├── ecs_task_transcoder  # FFmpeg transcoder task definition
├── ecs_task_video_service   # Video API task definition
├── eks                  # Kubernetes cluster (scaffolded — future phase)
├── iam                  # IAM roles, policies, queue policies
├── lambda               # SQS consumer launching ECS RunTask workloads
├── monitoring           # Prometheus + Grafana (future phase)
├── rds                  # PostgreSQL instance + subnet group + parameter group
├── redis                # ElastiCache cluster + subnet group
├── route53              # Hosted zone + DNS records (deferred — ADR-008)
├── s3                   # Ingest, delivery, and static asset buckets
├── sec_grps             # Security groups + ingress/egress rules
├── sns                  # Event publication layer
├── sqs                  # Processing queues + dead letter queues
└── vpc                  # VPC, subnets, route tables, NAT gateway, endpoints
```

## Consequences
- **Positive:** Environment parity — dev and prod use the same modules with
  different `terraform.tfvars` values.
- **Positive:** - **Positive:** Modular boundaries allow infrastructure changes to be
  isolated to specific service domains and independently reviewed through
  Terraform plans without impacting unrelated infrastructure components.
- **Positive:** Clear ownership — each module has a single responsibility,
  its own `outputs.tf`, and its own `README.md`.
- **Accepted trade-off:** More initial boilerplate — each module requires
  `variables.tf`, `outputs.tf`, and a root file. This is offset by long-term
  maintainability.
- **Accepted trade-off:** Inter-module output wiring must be explicit —
  a missing output reference fails at `terraform validate` rather than silently.

---