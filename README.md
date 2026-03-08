# AWS Advanced: Serverless Media Streaming Platform

A serverless video on demand (VOD) streaming platform built on AWS. This project provides an ecosystem for uploading videos, automatically transcoding them into HLS (HTTP Live Streaming) format, cataloging them in a database, and serving them through a scalable CDN to a custom web frontend.

## Architecture Highlights

This project relies heavily on a serverless and managed services architecture:
- **Storage**: Amazon S3 (Source Bucket, Output Bucket, Static Web Hosting).
- **Processing**: AWS Elemental MediaConvert for reliable, scalable video transcoding into adaptive bitrate HLS streams.
- **Compute**: AWS Lambda (Python) triggered by S3 events and EventBridge rules to orchestrate transcoding jobs and handle API requests.
- **Database**: Amazon DynamoDB for maintaining a catalog of video metadata and status.
- **Delivery**: Amazon CloudFront to reliably deliver video segments and the frontend application globally.
- **API**: Amazon API Gateway to serve video metadata to the frontend.
- **Infrastructure as Code (IaC)**: Terraform, organized into phased stateful modules for robust deployment.
- **CI/CD**: GitHub Actions utilizing AWS OIDC integration for password-less, short-lived credential deployment.

## Directory Structure

The repository is structured to separate infrastructure layers and application logic:

```
.
├── .github/
│   └── workflows/          # GitHub Actions CI/CD pipelines
├── frontend/               # Web application (HTML/CSS/JS)
├── lambdas/                # Python serverless function code
│   ├── trigger-transcode/  # Triggers MediaConvert on video upload
│   ├── job-completion/     # Updates DynamoDB when transcoding finishes
│   └── list-videos/        # API backend for fetching video library
└── terraform/              # Infrastructure as Code modules
    ├── account/            # Account baseline (Billing, IAM, OIDC)
    ├── 01-storage/         # S3 buckets and baseline IAM Roles
    ├── 02-pipeline/        # MediaConvert, DynamoDB, and internal Event Lambda
    ├── 03-api/             # API Gateway and List Videos Lambda
    ├── 04-cdn/             # CloudFront distributions and bucket policies
    └── 05-frontend/        # S3 frontend upload and environment configuration
```

## Infrastructure Phases & Deployment

Deployments are strictly broken down into sequential phases to manage dependencies tightly. You can deploy these locally or rely on the GitHub Actions pipeline.

1. **`account/`** - Configures account budgets, password policies, user IAM groups, and the GitHub OIDC provider.
2. **`01-storage/`** - Creates the S3 buckets used across the application.
3. **`02-pipeline/`** - Sets up the transcoding pipeline, DynamoDB, the MediaConvert service role, and triggers.
4. **`03-api/`** - provisions the API Gateway and backing Lambda to list the videos.
5. **`04-cdn/`** - Creates the CloudFront distribution to serve the Site and HLS media with an Origin Access Control (OAC).
6. **`05-frontend/`** - Reads API Gateway and S3 endpoints, injects them into the `index.html`, and uploads the final web assets to the S3 web bucket.

## Usage Guide

1. **Frontend App**: Visit your CloudFront distribution URL to view the video library. By default, it will be empty.
2. **Upload a Video**: Upload an `.mp4` video to your S3 Source media bucket directly.
   ```bash
   aws s3 cp my-video.mp4 s3://<YOUR_SOURCE_BUCKET_NAME>/
   ```
3. **Processing**: The `trigger-transcode` Lambda automatically fires, dispatching a job to AWS Elemental MediaConvert.
4. **Completion**: Once MediaConvert finishes, it emits an EventBridge event. The `job-completion` Lambda updates your DynamoDB item status to `READY` and attaches the HLS manifest URL.
5. **Streaming**: Refresh your frontend app. The video card will appear, allowing you to seamlessly stream the Adaptive Bitrate HLS video directly from the CDN.

## GitHub Actions CI/CD

The `.github/workflows/deploy.yml` completely automates the release process when merging to `main`. It uses the centralized `.github/workflows/terraform-apply.yml` to assume the AWS Role via OpenID Connect (OIDC) and run `terraform apply` across all phases securely.
