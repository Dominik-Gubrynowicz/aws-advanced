output "api_endpoint" {
  description = "The HTTP API Gateway endpoint URL"
  value       = aws_apigatewayv2_api.video_api.api_endpoint
}

# The domain name without schema for CloudFront
output "api_domain_name" {
  description = "The domain name of the API Gateway"
  value       = replace(aws_apigatewayv2_api.video_api.api_endpoint, "/^https?://([^/]*).*/", "$1")
}
