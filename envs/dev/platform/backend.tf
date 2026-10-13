# bucket comes from the gitignored backend.hcl at the repo root:
#   terraform init -backend-config=../../../backend.hcl
terraform {
  backend "s3" {
    key          = "envs/dev/platform/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}
