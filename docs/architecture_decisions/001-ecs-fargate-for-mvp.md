# ADR-001: Use ECS Fargate for Container Orchestration During MVP

## Status
Accepted

## Date
18-05-2026

## Context
The platform requires a container orchestration layer to run microservices
(auth, catalog, billing, playback, video) across a three-tier AWS VPC. The
decision was needed early in the project as it drives CI/CD pipeline design,
IAM role structure, networking, and cost profile throughout the MVP phase.

Two options were evaluated: Amazon ECS Fargate and Amazon EKS. Both support
containerised workloads on AWS but differ significantly in operational
complexity, cost, and capability.

## Alternatives Considered

**Amazon EKS (Kubernetes)**
- Full Kubernetes API — portable, extensible, industry standard
- Supports advanced workload patterns (Karpenter, HPA, service mesh)
- EKS control plane: ~$72/month regardless of workload
- Requires cluster management, node group configuration, and Kubernetes
  expertise to operate safely
- Longer time to first deployment for an MVP

**Amazon ECS Fargate** ✅ Selected
- AWS-native, serverless container runtime — no node or cluster management
- Pay only for vCPU and memory consumed per task
- Native integration with ALB, CloudWatch, ECR, IAM, and Secrets Manager
- Simpler CI/CD — GitHub Actions can deploy directly via `ecs update-service`
- Sufficient for all MVP workload requirements

## Decision
Use Amazon ECS Fargate for the MVP. The `ecs/` Terraform module manages task
definitions, services, and cluster configuration. EKS infrastructure is
deferred to a post-MVP phase.

The `eks/` module directory is scaffolded in the repository now to preserve
the intended long-term platform architecture and reduce future migration
effort.

## Consequences
- **Positive:** Faster time to deployment; lower baseline cost; reduced
  operational overhead during development.
- **Positive:** Full ALB, CloudWatch Logs, and Secrets Manager integration
  without additional configuration.
- **Accepted trade-off:** No Kubernetes-native features (Helm, CRDs, HPA on
  custom metrics, service mesh) during MVP.
- **Accepted trade-off:** ECS task definitions are AWS-specific — workloads
  are not portable to other cloud providers without rework.
- **Future:** Migration from ECS to EKS is planned for the production release.
  The three-tier VPC and IAM role structure are designed to be compatible with
  EKS from the outset, minimising rework.

---