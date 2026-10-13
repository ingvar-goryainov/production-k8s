data "terraform_remote_state" "infra" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = var.infra_state_key
    region = var.state_region
  }
}

locals {
  infra = data.terraform_remote_state.infra.outputs

  # Short-lived token for the cluster-admin role, assumed with the caller's AWS_PROFILE credentials.
  eks_token_exec = {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", local.infra.cluster_name,
      "--region", local.infra.region,
      "--role-arn", local.infra.cluster_admin_role_arn,
    ]
  }
}

provider "kubernetes" {
  host                   = local.infra.cluster_endpoint
  cluster_ca_certificate = base64decode(local.infra.cluster_certificate_authority_data)

  exec {
    api_version = local.eks_token_exec.api_version
    command     = local.eks_token_exec.command
    args        = local.eks_token_exec.args
  }
}

provider "helm" {
  kubernetes = {
    host                   = local.infra.cluster_endpoint
    cluster_ca_certificate = base64decode(local.infra.cluster_certificate_authority_data)
    exec                   = local.eks_token_exec
  }
}
