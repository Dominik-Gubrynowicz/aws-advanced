# Serverless Media Streaming – Implementation Plan

This plan breaks the build into phases with clear dependencies, deliverables, and acceptance criteria. It aligns with [SERVERLESS-MEDIA-STREAMING-SPEC.md](./SERVERLESS-MEDIA-STREAMING-SPEC.md).

---

## Phase overview

| Phase | Name | Goal |
|-------|------|------|
| -1 | Account baseline | Budget alerting and IAM structure (who can access what). |
| 0 | Foundation | Repo, Terraform layout, naming, region. |
| 1 | Storage & IAM | S3 buckets (static, source, output) and MediaConvert role. |
| 2 | Catalog & transcoding pipeline | DynamoDB catalog, trigger Lambda, job-completion Lambda, S3 events, EventBridge. |
| 3 | Video list API | API Gateway + Lambda, CORS, frontend-callable GET /videos. |
| 4 | CDN & static site | CloudFront (static + media origins), static site bucket policy, deploy placeholder site. |
| 5 | Frontend & E2E | Player + list UI, wiring to API and CloudFront; E2E test. |

---

## Phase -1: Account baseline (budget + IAM) 

**Goal:** Before building the workload, set guardrails: **$1 spend alert** and a basic IAM user/group structure.

| # | Task | Deliverable | Notes |
|---|------|-------------|------|
| -1.1 | Configure budget alerting ($1) | Terraform code creating an AWS Budget with an **ACTUAL spend** notification at **$1** | Alerts to one or more email addresses; limit can be higher than $1 (the threshold is the alert). |
| -1.2 | IAM group structure | Terraform code creating IAM groups: **admins**, **powerusers**, **readonly** | Attach AWS managed policies by group; users assigned via variables. |
| -1.3 | IAM users (optional) | Terraform code creating IAM users and assigning them to groups | Prefer AWS IAM Identity Center (SSO) for humans; IAM users are acceptable for small/simple setups. |
| -1.4 | Password policy (recommended) | Terraform account password policy | Helps reduce weak console passwords if you use IAM users. |
| -1.5 | MFA expectations (recommended) | Document/require MFA for console users | Terraform can’t fully “force” MFA usage for all actions without careful policy design; at minimum, require it operationally. |

**Acceptance:** You receive an email when spend exceeds **$1** (after AWS Budgets evaluation delay), and your intended users/groups exist with the correct permissions.

---

## Phase 0: Foundation

**Goal:** Ready-to-use Terraform layout and conventions for the rest of the work.

