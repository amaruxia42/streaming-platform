ADR-008: Defer Route53 Until Custom Domain Requirement Exists

## Status
Accepted

## Date
10-06-2026

## Context

The platform does not currently require a public custom domain.
CloudFront provides a globally routable HTTPS endpoint suitable for MVP
testing and portfolio demonstrations.

## Decision 

Route53 infrastructure is deferred until a custom domain requirement
exists.

## Consequences 

Positive:
- Reduced infrastructure complexity
- No domain registration costs
- No certificate management requirements

Trade-off:
- URLs use the CloudFront domain name