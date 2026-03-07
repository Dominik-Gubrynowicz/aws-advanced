data "terraform_remote_state" "storage" {
  backend = "s3"
  config = {
    bucket = "iu-aws-advanced-tf-remote-state"
    key    = "aws-advanced/01-storage/terraform.tfstate"
    region = var.aws_region
  }
}

data "terraform_remote_state" "api" {
  backend = "s3"
  config = {
    bucket = "iu-aws-advanced-tf-remote-state"
    key    = "aws-advanced/03-api/terraform.tfstate"
    region = var.aws_region
  }
}

data "terraform_remote_state" "cdn" {
  backend = "s3"
  config = {
    bucket = "iu-aws-advanced-tf-remote-state"
    key    = "aws-advanced/04-cdn/terraform.tfstate"
    region = var.aws_region
  }
}

locals {
  name_prefix           = "${var.project}-${var.environment}"
  static_site_bucket_id = data.terraform_remote_state.storage.outputs.static_site_bucket_id
  api_domain_name       = data.terraform_remote_state.api.outputs.api_domain_name
  cloudfront_domain     = data.terraform_remote_state.cdn.outputs.cloudfront_domain
}
