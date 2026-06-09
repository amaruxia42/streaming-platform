# ADR-004: S3 + CloudFront for Video Delivery and Static Asset Hosting

## Status
Accepted

## Date
06-07-2026

## Context
The platform requires a content delivery strategy covering two distinct
workloads:

1. **Video segment delivery** — HLS manifests (`.m3u8`) and transport stream
   segments (`.ts`) served to web, mobile, and smart TV clients during
   playback. Latency and cache hit rate directly impact the viewer experience.
   A buffer event caused by a slow origin or cache miss is measurable and
   visible to the user.

2. **Static asset delivery** — frontend HTML, CSS, JavaScript bundles, and
   thumbnail images for the React + Next.js web client.

Both workloads require global low-latency delivery, HTTPS enforcement, and
access control to prevent unauthorised access to premium content. The
platform runs on AWS (eu-west-2), so the delivery architecture decision
determines how tightly coupled the platform is to the AWS ecosystem and
what the per-GB egress cost profile looks like at scale.

A secondary concern is **subscriber access control**. The platform is a
subscription service — content must only be accessible to authenticated
subscribers with an active plan. Delivery infrastructure must enforce this
at the CDN layer, not just at the application layer.

## Alternatives Considered

### Option 1 — Self-hosted Nginx on ECS as origin and edge cache

Nginx running as an ECS Fargate service can act as both a reverse proxy
and a caching layer for video segments and static assets.

**Evaluated and rejected for the following reasons:**

- No global edge network — all traffic routes to the single AWS region
  (eu-west-2), adding latency for users outside London
- Cache lives in ECS task memory/disk — no persistent CDN cache layer
  surviving task restarts or scaling events
- Requires manual TLS certificate management, cache invalidation logic,
  and origin health check configuration
- Operational overhead of managing an Nginx configuration at scale is
  significant — cache tuning, log analysis, and failure recovery all fall
  to the engineering team
- Egress costs from ECS to the internet are higher than CloudFront's
  discounted egress rates

Nginx remains in the stack as a reverse proxy inside ECS for inter-service
routing, but is not appropriate as a public CDN origin.

### Option 2 — Cloudflare CDN + R2 object storage

Cloudflare offers a global CDN with competitive per-GB pricing and R2
object storage with zero egress fees between R2 and Cloudflare's edge.

**Evaluated and rejected for the following reasons:**

- Introduces a second cloud vendor alongside AWS, adding operational
  complexity and a second billing relationship for an MVP
- R2 is not a drop-in replacement for S3 — migration would require changes
  to the Terraform storage modules, IAM policies, and application-level
  S3 SDK calls
- Cloudflare signed tokens work differently from CloudFront signed cookies —
  the access control mechanism would need to be rebuilt if the platform
  later consolidates on AWS
- The cost advantage of R2 zero-egress is significant at scale but not
  material at MVP traffic volumes

Cloudflare is worth revisiting post-MVP if egress costs become a meaningful
line item.

### Option 3 — AWS S3 + CloudFront with OAC and signed cookies ✅ Selected

S3 as the origin store for both video segments and static assets, fronted
by a CloudFront distribution with Origin Access Control (OAC) and signed
cookies for subscriber access control.

**Selected for the following reasons:**

- Native AWS integration — S3, CloudFront, ACM, WAF, and Route 53 all
  operate within the same account, region, and IAM permission model
- No additional vendor relationship or billing account to manage during MVP
- CloudFront's global edge network (600+ PoPs) provides low-latency delivery
  without operating any edge infrastructure
- OAC is the current AWS-recommended mechanism for restricting S3 bucket
  access to CloudFront only — supersedes the legacy Origin Access Identity
  (OAI) pattern
- Signed cookies are the correct access control mechanism for HLS playback
  (see Access Control Design below)

## Decision

Use **AWS S3 as the origin** for video segments and static assets, fronted
by a **CloudFront distribution** with the following configuration:

- **Origin Access Control (OAC)** on the S3 delivery bucket — blocks all
  direct S3 access; content is only accessible via CloudFront
- **CloudFront signed cookies** for subscriber access control using CloudFront Key Groups
- **Separate cache behaviours** per content type with tuned TTLs
- **AWS WAF** attached to the CloudFront distribution for edge-layer
  protection (rate limiting, bot control, geo-restriction)