| # | Task | Deliverable | Notes |
|---|------|-------------|--------|
| 0.1 | Confirm Terraform root and backend | `terraform init` with S3 backend (eu-west-1) | Use existing boilerplate; ensure backend.hcl points to eu-west-1. |
| 0.2 | Define naming and tags | `locals.tf` or `variables.tf`: project name, env, common tags | e.g. `project = "media-streaming"`, `environment = "dev"`. |
| 0.3 | Organise modules and repo layout | Follow the [Suggested directory structure](#suggested-directory-structure): `terraform/` (with optional `modules/`), `lambdas/<trigger|job-completion|list-videos>`, `frontend/`, `templates/mediaconvert/`, `scripts/` | Keeps IaC, application code, and config separate; Terraform references Lambda and template paths from this layout. |

**Acceptance:** Terraform plan runs successfully; naming and region are consistent across the plan.

---

## Phase 1: Storage & IAM

**Goal:** All S3 buckets and the MediaConvert IAM role exist; no events or Lambdas yet.

| # | Task | Deliverable | Spec ref |
|---|------|-------------|----------|
| 1.1 | S3 – static site bucket | Bucket, versioning optional, SSE-S3, block public access, no public ACLs | §3.1 |
| 1.2 | S3 – source media bucket | Bucket, block public access, SSE-S3; no event notifications yet | §3.2 |
| 1.3 | S3 – output (transcoded) bucket | Bucket, block public access, SSE-S3 | §3.4 |
| 1.4 | IAM role for MediaConvert | Role with policies: read source bucket, write output bucket; trust `mediaconvert.amazonaws.com` | §3.3 |
| 1.5 | (Optional) Lifecycle rules | Rules on source/output for transition/expiry if required | §3.2, §3.4 |

**Acceptance:** Three buckets and one MediaConvert role in place; Terraform apply succeeds; upload test to source bucket works with an IAM identity that has `s3:PutObject`.

---

## Phase 2: Catalog & transcoding pipeline

**Goal:** Upload → trigger Lambda → MediaConvert job → job-completion Lambda → catalog updated.

| # | Task | Deliverable | Spec ref |
|---|------|-------------|----------|
| 2.1 | DynamoDB catalog table | Table: partition key `video_id` (string); optional GSI e.g. `status-created_at` for list by status/date | §5 |
| 2.2 | MediaConvert job template | JSON or Terraform/local config: HLS (and optionally DASH), ABR ladder, output prefix pattern | §3.3 |
| 2.3 | Trigger Lambda – code | Handler: on S3 event, validate (type/size), create MediaConvert job, write catalog item `status=processing` with `job_id` | §4 |
| 2.4 | Trigger Lambda – infra | Lambda function, IAM role (S3 read source, MediaConvert CreateJob/GetJob, DynamoDB PutItem), env (bucket names, output prefix, job template ARN or inline) | §4 |
| 2.5 | S3 event → trigger Lambda | S3 event notification: `ObjectCreated` → invoke trigger Lambda (prefix/filter optional) | §3.2, §4 |
| 2.6 | Job-completion Lambda – code | Handler: on EventBridge event (MediaConvert job state COMPLETE/ERROR), update DynamoDB: `manifest_url`, `thumbnail_url`, `status=ready` or `failed` | §5 |
| 2.7 | Job-completion Lambda – infra | Lambda function, IAM role (DynamoDB UpdateItem, optional S3 GetObject for output path), EventBridge rule for `aws.mediaconvert.jobStateChange` | §5 |
| 2.8 | Idempotency | Trigger uses deterministic `video_id`/output prefix from object key (e.g. hash or key path) to avoid duplicate jobs | §4 |

**Acceptance:** Upload a test file to source bucket → trigger runs → MediaConvert job created → on completion, catalog has `status=ready` and `manifest_url`; failed jobs set `status=failed`.

---

## Phase 3: Video list API

**Goal:** Frontend can call an API to get the list of available videos.

| # | Task | Deliverable | Spec ref |
|---|------|-------------|----------|
| 3.1 | List API Lambda – code | Handler: scan or query DynamoDB catalog, return JSON array (id, title, manifest_url, thumbnail_url, status, created_at); filter by status if needed | §6 |
| 3.2 | List API Lambda – infra | Lambda function, IAM role (DynamoDB Read on catalog table) | §6 |
| 3.3 | API Gateway REST or HTTP API | Resource/method: `GET /videos` (or `GET /api/videos`) → integrate with list Lambda | §6 |
| 3.4 | CORS | CORS enabled for the static site origin (CloudFront URL or custom domain) | §6, §8 |
| 3.5 | Response shape | Document or OpenAPI: response schema for GET /videos so frontend can depend on it | §6 |

**Acceptance:** `GET <api-url>/videos` returns JSON list; browser from static site origin can call it (CORS); response includes `manifest_url` for ready videos.

---

## Phase 4: CDN & static site

**Goal:** CloudFront serves static site and transcoded media; static site bucket only accessible via CloudFront.

| # | Task | Deliverable | Spec ref |
|---|------|-------------|----------|
| 4.1 | OAC (or OAI) | Create OAC; attach to CloudFront (recommended) or use legacy OAI | §3.1, §3.4 |
| 4.2 | Static site bucket policy | Allow `s3:GetObject` from CloudFront distribution (via OAC/OAI) | §3.1 |
| 4.3 | Output bucket policy | Allow `s3:GetObject` from CloudFront; keep MediaConvert write access | §3.4 |
| 4.4 | CloudFront distribution | Origin 1: static site S3 (OAC); Origin 2: output S3 (OAC); path pattern for media (e.g. `/media/*` or `/outputs/*`) | §3.5 |
| 4.5 | Behaviours | Default → static site; media path → output origin, long TTL | §3.5 |
| 4.6 | HTTPS | Viewer protocol redirect HTTP→HTTPS; default or custom ACM cert | §3.5 |
| 4.7 | Static site content (placeholder) | Upload minimal `index.html` (and error doc); set default root and error document | §3.1 |
| 4.8 | Manifest URL format | Ensure `manifest_url` in catalog uses CloudFront base URL (not S3); job-completion Lambda or config uses distribution URL | §5, §7 |

**Acceptance:** Static site and media are served over HTTPS via CloudFront; direct S3 access is blocked; placeholder page loads.

---

## Phase 5: Frontend & end-to-end

**Goal:** Working UI: list of videos from API and playback via CloudFront.

| # | Task | Deliverable | Spec ref |
|---|------|-------------|----------|
| 5.1 | Frontend – list view | Page or section that calls GET /videos and renders titles (and optional thumbnails); show status (e.g. “Processing”) where needed | §6, §7 |
| 5.2 | Frontend – player | Use `manifest_url` from API with an HLS player (e.g. HLS.js); point to CloudFront base URL | §7 |
| 5.3 | API base URL in frontend | Config or build-time env for API base (API Gateway URL or custom domain); CORS already set in Phase 3 | §6 |
| 5.4 | E2E test | 1) Upload test asset to source bucket. 2) Wait for job complete (poll catalog or EventBridge). 3) Call GET /videos and confirm entry. 4) Open site, select video, verify playback | §10 |

