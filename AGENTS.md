# AWS Advanced Infrastructure Configuration

## Architecture
The infrastructure is organized into standalone Terraform projects rather than a single monolithic directory. This allows for clear boundaries of responsibility, smaller state files, and more targeted deployments.

### Data Exchange Between Projects
When one Terraform project depends on the outputs of another (e.g., the root project requiring infrastructure created by the `account` project), you **must** use `terraform_remote_state` data sources to fetch this information.

**Do not** use monolithic modules or cross-directory local state access.

#### Example
If the environment requires the baseline budget name from the account project:

```hcl
data "terraform_remote_state" "account" {
  backend = "s3"
  config = {
    bucket = "iu-aws-advanced-tf-remote-state"
    key    = "aws-advanced/account/terraform.tfstate"
    region = "eu-west-1"
  }
}

# Accessing the output:
# data.terraform_remote_state.account.outputs.account_baseline_budget_name
```

## State Management and Locking
We use native S3 state locking (`use_lockfile = true`) for all Terraform state backends. 
**Do not** configure or use DynamoDB tables for state locking.