- **ACM certificate** on the CloudFront distribution for HTTPS enforcement

### Access Control Design — Signed Cookies over Signed URLs

HLS video playback involves a high volume of individual HTTP requests per
session — one request for the master manifest, one per rendition manifest,
and one per transport stream segment (typically every 6 seconds across
multiple renditions). A 60-minute episode at six quality levels generates
approximately 600–800 segment requests per viewer session.

**CloudFront signed URLs** grant access per file. Signing 600–800 URLs
individually per session — either upfront or dynamically — introduces
significant application complexity and latency overhead.

**CloudFront signed cookies** grant access to a path pattern in a single
operation. One cookie covers `episodes/{show}/{season}/*`, authorising
the manifest and all segment requests for the entire session. The cookie
is issued by the playback service at session start after validating the
subscriber's entitlement, and all subsequent CDN requests carry it
automatically via the browser or native player cookie jar.

```
Subscriber requests playback
          │
          ▼
Playback service checks entitlement (active subscription)
          │
          ▼
Issues CloudFront signed cookie

The cookie is signed using a CloudFront Key Group. Private signing keys are
stored in AWS Secrets Manager and accessed only by the Playback Service IAM
role responsible for issuing playback authorisation.

The cookie is signed using a CloudFront Key Group. Private signing keys are stored in AWS Secrets Manager and accessed only by the Playback Service IAM role responsible for issuing playback authorisation.
  - Policy: episodes/show-1/season-1/*
  - Expiry: 6 hours from issue time
  - Signed with CloudFront key pair (private key in Secrets Manager)
          │
          ▼
Client streams HLS — all segment requests carry cookie automatically
          │
          ▼
CloudFront validates cookie on every request — no application involvement
```

Signed URLs are used for one-off asset downloads (subtitles, thumbnail
sprites) where per-file access control is appropriate.

### Cache Behaviour TTLs

| Path pattern | Content type | Cache-Control | Rationale |
|-------------|-------------|---------------|-----------|
| `*.m3u8` | HLS manifest | `max-age=5, must-revalidate` | Short TTL — manifests update as new segments are added |
| `*.ts` | HLS segment | `max-age=31536000` | Immutable — segment content never changes once written |
| `/static/*` | Frontend assets | `max-age=31536000` | Immutable — hashed filenames on every build |
| `/thumbnails/*` | Thumbnail images | `max-age=86400` | Stable but not immutable |

### S3 Bucket Structure

```
streaming-platform-ingest-{env}/    # Raw source video — private, no CloudFront
streaming-platform-delivery-{env}/  # Processed HLS assets — OAC, CloudFront only
streaming-platform-assets-{env}/    # Static frontend assets — OAC, CloudFront only
```

DASH packaging is intentionally deferred to a post-MVP phase. The delivery
bucket structure is designed to accommodate DASH manifests and segments in
the future without requiring changes to the surrounding storage architecture.

The ingest bucket has no CloudFront distribution — it is accessed only by
the transcoding pipeline via IAM role. The delivery and assets buckets are
private with OAC; no public S3 access is granted.

## Consequences

- **Positive:** Global low-latency video delivery via CloudFront edge network
  without operating any edge infrastructure.
- **Positive:** OAC ensures the S3 delivery bucket is never publicly
  accessible — content can only be served through CloudFront.
- **Positive:** Signed cookies handle HLS multi-segment access control in
  a single operation — no per-segment signing logic in the application.
- **Positive:** CloudFront discounted egress rates reduce data transfer costs
  compared to direct S3 or ECS egress to the internet.
- **Accepted trade-off:** CloudFront signed cookies require a CloudFront
  key pair — the private key must be securely stored in AWS Secrets Manager
  and rotated periodically.
- **Accepted trade-off:** Cookie-based access control requires clients to
  support cookies — applicable to web and native mobile clients but requires
  explicit handling in smart TV SDK implementations.
- **Accepted trade-off:** Platform is coupled to AWS for CDN delivery during
  the MVP. Cloudflare migration path exists post-MVP if egress costs justify
  the operational change.
- **Future:** Evaluate Cloudflare R2 + CDN post-MVP if egress costs become
  a material concern at scale.
