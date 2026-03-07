provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aws-advanced"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix = "account-baseline-${var.environment}"
}

############################################
# Budget alerting: notify when spend >= $1
############################################

resource "aws_budgets_budget" "monthly_cost" {
  name         = "${local.name_prefix}-monthly-cost"
  budget_type  = "COST"
  limit_unit   = "USD"
  limit_amount = tostring(var.monthly_budget_limit_usd)
  time_unit    = "MONTHLY"

  cost_types {
    include_credit             = true
    include_discount           = true
    include_other_subscription = true
    include_recurring          = true
    include_refund             = true
    include_subscription       = true
    include_support            = true
    include_tax                = true
    include_upfront            = true
    use_amortized              = false
    use_blended                = false
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 1
    threshold_type             = "ABSOLUTE_VALUE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_emails
  }
}

############################################
# IAM structure: groups + (optional) users
############################################

resource "aws_iam_group" "admins" {
  name = "${local.name_prefix}-admins"
}

resource "aws_iam_group" "powerusers" {
  name = "${local.name_prefix}-powerusers"
}

resource "aws_iam_group" "readonly" {
  name = "${local.name_prefix}-readonly"
}

resource "aws_iam_group_policy_attachment" "admins_admin_access" {
  group      = aws_iam_group.admins.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_group_policy_attachment" "powerusers_power_user_access" {
  group      = aws_iam_group.powerusers.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_group_policy_attachment" "readonly_read_only_access" {
  group      = aws_iam_group.readonly.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_user" "admins" {
  for_each = toset(var.iam_admin_users)
  name     = each.value
}

resource "aws_iam_user" "powerusers" {
  for_each = toset(var.iam_power_users)
  name     = each.value
}

resource "aws_iam_user" "readonly" {
  for_each = toset(var.iam_readonly_users)
  name     = each.value
}

resource "aws_iam_user_group_membership" "admins" {
  for_each = aws_iam_user.admins
  user     = each.value.name
  groups   = [aws_iam_group.admins.name]
}

resource "aws_iam_user_group_membership" "powerusers" {
  for_each = aws_iam_user.powerusers
  user     = each.value.name
  groups   = [aws_iam_group.powerusers.name]
}

resource "aws_iam_user_group_membership" "readonly" {
  for_each = aws_iam_user.readonly
  user     = each.value.name
  groups   = [aws_iam_group.readonly.name]
}

resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_numbers                = true
  require_uppercase_characters   = true
  require_symbols                = true
  allow_users_to_change_password = true
  hard_expiry                    = false
  max_password_age               = 90
  password_reuse_prevention      = 24
}
