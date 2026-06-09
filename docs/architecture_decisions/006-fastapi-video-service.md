# ADR-006: FastAPI for the Video Service API Layer

## Status
Accepted

## Date
06-06-2026

## Context
The platform requires a Video Service responsible for four specific
concerns: video metadata management, upload orchestration (pre-signed S3
URL generation), transcoding job tracking, and playback URL preparation
ahead of signed cookie issuance by the Playback Service.

The service must:
- Expose a REST API consumed by the frontend and other internal services
- Integrate with AWS S3 (pre-signed URL generation), SQS (job submission),
  and CloudWatch Logs (observability)
- Run as a containerised workload on ECS Fargate
- Produce OpenAPI documentation — the API contract is the primary
  integration surface for other services during MVP development

A key constraint on framework selection is the broader project objective.
This platform exists to demonstrate cloud architecture, infrastructure
automation, CI/CD pipeline design, and distributed systems thinking —
not application framework sophistication. The framework choice should
minimise API development complexity so engineering effort remains focused
on the infrastructure layer.

The Video Service sits in the following request path:

```
Client / Internal Service
          │
          ▼
    ALB → ECS (Video Service — FastAPI)
          │
          ├── POST /videos     → generates S3 pre-signed upload URL
          │                      submits job to SQS
          │
          ├── GET  /videos     → returns catalog metadata
          │
          ├── GET  /videos/{id}        → returns single title metadata
          │
          └── GET  /videos/{id}/status → returns transcoding job status
```

## Alternatives Considered

### Flask

Python micro-framework with a large ecosystem and broad community adoption.

**Evaluated and rejected:**

- No native async support — Flask's synchronous request handling requires
  additional tooling (gevent, gunicorn workers) to handle concurrent
  requests efficiently in a containerised environment
- No built-in request validation — Marshmallow or similar must be added
  and configured separately, increasing boilerplate for a typed REST API
- OpenAPI documentation requires flask-smorest or flasgger — third-party
  integrations that add configuration overhead
- For an API with clearly defined request/response schemas and AWS SDK
  integration, Flask's minimalism becomes friction rather than flexibility

### Node.js + Express

JavaScript runtime with a mature ecosystem for microservice APIs.

**Evaluated and rejected:**

- Introduces a second language runtime into a platform where the remaining
  Python services (auth, billing, user) share tooling, base images, and
  CI/CD patterns — the operational cost of maintaining a Node.js service
  alongside Python services is not justified for MVP scope
- TypeScript is required to achieve the type safety and validation that
  FastAPI provides natively — adding build tooling complexity
- AWS SDK for JavaScript v3 is well-supported but adds a separate
  dependency tree from the Python boto3 ecosystem used across other services

### Go

Compiled, statically typed language with excellent performance
characteristics for concurrent API workloads.

Go is used in this platform for the **Playback Service** — the high-
throughput token issuance endpoint where Go's concurrency model and raw
performance justify the additional implementation complexity.

**Not selected for the Video Service:**

- Video metadata operations and job tracking are not performance-critical
  paths — the bottleneck is S3 and SQS latency, not API processing time
- Go's verbosity increases development time for CRUD-style REST APIs
  relative to Python frameworks
- OpenAPI generation in Go requires additional tooling (swaggo, ogen)
  versus FastAPI's native generation

The Go / FastAPI split is intentional — each language is applied where its
characteristics provide a demonstrable benefit rather than using one
language uniformly across all services.

### FastAPI ✅ Selected

Python async web framework with native OpenAPI generation, Pydantic-based
request validation, and strong typing support.

**Selected for the following reasons:**

- Native OpenAPI 3.0 and Swagger UI generation from route definitions and
  Pydantic models — no additional configuration or third-party libraries
- Pydantic v2 models provide request validation, response serialisation,
  and JSON schema generation in a single definition
- Native async support (`async def`) handles concurrent S3 pre-signed URL
  generation and SQS job submission without blocking
- Shares language runtime, base Docker image, boto3 dependency, and CI/CD
  patterns with other Python services in the platform
- Minimal boilerplate for a typed REST API — keeps development velocity
  high during MVP without sacrificing structure or documentation quality

## Decision

Implement the Video Service using **FastAPI**, deployed as a Docker
container on ECS Fargate.

The service exposes the following endpoints:

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/videos` | Accepts metadata, returns pre-signed S3 upload URL, submits SQS transcode job |
| `GET` | `/videos` | Returns paginated content catalog |
| `GET` | `/videos/{id}` | Returns single title metadata and asset URLs |
| `GET` | `/videos/{id}/status` | Returns transcoding job status from the video metadata datastore |

FastAPI is applied to the Video Service specifically. The **Playback
Service** uses Go for performance-critical token issuance. This reflects a
deliberate per-service language selection based on workload characteristics
rather than a uniform platform-wide framework choice.

## Consequences

- **Positive:** Automatic OpenAPI 3.0 documentation and Swagger UI
  available at `/docs` — provides a live, testable API contract for
  frontend and service integration during MVP development.
- **Positive:** Pydantic models enforce strict request validation and
  response serialisation with no additional libraries.
- **Positive:** Shared Python runtime with the Video Service ecosystem,
  common base images, reusable CI/CD patterns, and consistent boto3 AWS SDK
  usage across Python-based workloads.
- **Positive:** Native async support handles concurrent AWS API calls
  (S3, SQS) without blocking the event loop.
- **Accepted trade-off:** Python is not the highest-performance language
  for API throughput. This is acceptable because the Video Service is not
  a high-throughput path — upload orchestration and job tracking are
  low-frequency operations relative to playback.
- **Accepted trade-off:** The platform uses two languages (Python and Go)
  across its services. This is a deliberate, documented decision rather
  than inconsistency — each language is applied where its characteristics
  are the right fit for the workload.
- **Future:** If the Video Service metadata API becomes a high-traffic path
  post-MVP (e.g. catalog browsing at scale), evaluate migration to Go or
  a dedicated read-optimised catalog service backed by a search index.