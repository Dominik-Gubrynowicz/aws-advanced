output "static_site_bucket_id" {
  description = "ID of the static site bucket"
  value       = aws_s3_bucket.static_site.id
}

output "static_site_bucket_arn" {
  description = "ARN of the static site bucket"
  value       = aws_s3_bucket.static_site.arn
}

output "static_site_bucket_regional_domain_name" {
  description = "Regional domain name of the static site bucket"
  value       = aws_s3_bucket.static_site.bucket_regional_domain_name
}

output "source_media_bucket_id" {
  description = "ID of the source media bucket"
  value       = aws_s3_bucket.source.id
}

output "source_media_bucket_arn" {
  description = "ARN of the source media bucket"
  value       = aws_s3_bucket.source.arn
}

output "output_media_bucket_id" {
  description = "ID of the output media bucket"
  value       = aws_s3_bucket.output.id
}

output "output_media_bucket_arn" {
  description = "ARN of the output media bucket"
  value       = aws_s3_bucket.output.arn
}

output "output_media_bucket_regional_domain_name" {
  description = "Regional domain name of the output media bucket"
  value       = aws_s3_bucket.output.bucket_regional_domain_name
}

output "mediaconvert_role_arn" {
  description = "ARN of the MediaConvert IAM role"
  value       = aws_iam_role.mediaconvert.arn
}
