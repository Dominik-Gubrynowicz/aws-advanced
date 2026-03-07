data "terraform_remote_state" "pipeline" {
  backend = "s3"
  config = {
    bucket = "iu-aws-advanced-tf-remote-state"
    key    = "aws-advanced/02-pipeline/terraform.tfstate"
    region = var.aws_region
  }
}

locals {
  catalog_table_name = data.terraform_remote_state.pipeline.outputs.catalog_table_name
  catalog_table_arn  = data.terraform_remote_state.pipeline.outputs.catalog_table_arn
}
