############################################
# CloudFront Origin Access Control
############################################
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${local.name_prefix}-oac"
  description                       = "OAC for static site and media output"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

############################################
# CloudFront Cache Policies
############################################
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

############################################
# CloudFront Distribution
############################################
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  # Origin 1: Static Site
  origin {
    domain_name              = local.static_site_bucket_regional_domain_name
    origin_id                = "StaticSite"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  # Origin 2: Media Output
  origin {
    domain_name              = local.output_media_bucket_regional_domain_name
    origin_id                = "MediaOutput"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  # Origin 3: API Gateway
  origin {
    domain_name = local.api_domain_name
    origin_id   = "APIGateway"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default cache behavior -> Static Site
  default_cache_behavior {
    target_origin_id       = "StaticSite"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]

    # Managed CachingOptimized Policy
    cache_policy_id = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  # Ordered cache behavior -> Media Output
  ordered_cache_behavior {
    path_pattern           = "/outputs/*"
    target_origin_id       = "MediaOutput"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]

    # Managed CachingOptimized Policy
    cache_policy_id = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  # Ordered cache behavior -> API Gateway
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "APIGateway"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]

    # Managed CachingDisabled Policy so all requests go to API
    cache_policy_id = data.aws_cloudfront_cache_policy.caching_disabled.id

    # Managed AllViewerExceptHostHeader Policy to forward everything (except Host)
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${local.name_prefix}-cdn"
  }
}



############################################
# S3 Bucket Policies (CloudFront OAC)
############################################

data "aws_iam_policy_document" "static_site_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${local.static_site_bucket_arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cdn.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "static_site" {
  bucket = local.static_site_bucket_id
  policy = data.aws_iam_policy_document.static_site_policy.json
}

data "aws_iam_policy_document" "output_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${local.output_media_bucket_arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cdn.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "output" {
  bucket = local.output_media_bucket_id
  policy = data.aws_iam_policy_document.output_policy.json
}
