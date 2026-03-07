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

locals {
  static_site_bucket_id                   = data.terraform_remote_state.storage.outputs.static_site_bucket_id
  static_site_bucket_arn                  = data.terraform_remote_state.storage.outputs.static_site_bucket_arn
  static_site_bucket_regional_domain_name = data.terraform_remote_state.storage.outputs.static_site_bucket_regional_domain_name

  output_media_bucket_id                   = data.terraform_remote_state.storage.outputs.output_media_bucket_id
  output_media_bucket_arn                  = data.terraform_remote_state.storage.outputs.output_media_bucket_arn
  output_media_bucket_regional_domain_name = data.terraform_remote_state.storage.outputs.output_media_bucket_regional_domain_name

  api_domain_name = data.terraform_remote_state.api.outputs.api_domain_name
}
