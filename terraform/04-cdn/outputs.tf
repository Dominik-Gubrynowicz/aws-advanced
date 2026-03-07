output "cloudfront_domain" {
  description = "The CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.cdn.domain_name
}
