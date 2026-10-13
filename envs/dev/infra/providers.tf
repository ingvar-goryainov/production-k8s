# Credentials come from the environment (AWS_PROFILE), never hardcoded.
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "kubernetes-in-production"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
    }
  }
}
