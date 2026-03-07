# Serverless Media Streaming Solution – Deployment Specification

## 1. Overview

This document specifies a serverless media streaming solution on AWS. The system ingests source media, transcodes it with AWS Elemental MediaConvert, stores outputs in S3, and delivers them via CloudFront. The streaming front-end is a static site hosted on S3.

| Component | AWS Service | Purpose |
|-----------|-------------|---------|
| Static site | S3 + CloudFront | Hosting the streaming web app (HTML, JS, CSS, assets) |
| Source media | S3 | Upload and storage of original (pre-transcode) media files (uploads from AWS only: CLI, SDK, Lambda, or other services) |
| Transcoding | AWS Elemental MediaConvert | Encode source media into streaming-friendly formats (e.g. HLS/DASH, multiple bitrates) |
| Output storage | S3 | Storage of transcoded outputs (manifests, segments, thumbnails) |
| Content delivery | CloudFront | CDN for low-latency, global delivery of static site and media |
| **Trigger** | Lambda + S3 events | **Required.** On new object in source bucket, validate and submit MediaConvert job. |
| **Catalog** | DynamoDB | **Required.** Store video metadata and manifest URLs; updated when transcoding jobs complete. |
| **Video list API** | API Gateway + Lambda | **Required.** API for the frontend to retrieve the list of available videos from the catalog. |

**Region:** eu-west-1 (or as per project Terraform default).

---

## 2. Architecture Summary

