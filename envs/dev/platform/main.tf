module "platform" {
  source = "../../../modules/eks-platform"

  cluster_name = local.infra.cluster_name
  region       = local.infra.region
  vpc_id       = local.infra.vpc_id

  aws_lb_controller_chart_version = var.aws_lb_controller_chart_version
  argocd_chart_version            = var.argocd_chart_version
  argocd_apps_chart_version       = var.argocd_apps_chart_version
  gitops_repo_url                 = var.gitops_repo_url

  grafana_admin_password = var.grafana_admin_password
  telegram_bot_token     = var.telegram_bot_token
  telegram_chat_id       = var.telegram_chat_id
}
