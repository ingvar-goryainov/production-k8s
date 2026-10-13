data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  cluster_arn = "arn:${data.aws_partition.current.partition}:eks:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:cluster/${var.name}"
}

# Dedicated cluster-admin role, granted AmazonEKSClusterAdminPolicy via an access entry (eks.tf).
# The trusted principals must be explicitly configured; no account-wide fallback is allowed.
data "aws_iam_policy_document" "cluster_admin_assume" {
  statement {
    # TagSession: needed when the caller's session (e.g. SSO/SAML) carries transitive session tags.
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "AWS"
      identifiers = var.admin_trusted_principal_arns
    }
  }
}

resource "aws_iam_role" "cluster_admin" {
  name               = "${var.name}-admin"
  description        = "Kubernetes cluster-admin for EKS cluster ${var.name}"
  assume_role_policy = data.aws_iam_policy_document.cluster_admin_assume.json
}

# AWS-side permissions only (aws eks update-kubeconfig / describe-cluster);
# Kubernetes permissions come from the access entry.
data "aws_iam_policy_document" "cluster_admin" {
  statement {
    actions   = ["eks:DescribeCluster"]
    resources = [local.cluster_arn]
  }

  statement {
    actions   = ["eks:ListClusters"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "cluster_admin" {
  name   = "eks-describe"
  role   = aws_iam_role.cluster_admin.id
  policy = data.aws_iam_policy_document.cluster_admin.json
}
