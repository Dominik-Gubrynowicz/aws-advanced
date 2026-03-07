variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "budget_alert_emails" {
  description = "Email addresses to receive AWS Budget alerts."
  type        = list(string)
  default     = []
}

variable "monthly_budget_limit_usd" {
  description = "Monthly budget limit in USD. Alerting can still be set at $1 threshold."
  type        = number
  default     = 1
}

variable "iam_admin_users" {
  description = "IAM usernames to create and assign to the admins group."
  type        = list(string)
  default     = []
}

variable "iam_power_users" {
  description = "IAM usernames to create and assign to the powerusers group."
  type        = list(string)
  default     = []
}

variable "iam_readonly_users" {
  description = "IAM usernames to create and assign to the readonly group."
  type        = list(string)
  default     = []
}

variable "github_repository" {
  description = "GitHub repository name (e.g., owner/repo)"
  type        = string
}
