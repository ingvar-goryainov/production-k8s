module "infra" {
  source = "../../../modules/eks-infra"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version
  addon_versions     = var.addon_versions

  vpc_cidr = var.vpc_cidr
  azs      = var.azs

  admin_trusted_principal_arns = var.admin_trusted_principal_arns
  deletion_protection          = var.deletion_protection

  enable_client_vpn = var.enable_client_vpn
  client_vpn_cidr   = var.client_vpn_cidr

  node_instance_types = var.node_instance_types
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  node_desired_size   = var.node_desired_size
}
