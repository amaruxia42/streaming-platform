# ADR-005: FFmpeg on ECS for Video Transcoding Pipeline

## Status
Accepted

## Date
07-06-2026

## Context
The platform requires a video transcoding pipeline capable of converting
raw source video uploaded by content managers into adaptive bitrate (ABR)
HLS format, delivered across multiple quality renditions to support varying
network conditions and device capabilities on web, mobile, and smart TV clients.

The transcoding pipeline sits at the core of the content ingestion workflow.
Architectural decisions here affect cost at scale, vendor dependency, pipeline
reliability, and the effort required to switch transcoding providers as the
platform grows. These concerns were weighted explicitly in the evaluation.

The ingestion flow is as follows regardless of transcoding solution chosen:

```
Content manager uploads source video
          │
          ▼
S3 ingest bucket (pre-signed multipart URL)
          │
          └── S3 Event Notification
                    │
                    ▼
                  SQS queue (durable job buffer)
                    │
                    ▼
              Transcoding layer  ←── decision point
                    │
                    ▼
          HLS segments + manifests
                    │
                    ▼
          S3 delivery bucket → CloudFront
```

The decision point is what sits in the transcoding layer. Three options
were evaluated.

## Alternatives Considered

### Option 1 — AWS Elemental MediaConvert

AWS MediaConvert is a managed file-based transcoding service. Jobs are
submitted via API, MediaConvert handles the compute, and output files are
written to S3.

**Evaluated and rejected for the following reasons:**

**Cost at scale:** MediaConvert charges per minute of output video per
rendition. A full ABR ladder (240p, 360p, 480p, 720p, 1080p, 4K) means
each source minute is billed six times. A 2-hour film costs approximately
$2.16 in MediaConvert output charges alone — before S3 storage or data
transfer. At a catalogue of 500 titles that is over $1,000 in transcoding
costs before a single user streams anything.

**Vendor lock-in:** MediaConvert job definitions, preset configurations,
and queue management are AWS-proprietary. The Lambda trigger logic, IAM
policies, and retry behaviour are all written against the MediaConvert API.
Migrating to another transcoding provider requires rewriting the entire
pipeline, not just swapping a configuration value.

**No multi-cloud path:** The platform has a near-term requirement to evaluate
third-party transcoding providers (Mux, Cloudflare Stream, Coconut.co) that
offer per-minute pricing significantly below MediaConvert. MediaConvert
makes that evaluation more expensive — the switching cost is high because
the pipeline is deeply coupled to AWS-specific constructs.

### Option 2 — Self-hosted FFmpeg on EC2 (dedicated instances)

Run FFmpeg on dedicated EC2 instances sized for transcoding workloads
(compute-optimised: `c6i`, `c6a` families).

**Evaluated and rejected for the following reasons:**

- Requires provisioning, patching, and managing EC2 instances — operational
  overhead not justified when ECS is already in the stack
- Instances must be running continuously or scaled via Auto Scaling Groups,
  adding complexity and idle cost between transcoding jobs
- No meaningful advantage over FFmpeg on ECS — ECS Fargate eliminates the
  instance management burden while retaining the same FFmpeg flexibility

### Option 3 — FFmpeg on ECS Fargate (containerised, event-driven) ✅ Selected

FFmpeg packaged as a Docker container, run as an ECS Fargate task triggered
from an SQS queue. Each transcoding job spins up a Fargate task, completes
the transcode, writes output to S3, and terminates. No infrastructure runs
when there are no jobs.

**Selected for the following reasons:**

- **Vendor-agnostic:** FFmpeg is open source and industry standard. It is
  the encoder used internally by MediaConvert, Mux, and most commercial
  transcoding services. The pipeline logic (S3 input, HLS output, S3
  delivery) is decoupled from the transcoding engine and can be rewired
  to an external provider API without restructuring the surrounding
  architecture.
- **Cost-controlled:** Fargate charges only for vCPU and memory consumed
  during the task runtime. A 2-hour film transcoding to a six-rendition
  ABR ladder takes approximately 30–45 minutes on a 4 vCPU / 8 GB task,
  costing roughly $0.08–$0.12 per title — significantly below MediaConvert
  for equivalent output.
- **Uses existing infrastructure:** ECS, ECR, SQS, IAM, S3, and CloudWatch
  Logs are already provisioned. No new AWS service is introduced.
- **Multi-cloud transition path:** When third-party transcoding providers
  are evaluated post-MVP, the SQS consumer can be modified to submit an
  API request to an external provider rather than launching a Fargate task.
  The S3 ingest trigger, delivery bucket, and CloudFront distribution remain
  unchanged — the transcoding layer is the only component that changes.

## Decision

Use **FFmpeg running as a containerised ECS Fargate task**,A lightweight Lambda function acts as the queue consumer and orchestration layer. Its sole responsibility is to receive messages from SQS and launch an ECS Fargate task via the ECS RunTask API. The Lambda function performs no transcoding itself.

### Pipeline Architecture

