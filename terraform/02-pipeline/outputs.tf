output "catalog_table_name" {
  description = "Name of the DynamoDB catalog table"
  value       = aws_dynamodb_table.catalog.name
}

output "catalog_table_arn" {
  description = "ARN of the DynamoDB catalog table"
  value       = aws_dynamodb_table.catalog.arn
}
