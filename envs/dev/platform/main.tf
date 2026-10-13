module "platform" {
  source = "../../../modules/eks-platform"

  cluster_name = local.infra.cluster_name
  region       = local.infra.region
  vpc_id       = local.infra.vpc_id

  aws_lb_controller_chart_version = var.aws_lb_controller_chart_version
  kyverno_chart_version           = var.kyverno_chart_version
}
