output "aws_account_id" {
  description = "Current AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "Current AWS region"
  value       = data.aws_region.current.name
}

output "account_baseline_budget_name" {
  description = "AWS Budget name used for spend alerts."
  value       = aws_budgets_budget.monthly_cost.name
}

output "account_baseline_iam_groups" {
  description = "IAM groups created for baseline access structure."
  value = {
    admins     = aws_iam_group.admins.name
    powerusers = aws_iam_group.powerusers.name
    readonly   = aws_iam_group.readonly.name
  }
}
