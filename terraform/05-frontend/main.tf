# Path to the frontend code
locals {
  frontend_dir = "${path.module}/../../frontend"
}

# Upload index.html (no replacement needed, it uses relative API path)
resource "aws_s3_object" "index" {
  bucket       = local.static_site_bucket_id
  key          = "index.html"
  content_type = "text/html"
  source       = "${local.frontend_dir}/index.html"
  etag         = filemd5("${local.frontend_dir}/index.html")
}
