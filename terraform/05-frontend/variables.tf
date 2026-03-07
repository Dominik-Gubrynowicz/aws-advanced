variable "aws_region" {
  description = "The AWS Region to deploy to"
  type        = string
  default     = "eu-west-1"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "aws-advanced"
}

variable "environment" {
  description = "Environment (dev, prod, etc)"
  type        = string
  default     = "dev"
}
