# The association is created by the aws-ebs-csi-driver add-on (see eks.tf).
module "ebs_csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.9"

  name = "${var.name}-ebs-csi"

  attach_aws_ebs_csi_policy = true
}

# The service account itself is created by the Helm chart in the platform stack.
module "aws_lb_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.9"

  name = "${var.name}-aws-lbc"

  attach_aws_lb_controller_policy = true

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
    }
  }
}