**Acceptance:** Upload → transcode → catalog updated → frontend lists video → playback works via CloudFront.

---

## Dependency graph (high level)

```
Phase 0 (Foundation)
    ↓
Phase 1 (Storage & IAM)  ← no dependency on 2–5
    ↓
Phase 2 (Catalog & pipeline)  ← needs 1 (buckets, MediaConvert role)
    ↓
Phase 3 (Video list API)      ← needs 2 (DynamoDB catalog)
Phase 4 (CDN & static site)   ← needs 1 (buckets)
    ↓
Phase 5 (Frontend & E2E)       ← needs 3 (API), 4 (CloudFront, manifest URLs)
```

Phase 3 and Phase 4 can be done in parallel after Phase 2 and Phase 1 respectively.

---

## Suggested directory structure

Layout for the repo that separates Terraform, Lambda code, frontend, job templates, and config. Adjust to taste (e.g. monorepo vs separate repos for frontend/lambdas).

```
aws-advanced/
├── docs/                          # Specification and planning
│   ├── SERVERLESS-MEDIA-STREAMING-SPEC.md
│   └── IMPLEMENTATION-PLAN.md
│
├── terraform/                     # Terraform root (existing)
│   ├── backend.tf
│   ├── backend.hcl.example
│   ├── versions.tf
│   ├── variables.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   ├── modules/                   # Optional: split by component
│   │   ├── s3-buckets/
│   │   ├── mediaconvert/
│   │   ├── catalog/
│   │   ├── lambdas/
│   │   ├── api/
│   │   └── cloudfront/
│   └── ...
│
├── lambdas/                      # Lambda source code (each function)
│   ├── trigger/                  # S3 → MediaConvert + catalog (processing)
│   │   ├── main.py               # or index.js / handler.go
│   │   ├── requirements.txt     # Python deps (or package.json, go.mod)
│   │   └── (tests)
│   ├── job-completion/           # EventBridge → update catalog (ready/failed)
│   │   ├── main.py
│   │   ├── requirements.txt
│   │   └── (tests)
│   └── list-videos/              # API Gateway → GET /videos
│       ├── main.py
│       ├── requirements.txt
│       └── (tests)
│
├── frontend/                     # Static site (player + list UI)
│   ├── index.html
│   ├── app.js                    # or React/Vue/Svelte app
│   ├── styles/
│   ├── assets/
│   ├── package.json              # if using a bundler
│   └── (build output → deploy to static site bucket)
│
├── templates/                    # MediaConvert and other config
│   ├── mediaconvert/
│   │   ├── job-template-hls.json # HLS output group, ABR ladder
│   │   └── (optional) job-template-dash.json
│   └── (optional) openapi.yaml   # API spec for GET /videos
│
├── scripts/                      # Operational and test helpers
│   ├── upload-test-asset.sh      # Upload a sample file to source bucket
│   ├── e2e-check.sh              # Poll catalog, call API, basic checks
│   └── (optional) deploy-frontend.sh
│
├── .gitignore
└── README.md
```