```
┌─────────────────┐     upload      ┌──────────────────┐
│  AWS (upload)   │ ──────────────► │  S3 Source       │
│  CLI/SDK/Lambda │                 │  (source media)  │
└─────────────────┘                 └────────┬─────────┘
       │                                      │ S3 event (required)
       │                                      ▼
       │                             ┌──────────────────┐     submit      ┌──────────────────┐
       │                             │  Lambda          │ ──────────────► │  MediaConvert    │
       │                             │  (trigger)       │                 │  (transcoding)   │
       │                             └──────────────────┘                 └────────┬─────────┘
       │                                      │                                      │ outputs
       │                             writes   │                              Lambda  │
       │                             catalog  │                              (job    ▼
       │                             (pending)│                              done)  ┌──────────────────┐
       │                             ┌────────▼────────┐     updates       ┌───────│  S3 Output       │
       │                             │  DynamoDB       │ ◄─────────────────│       │  (transcoded)    │
       │                             │  (catalog)      │  manifest_url,    │       └──────────────────┘
       │                             └────────▲────────┘   status=ready    │
       │  GET /videos (list)                  │                             │
       │  ───────────────────────────────────┼─────────────────────────────┘
       │                                      │  API Gateway + Lambda (reads catalog)
       │  HTTPS                               │
       ▼                                      │
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│  CloudFront: (1) S3 static site   (2) S3 transcoded media   [API: direct or custom domain]│
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

- **Static site:** S3 bucket with static website hosting (or origin for CloudFront). Serves the player and UI; calls the Video list API to get available videos.
- **Source media:** Dedicated S3 bucket for ingest. Uploads from AWS only. **Required:** S3 event on object create invokes Lambda to submit a MediaConvert job.
- **Trigger Lambda:** Invoked by S3 event; validates file and submits MediaConvert job. Required.
- **MediaConvert:** Reads from source S3, writes to output S3.
- **Output media:** Dedicated S3 bucket for transcoded HLS/DASH (and any thumbnails). Origin for media delivery.
- **Catalog:** DynamoDB table holding video metadata and manifest URLs. **Required:** Updated by a Lambda when MediaConvert jobs complete (via EventBridge).
- **Video list API:** API Gateway + Lambda that reads from the catalog and returns the list of available videos. **Required** so the frontend can display and play them.
- **CloudFront:** Origins for static site and transcoded media; API can be called directly or via a custom domain in front of API Gateway.

---

## 3. Component Specifications

### 3.1 S3 – Static Site Hosting

- **Purpose:** Host the streaming web application (HTML, JavaScript, CSS, images, etc.).
- **Requirements:**
  - One S3 bucket dedicated to static site content.
  - Enable **static website hosting** (or use as CloudFront origin only; then website hosting is optional).
  - **Block public access** if all access is via CloudFront (recommended). Use an Origin Access Control (OAC) or legacy Origin Access Identity (OAI) so only CloudFront can access the bucket.
  - **Bucket policy:** Allow `s3:GetObject` from the CloudFront distribution (via OAC/OAI).
  - **Default root object:** e.g. `index.html`; **error document** e.g. `index.html` or `404.html` for SPA-style routing if applicable.
  - **Encryption:** SSE-S3 (or SSE-KMS if required).
  - **Versioning:** Optional; useful for rollbacks.
- **Content:** Uploaded by CI/CD or manually; no server-side rendering.

### 3.2 S3 – Source Media (Ingest)

- **Purpose:** Store original, pre-transcode media files (e.g. master mezzanines).
- **Upload model:** Uploads happen **from AWS only** (e.g. AWS CLI, SDK, Lambda, EC2, or other AWS services). No browser or public upload; all access is IAM-authenticated.
- **Requirements:**
  - One S3 bucket dedicated to source media.
  - **Block public access**; access only via IAM:
    - **Uploaders:** IAM roles or users that need `s3:PutObject` (and optionally `s3:ListBucket`, `s3:GetObject`) on this bucket.
    - **MediaConvert** (via job role): `s3:GetObject` to read source files.
    - **Trigger Lambda** (required): read access to submit MediaConvert jobs.
  - **Lifecycle rules (optional):** Move to colder storage (e.g. Glacier) or delete after a retention period once transcoding is done and verified.
  - **Event notifications (required):** On `s3:ObjectCreated:*`, trigger Lambda to validate file and submit a MediaConvert job (see §4).

### 3.3 AWS Elemental MediaConvert – Transcoding

- **Purpose:** Transcode source media into formats and bitrates suitable for streaming (e.g. HLS, DASH, multiple resolutions).
- **Requirements:**
  - **Input:** Source media from S3 source bucket (path passed per job).
  - **Output:** All outputs to the dedicated S3 output bucket (see §3.4); use a prefix per job/asset (e.g. `outputs/{job-id}/` or `outputs/{asset-id}/`).
  - **IAM role:** MediaConvert job role must have:
    - `s3:GetObject` (and list if needed) on source bucket/prefix.
    - `s3:PutObject`, `s3:GetBucketLocation` on output bucket/prefix.
  - **Job settings:** Specify in spec or separate config:
    - Output groups: e.g. HLS (and optionally DASH), ABR ladder (e.g. 1080p, 720p, 480p, 360p).
    - Optional: thumbnail output to same or separate prefix in output bucket.
  - **Pricing:** Pay per output minute; no minimum commitment. Consider reserved queue (RQC) for predictable high volume.
  - **Region:** MediaConvert is available in selected regions; use eu-west-1 if supported, else specify (e.g. us-east-1) and document.

### 3.4 S3 – Output Storage (Transcoded Media)

- **Purpose:** Store all MediaConvert outputs (HLS/DASH manifests, segments, thumbnails).
- **Requirements:**
  - One S3 bucket dedicated to transcoded outputs.
  - **Block public access**; access only from CloudFront (and from MediaConvert for writes). Use OAC/OAI for CloudFront.
  - **Bucket policy:** Allow `s3:GetObject` from the CloudFront distribution (OAC/OAI).
  - **Structure:** e.g. `outputs/{job-id}/` or `outputs/{asset-id}/{format}/` so each asset has a stable base URL for the player.
  - **Encryption:** SSE-S3 or SSE-KMS.
  - **Caching:** Rely on CloudFront for caching; object metadata (e.g. Cache-Control) can be set by MediaConvert or a post-process step.
  - **Lifecycle (optional):** After a retention period, move to colder storage or delete.

### 3.5 CloudFront – Content Delivery

- **Purpose:** Serve the static site and transcoded media with low latency and high throughput.
- **Requirements:**
  - **Origins:**
    - **Origin 1 – Static site:** S3 bucket used for static site hosting (or its website endpoint). Use OAC (recommended) or OAI; no public bucket.
    - **Origin 2 – Media:** S3 bucket used for transcoded outputs; OAC/OAI. Optional path pattern (e.g. `/media/*`) to route only media to this origin.
  - **Behaviours:**
    - Default (or `/`) for static site: forward minimal headers; optional cache policy (e.g. cache static assets, short TTL or no-cache for `index.html` if needed).
    - Media path (e.g. `/media/*` or `/outputs/*`): long TTL (e.g. 1 year) for segments and manifests; consider query string forwarding only if needed for signed URLs.
  - **Viewer protocol policy:** Redirect HTTP to HTTPS (or HTTPS only).
  - **Price class:** Default (all edge locations) or restrict to reduce cost (e.g. EU + US).
  - **SSL:** Custom domain with ACM certificate (recommended) or default `*.cloudfront.net`.
  - **Optional:** Signed URLs or signed cookies for private content; restrict S3 and MediaConvert output to CloudFront only.

---

## 4. Transcoding Trigger (Required)

- **Flow:** Object created in source media bucket → S3 event → Lambda → validate (e.g. file type, size) → create MediaConvert job with input path and output prefix. On job creation, write a **pending** (or **processing**) record to the catalog so the frontend can show status.
- **Lambda:** IAM permissions for MediaConvert (`mediaconvert:CreateJob`, `mediaconvert:GetJob`), S3 read on source bucket, and DynamoDB write (catalog). Job settings from environment or config.
- **Idempotency:** Use a deterministic output prefix or job-naming rule (e.g. based on object key) to avoid duplicate jobs for the same file.
- **Failure handling:** On job failure, update catalog entry to **failed** (or notify via SNS/SQS); optionally support retry.

---

## 5. Catalog (Required)

- **Purpose:** Single source of truth for “available videos” so the frontend can list and play them.
- **Store:** DynamoDB table. Recommended attributes (adjust as needed): `video_id` (partition key), `title`, `source_key`, `manifest_url` (CloudFront URL to HLS/DASH manifest), `thumbnail_url` (optional), `status` (e.g. `pending` | `processing` | `ready` | `failed`), `created_at`, `updated_at`, `job_id`.
- **Writes:**
  - **Trigger Lambda:** On job submit, insert or update record with `status = processing` (and `job_id`).
  - **Job-completion Lambda:** Invoked by EventBridge when MediaConvert job state becomes COMPLETE (or ERROR). Update record with `status = ready`, `manifest_url`, optional `thumbnail_url`, and `updated_at`; on ERROR set `status = failed`.
- **Reads:** Video list API (Lambda) reads from this table to return the list of videos to the frontend (see §6).

---

## 6. Video List API (Required – Frontend Retrieves Available Videos)

- **Purpose:** Allow the frontend to retrieve the list of available videos (for display in a library or playlist).
- **Implementation:** API Gateway (REST or HTTP API) + Lambda. Lambda queries the DynamoDB catalog and returns a JSON list.
- **Endpoint:** e.g. `GET /videos` (or `GET /api/videos`) returning:
  - Array of items: `id`, `title`, `manifest_url`, `thumbnail_url` (optional), `status`, `created_at`. Only **ready** (or **processing** if showing “encoding…”) items should be returned, per product rules.
- **CORS:** Enable CORS on the API for the static site origin (CloudFront or S3 website URL) so the browser can call it.
- **Auth:** If the catalog is public (list of public videos), no auth required; otherwise use API key, Cognito, or IAM as needed.
- **Frontend usage:** The static site (JavaScript) calls this API on load (or on “library” view), then renders the list and uses `manifest_url` in the video player (e.g. HLS.js) for playback via CloudFront.

---

## 7. Data Flow (End-to-End)

1. **Upload:** Source media is uploaded from within AWS to the **source media** S3 bucket (e.g. AWS CLI, SDK, Lambda, or another AWS service using IAM).
2. **Trigger (required):** S3 event invokes Lambda, which validates the file, submits a MediaConvert job (input = source object, output = output bucket + prefix), and writes a **processing** catalog entry in DynamoDB.
3. **Transcode:** MediaConvert reads from source bucket and writes HLS/DASH (and optional thumbnails) to the **output** S3 bucket.
4. **Catalog update (required):** On job completion, EventBridge invokes a Lambda that updates the DynamoDB catalog (e.g. `status = ready`, `manifest_url`, `thumbnail_url`).
5. **List videos:** Frontend calls the Video list API (GET /videos). API Gateway invokes Lambda, which reads from DynamoDB and returns the list of available videos (with CloudFront manifest URLs).
6. **Playback:** User selects a video; the app loads the manifest URL from the catalog/API response. CloudFront serves the manifest and segments from the **output** S3 bucket; static assets from the **static site** S3 bucket.

---

## 8. Security Summary

- **S3:** All three buckets private; no public reads. Access only via IAM (MediaConvert, Lambda) and CloudFront (OAC/OAI).
- **CloudFront:** HTTPS only; optional signed URLs/cookies for private content.
- **API Gateway:** Enable CORS for the static site origin only; use API key or Cognito if the video list is not public.
- **IAM:** Least privilege for MediaConvert role, trigger Lambda, job-completion Lambda, list-api Lambda, and uploader identities; no wildcard `s3:*` on production buckets. DynamoDB access scoped to the catalog table.
- **Encryption:** SSE on all S3 buckets; TLS in transit (CloudFront ↔ viewer, CloudFront ↔ S3, API Gateway ↔ frontend).

---

## 9. Cost Considerations

- **S3:** Storage and request costs for three buckets; optional lifecycle to Glacier for source/output after retention.
- **MediaConvert:** Per output minute; optimize by resolution ladder and codec (e.g. H.264/HEVC).
- **CloudFront:** Data transfer out and requests; choose price class and cache TTLs to balance cost and freshness.
- **Lambda:** Trigger (on upload), job-completion (EventBridge), and Video list API; minimal cost at moderate scale.
- **DynamoDB:** On-demand or provisioned capacity for the catalog table; typically low.
- **API Gateway:** Per request and data transfer for the list API.

---

## 10. Deployment Checklist

- [ ] Create S3 bucket for static site; enable static hosting or configure as CloudFront origin only; set bucket policy for OAC/OAI.
- [ ] Create S3 bucket for source media; grant uploader IAM roles/users `s3:PutObject` (and list/get if needed); **enable S3 event notifications** to invoke the trigger Lambda on `ObjectCreated`.
- [ ] Create S3 bucket for transcoded output; set bucket policy for CloudFront and MediaConvert.
- [ ] Create IAM role for MediaConvert (S3 read source, S3 write output).
- [ ] **Create DynamoDB table** for the catalog (e.g. partition key `video_id`); set up indexes if needed for list queries.
- [ ] **Implement and deploy trigger Lambda** (S3 → MediaConvert, write catalog entry); set S3 event to invoke it; configure job template and IAM.
- [ ] **Implement and deploy job-completion Lambda** (EventBridge rule on MediaConvert job state change); update catalog with `manifest_url` and `status = ready` (or `failed`).
- [ ] **Implement and deploy Video list API:** API Gateway + Lambda that reads from DynamoDB and returns video list; enable CORS for the frontend origin.
- [ ] Create CloudFront distribution with two origins (static site, media); configure behaviours and SSL.
- [ ] Deploy static site content; ensure the frontend calls the Video list API (e.g. `GET /videos`) to display available videos and uses returned `manifest_url` for playback.
- [ ] Verify: upload a test file to source → trigger runs → job completes → catalog updated → frontend lists video and playback works via CloudFront.

---

## 11. References

- [S3 Static Website Hosting](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html)
- [S3 Event Notifications](https://docs.aws.amazon.com/AmazonS3/latest/userguide/NotificationHowTo.html)
- [AWS Elemental MediaConvert – User Guide](https://docs.aws.amazon.com/mediaconvert/latest/ug/)
- [EventBridge – MediaConvert job state changes](https://docs.aws.amazon.com/mediaconvert/latest/ug/cloudwatch_events.html)
- [API Gateway – CORS](https://docs.aws.amazon.com/apigateway/latest/developerguide/how-to-cors.html)
- [CloudFront – Serving content from S3](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/DownloadDistS3AndCustomOrigins.html)
- [CloudFront – Origin Access Control (OAC)](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html)
