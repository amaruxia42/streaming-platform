# ADR-003: GitHub OIDC Federation for CI/CD Authentication

## Status
Accepted

## Date
02-06-2026

## Context
The CI/CD pipeline (GitHub Actions) requires AWS credentials to deploy
infrastructure and push container images to ECR. The conventional approach
is to generate an IAM user, create a long-lived access key, and store it as
a GitHub Actions secret (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`).

Long-lived static credentials are a significant security risk: they do not
expire, are frequently over-permissioned, and if leaked via a repository
exposure or a compromised runner, grant persistent AWS access until manually
rotated. AWS IAM best practice explicitly recommends against long-lived keys
for machine identities.

## Alternatives Considered

**IAM user with long-lived access keys**
- Simple to set up
- Keys do not expire — require manual rotation policy
- If leaked, provide persistent AWS access
- Cannot be scoped to a specific repository or branch
- Not recommended by AWS for CI/CD workloads

**GitHub OIDC federation with IAM role assumption** ✅ Selected
- GitHub Actions presents a signed OIDC token to AWS STS per workflow run
- AWS STS validates the token against the GitHub OIDC provider and issues
  short-lived credentials (maximum 1 hour)
- No static credentials exist anywhere — nothing to leak, rotate, or audit
- Trust policy can be scoped to a specific repository, branch, or environment
- AWS-recommended pattern for GitHub Actions

## Decision
Configure an AWS IAM OIDC provider for `token.actions.githubusercontent.com`
and an IAM deployment role with a trust policy scoped to this repository.
GitHub Actions assumes the role via `aws-actions/configure-aws-credentials`
at the start of each workflow. Credentials expire automatically at the end
of the workflow run.

The GitHub Actions module provisions the OIDC provider and deployment role while IAM permissions remain managed separately within the IAM module. Credential configuration remains version-controlled alongside the infrastructure it secures.

## Consequences
- **Positive:** Zero static credentials in GitHub Secrets or anywhere else.
- **Positive:** Credentials are short-lived — a compromised runner gains
  access only for the duration of a single workflow run (≤1 hour).
- **Positive:** Trust policy enforces `repo:org/streaming-platform:ref:refs/heads/main`
  — only the main branch of this specific repository can assume the role.
- **Accepted trade-off:** Requires initial OIDC provider configuration in AWS —
  slightly more setup than generating an access key, but a one-time cost.
- **Accepted trade-off:** AWS-specific pattern — not directly portable to
  other cloud providers, though GCP and Azure support equivalent OIDC flows.