**Notes by area**

| Area | Purpose |
|------|--------|
| **terraform/** | IaC only. References Lambda zip paths (e.g. `lambdas/trigger`) for `archive_file` or `null_resource` to build and upload. |
| **lambdas/** | One folder per function; same runtime (e.g. Python 3.12) recommended. Terraform builds zips from these dirs or use CI to build and pass artifact path. |
| **frontend/** | Plain HTML/JS or SPA; build step can output to `frontend/dist/`; deploy `dist/` (or equivalent) to the static site S3 bucket. |
| **templates/** | MediaConvert job JSON (and optional OpenAPI) live here; Terraform or Lambda can read them via `file()` or bundle into Lambda. |
| **scripts/** | Not deployed; used for manual upload, E2E checks, or local dev. |

**Terraform ↔ code locations**

- Trigger Lambda zip: e.g. `lambdas/trigger` → Terraform `source_code_hash` / `filename` from that directory.
- Job-completion Lambda zip: `lambdas/job-completion`.
- List-videos Lambda zip: `lambdas/list-videos`.
- Static site deploy: sync `frontend/` (or `frontend/dist/`) to the static site bucket; can be a script or CI step, not necessarily Terraform.
- Job template: Terraform `file("${path.module}/../templates/mediaconvert/job-template-hls.json")` or Lambda env pointing to bundled template.

Phase 0 task 0.3 can use this layout when organising modules and naming resources.

---

## Suggested Terraform apply order

1. **Phase -1:** Apply once (budget alert + IAM structure).
2. **Phase 0–1:** Apply once (buckets, MediaConvert role).
3. **Phase 2:** Apply (DynamoDB, trigger Lambda, S3 event, job-completion Lambda, EventBridge).
4. **Phase 3:** Apply (list Lambda, API Gateway, CORS).
5. **Phase 4:** Apply (OAC, bucket policies, CloudFront).
6. **Phase 5:** No Terraform for frontend code; deploy static assets to static site bucket (e.g. `aws s3 sync` or CI/CD).

---

## Risks and mitigations

| Risk | Mitigation |
|------|-------------|
| MediaConvert not in eu-west-1 | Check [MediaConvert regions](https://docs.aws.amazon.com/mediaconvert/latest/ug/regions.html); if not available, use closest (e.g. eu-west-2) and document; consider cross-region S3 if needed. |
| EventBridge payload for job completion | Use documented [MediaConvert event shape](https://docs.aws.amazon.com/mediaconvert/latest/ug/cloudwatch_events.html); parse `detail.jobId` and `detail.status`. |
| CORS / API URL in frontend | Set CORS to CloudFront origin; use same origin for API (e.g. /api/*) or document API Gateway URL for frontend config. |
| Large catalog list | Add pagination to GET /videos (query params) and DynamoDB query/scan with limit; optional GSI for sort order. |

---

## Definition of done (full solution)

- [ ] All Phase 0–5 acceptance criteria met.
- [ ] Spec deployment checklist (§10) satisfied.
- [ ] One successful E2E run: upload → transcode → list in UI → playback.
- [ ] README or runbook: how to upload, how to find catalog state, how to open frontend and API URLs.
