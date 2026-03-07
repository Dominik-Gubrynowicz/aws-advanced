# S3 backend - use partial config and pass via -backend-config or backend.hcl
# Example: terraform init -backend-config=backend.hcl
# Or:     terraform init -backend-config="bucket=MY_BUCKET" -backend-config="key=path/to/state" -backend-config="region=eu-west-1"
terraform {
  backend "s3" {}
}
