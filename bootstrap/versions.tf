terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.68"
    }
  }

  # State for this stack is local on purpose: it creates the bucket that every
  # other stack uses. See README for optionally migrating it into the bucket.
}

provider "aws" {
  region = var.region

  default_tags {
    tags = var.tags
  }
}