```
S3 ingest bucket
      │
      └── S3 Event Notification (ObjectCreated)
                │
                ▼
             SNS topic
                │
                ▼
             SQS queue  ←── dead letter queue (maxReceiveCount: 3)
                │
                ▼
            Lambda consumer
                │
                ▼
        ECS RunTask API
                │
                ▼
        ECS Fargate task
        ┌──────────────────────────────────┐
        │  FFmpeg transcoding container    │
        │                                  │
        │  Input:  s3://ingest/{key}       │
        │  Output: s3://delivery/{key}/    │
        │                                  │
        │  ABR ladder:                     │
        │    240p  — 400kbps  H.264        │
        │    360p  — 800kbps  H.264        │
        │    480p  — 1400kbps H.264        │
        │    720p  — 2800kbps H.264        │
        │    1080p — 5000kbps H.264        │
        │                                  │
        │  Container: H.264 + AAC          │
        │  Format: HLS (.m3u8 + .ts)       │
        │  Segment duration: 6 seconds     │
        └──────────────────────────────────┘
                │
                ▼
        S3 delivery bucket
        ├── {title}/master.m3u8
        ├── {title}/240p/index.m3u8
        ├── {title}/240p/segment-001.ts
        ├── {title}/240p/segment-002.ts
        ├── ...
        └── {title}/1080p/segment-NNN.ts
                │
                ▼
        CloudFront CDN (OAC + signed cookies)
```

### HLS Output Format

HLS (HTTP Live Streaming) is selected as the primary output format for
the following reasons:

- Native support in Safari, iOS, iPadOS, macOS, and Apple TV without
  additional libraries — critical for the smart TV and mobile client targets
- Broad support in Chrome and Android via HLS.js (browser) and ExoPlayer
  (Android native) with no DRM constraint at MVP
- Segment-based delivery maps naturally to CloudFront caching — each `.ts`
  segment is an immutable, independently cacheable object
- Industry standard for live and VOD delivery — supported by all major
  CDN providers if the platform moves away from CloudFront post-MVP

DASH (MPEG-DASH) is deferred to post-MVP. DASH offers better codec
flexibility (AV1, VP9) and is preferred for Widevine DRM on Android, but
adds packaging complexity not justified at this stage.

### SQS Dead Letter Queue

The SQS queue is configured with a Dead Letter Queue (DLQ) to handle
transcoding failures without losing jobs:

- `maxReceiveCount: 3` — a job is retried up to three times before being
  moved to the DLQ
- DLQ triggers a CloudWatch alarm → SNS → email notification
- Failed jobs in the DLQ are inspectable and can be replayed manually
  after the underlying issue is resolved

This is more robust than a Lambda trigger alone, which would silently drop
a failed invocation after its retry window expired.

### Multi-Cloud Transition Path

The pipeline is explicitly designed for the transcoding layer to be
replaceable. The interface contract is:

- **Input:** S3 object key in the ingest bucket
- **Output:** HLS segments and manifests written to a defined path in the
  delivery bucket

Any transcoding provider that can consume an S3 input and write HLS output
to S3 can replace the FFmpeg ECS task without changes to the surrounding
pipeline. Third-party providers evaluated for post-MVP:

| Provider | Pricing model | Integration |
|----------|--------------|-------------|
| Mux | Per minute of stored video | REST API, S3 input supported |
| Cloudflare Stream | Per minute stored + delivered | REST API, URL or S3 input |
| Coconut.co | Per minute of output | REST API, S3 input/output |
| Transloadit | Per GB processed | REST API, S3 input/output |

## Consequences

- **Positive:** No vendor lock-in — FFmpeg is open source and the pipeline
  is architected for a replaceable transcoding layer.
- **Positive:** Significant cost reduction versus MediaConvert at catalogue
  scale — Fargate compute cost per title is a fraction of per-rendition
  MediaConvert billing.
- **Positive:** No idle infrastructure cost — Fargate tasks run only during
  active transcoding jobs.
- **Positive:** Uses existing ECS, ECR, SQS, and S3 infrastructure — no
  new AWS service dependency introduced.
- **Positive:** SQS DLQ provides durable job retry and failure visibility
  without custom retry logic in the application.
- **Accepted trade-off:** FFmpeg container must be maintained — base image
  updates, codec version management, and security patching are the team's
  responsibility rather than AWS's.
- **Accepted trade-off:** Transcoding performance is constrained by Fargate
  task vCPU limits (max 16 vCPU per task). Very large source files (raw
  4K, 100GB+) may require task configuration tuning or chunked processing.
- **Accepted trade-off:** 4K output is omitted from the MVP ABR ladder.
  4K transcoding is compute-intensive and the added Fargate cost is not
  justified until the subscriber base warrants it.
- **Future:** Evaluate third-party transcoding providers (Mux, Cloudflare
  Stream) post-MVP when catalogue volume makes per-minute pricing comparison
  meaningful against Fargate compute cost.
- **Future:** Add DASH output alongside HLS when Widevine DRM support is
  introduced for Android and Chromecast clients.
