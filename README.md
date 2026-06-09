# VOD Streaming Platform — DevOps MVP

A cloud-native Video on Demand (VOD) streaming platform built on AWS using
Infrastructure as Code, containerised microservices, event-driven video
processing, and secure CI/CD pipelines.

The platform is intentionally developed in iterative phases to demonstrate
architectural decision-making, infrastructure evolution, and operational
trade-offs rather than simply deploying technology for its own sake.

The MVP uses ECS Fargate for container orchestration and a containerised
FFmpeg transcoding pipeline. The architecture is designed to evolve toward
an EKS-based platform once operational requirements justify the additional
complexity.

> **Status:** MVP — active development. Core infrastructure (VPC, Security
> Groups, IAM, ECS, ECR, ALB, CloudWatch, GitHub OIDC, and CI/CD) complete.
> Video pipeline, S3, CloudFront, Route53, RDS, and ElastiCache are currently
> in development.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Tech Stack](#tech-stack)
- [Repository Structure](#repository-structure)
- [Infrastructure Overview](#infrastructure-overview)
- [CI/CD Pipeline](#cicd-pipeline)
- [Getting Started](#getting-started)
- [Architecture Decision Records](#architecture-decision-records)
- [Module Documentation](#module-documentation)
- [Architecture Evolution](#architecture-evolution)
- [MVP Scope and Post-MVP Roadmap](#mvp-scope-and-post-mvp-roadmap)

---

## Architecture Overview

![VOD Streaming Platform — Network Architecture](docs/vpc-network-architecture.png)

The platform uses a three-tier AWS VPC spanning three Availability Zones.
Application workloads are isolated within private subnets while databases
and caching infrastructure reside in a dedicated data tier with no direct
internet access.

Two primary traffic paths exist:

### API Traffic Path

```text
Internet
    │
    ▼
Application Load Balancer
    │
    ▼
ECS Fargate Services
    │
    ▼
RDS / Redis
```

### Video Delivery Path

```text
Subscriber
     │
     ▼
CloudFront + WAF
     │
     ▼
S3 Delivery Bucket
```

### End-to-End Platform Architecture

```text
                           ┌─────────────────┐
                           │     GitHub      │
                           └────────┬────────┘
                                    │
                                    ▼
                         ┌─────────────────────┐
                         │ GitHub Actions CI/CD│
                         └─────────┬───────────┘
                                   │
                                   ▼
                         ┌─────────────────────┐
                         │ AWS OIDC Federation │
                         └─────────┬───────────┘
                                   │
                                   ▼
                         ┌─────────────────────┐
                         │ Amazon ECR          │
                         └─────────┬───────────┘
                                   │
                                   ▼
                    ┌─────────────────────────────┐
                    │ Amazon ECS (Fargate)        │
                    └──────────────┬──────────────┘
                                   │
                     ┌─────────────┴─────────────┐
                     │                           │
                     ▼                           ▼

             Video Service                FFmpeg Worker

                     │                           ▲
                     │                           │
                     ▼                           │

              S3 Ingest Bucket                  │
                     │                           │
                     ▼                           │

                    SNS                          │
                     │                           │
                     ▼                           │

                    SQS ─────────────────────────┘
                     │
                     ▼

              S3 Delivery Bucket
                     │
                     ▼

              CloudFront + WAF
                     │
                     ▼

                 Subscribers
```

---

## Tech Stack

| Layer | Technology | Purpose |
|---------|---------|---------|
| **Frontend** | React + Next.js, React Native | Web and mobile clients |
| **CDN / Edge** | CloudFront, AWS WAF, AWS Shield | Global delivery and edge security |
| **DNS / TLS** | Route53, ACM | DNS management and TLS certificates |
| **API Routing** | Application Load Balancer | HTTPS termination and request routing |
| **Compute** | ECS Fargate | Serverless container orchestration |
| **Services** | FastAPI (current), Go (planned) | Video service, playback service, future microservices |
| **Video Pipeline** | FFmpeg, ECS Fargate, SNS, SQS, S3, CloudFront | Video transcoding and content delivery |
| **Database** | PostgreSQL (planned) | Metadata and transactional storage |
| **Cache** | Redis (planned) | Sessions, caching, rate limiting |
| **Object Storage** | Amazon S3 | Video ingest, delivery, and static assets |
| **Container Registry** | Amazon ECR | Docker image storage |
| **Infrastructure as Code** | Terraform | AWS infrastructure provisioning |
| **CI/CD** | GitHub Actions + OIDC | Automated deployment pipeline |
| **Secrets** | AWS Secrets Manager (planned) | Runtime secret management |
| **Observability** | CloudWatch Logs and Metrics | Logging and monitoring |
| **Security** | IAM, Security Groups, OIDC, VPC Endpoints | Least-privilege architecture |

---

## Repository Structure

```text
streaming-platform/
├── docs/
│   ├── architecture-decisions/
│   └── diagrams/
│
├── frontend/
│
├── mobile/
│
├── services/
│   ├── auth-service/
│   ├── billing-service/
│   ├── catalog-service/
│   ├── playback-service/
│   ├── transcoder-worker/
│   └── video-service/
│
├── infra/
│   ├── helm/
│   ├── kubernetes/
│   └── terraform/
│       ├── environments/
│       ├── modules/
│       └── shared/
│
└── scripts/
```

---

## Infrastructure Overview

### Network Layer

A three-tier VPC design enforces strict separation between public, application,
and data tiers. ECS services run in private application subnets while
databases and cache services reside in isolated private data subnets.

VPC endpoints are used for AWS service communication where appropriate,
reducing NAT Gateway dependency and lowering AWS data processing costs.

→ See `infra/terraform/modules/vpc/networking.md`

---

### Security Groups

Security groups enforce least-privilege communication between:

- Application Load Balancer
- ECS Services
- PostgreSQL
- Redis
- Future EKS workloads

Security group references are used instead of CIDR-based rules wherever
possible to support dynamic ECS task IP allocation.

→ See `infra/terraform/modules/sec_grps/security_groups.md`

---

### Container Platform

The MVP uses ECS Fargate for workload execution.

Current services:

- Video Service (FastAPI)
- FFmpeg Transcoder Worker

Future services:

- Auth Service
- Catalog Service
- Billing Service
- Playback Service

Each service receives:

- Dedicated ECR repository
- ECS task definition
- IAM execution role
- CloudWatch log group

---

### Video Pipeline

Source video is uploaded directly to an S3 ingest bucket via a pre-signed
multipart upload URL generated by the Video Service.

An S3 ObjectCreated event publishes to SNS, which fans out to an SQS
transcoding queue. ECS Fargate FFmpeg workers consume jobs from the queue,
generate an adaptive bitrate HLS ladder, and write output assets to the
delivery bucket.

CloudFront distributes content globally using Origin Access Control (OAC)
and signed cookies for subscriber access control.

```text
Client Upload
      │
      ▼
S3 Ingest Bucket
      │
      ▼
SNS Topic
      │
      ▼
SQS Queue
      │
      ▼
FFmpeg Worker (ECS Fargate)
      │
      ▼
S3 Delivery Bucket
      │
      ▼
CloudFront CDN
      │
      ▼
Subscriber
```

---

## CI/CD Pipeline

```text
Git Push (main)
      │
      ▼
GitHub Actions
      │
      ▼
Docker Build
      │
      ▼
Push Image to ECR
      │
      ▼
ECS Service Update
      │
      ▼
Rolling Deployment
```

Authentication to AWS uses GitHub OIDC federation.

No long-lived AWS access keys exist within the repository or GitHub Actions
configuration.

Future enhancements include:

- Trivy image scanning
- Unit test execution
- Integration testing
- Deployment approval gates
- Environment promotion workflows

---

## Getting Started

### Prerequisites

| Tool | Version |
|--------|---------|
| Terraform | >= 1.6 |
| AWS CLI | >= 2.x |
| Docker Desktop | >= 24.x |

---

### AWS Authentication

```bash
aws configure --profile streaming-platform-dev
export AWS_PROFILE=streaming-platform-dev
```

---

### Deploy Development Environment

Terraform automatically resolves inter-module dependencies through outputs
and references.

```bash
cd infra/terraform/environments/dev

terraform init

terraform plan

terraform apply
```

---

### Destroy Development Environment

```bash
terraform destroy
```

---

## Architecture Decision Records

ADRs document the major engineering decisions made throughout the project.

| ADR | Decision | Status |
|------|----------|----------|
| ADR-001 | Use ECS Fargate for MVP container orchestration over EKS | Accepted |
| ADR-002 | Organise infrastructure as reusable Terraform modules | Accepted |
| ADR-003 | Use GitHub OIDC federation instead of long-lived IAM access keys | Accepted |
| ADR-004 | Use S3 + CloudFront with signed cookies for content delivery | Accepted |
| ADR-005 | Use FFmpeg on ECS Fargate for video transcoding | Accepted |
| ADR-006 | Use FastAPI for the Video Service API layer | Accepted |

See:

```text
docs/architecture-decisions/
```

---

## Module Documentation

Each Terraform module contains documentation covering:

- Purpose
- Inputs
- Outputs
- Design decisions
- Usage examples

| Module | Status |
|----------|----------|
| VPC | Complete |
| Security Groups | Complete |
| IAM | Complete |
| GitHub OIDC | Complete |
| ECS | Complete |
| ECR | Complete |
| ALB | Complete |
| CloudWatch | Complete |
| S3 | In Progress |
| CloudFront | In Progress |
| Route53 | In Progress |
| RDS | Planned |
| Redis | Planned |
| Monitoring | Planned |
| EKS | Planned |

---

## Architecture Evolution

The platform is intentionally built in stages to reflect how production
systems evolve over time.

### Phase 1 — Foundation ✅

- Terraform module architecture
- Three-tier VPC
- Security groups
- ECS Fargate
- ECR
- ALB
- CloudWatch
- GitHub OIDC
- CI/CD

### Phase 2 — Video Platform 🚧

- S3 ingest pipeline
- FFmpeg transcoding workers
- SNS/SQS event architecture
- CloudFront content delivery
- Route53 integration

### Phase 3 — Data Services

- PostgreSQL metadata store
- Redis cache layer
- Secrets Manager integration

### Phase 4 — Observability

- OpenTelemetry
- Prometheus
- Grafana
- Distributed tracing

### Phase 5 — Kubernetes Migration

- Amazon EKS
- Helm
- ArgoCD
- AWS Load Balancer Controller
- ExternalDNS
- Cert Manager

---

## MVP Scope and Post-MVP Roadmap

### MVP Scope

- Three-tier AWS VPC
- ECS Fargate
- ECR
- ALB
- CloudWatch
- GitHub OIDC
- CI/CD pipeline
- S3 ingest and delivery pipeline
- FFmpeg-based transcoding
- CloudFront CDN
- Route53 integration
- PostgreSQL metadata store
- Redis cache

### Post-MVP Enhancements

| Feature | Reason Deferred |
|----------|----------|
| EKS | Additional operational complexity |
| ArgoCD | Requires Kubernetes platform |
| Helm | Requires Kubernetes platform |
| DRM (Widevine/FairPlay) | Licensing and operational complexity |
| Multi-region deployment | Not required for MVP scale |
| Recommendation engine | Depends on user behavioural data |
| DASH output | HLS sufficient for MVP |

---

## License

This project is intended for educational, portfolio, and professional
development purposes.

All infrastructure changes should be performed through Terraform and
applied via the CI/CD pipeline where possible.