data "terraform_remote_state" "storage" {
  backend = "s3"
  config = {
    bucket = "iu-aws-advanced-tf-remote-state"
    key    = "aws-advanced/01-storage/terraform.tfstate"
    region = var.aws_region
  }
}

locals {
  source_media_bucket_id  = data.terraform_remote_state.storage.outputs.source_media_bucket_id
  source_media_bucket_arn = data.terraform_remote_state.storage.outputs.source_media_bucket_arn
  output_media_bucket_id  = data.terraform_remote_state.storage.outputs.output_media_bucket_id
  mediaconvert_role_arn   = data.terraform_remote_state.storage.outputs.mediaconvert_role_arn
}
