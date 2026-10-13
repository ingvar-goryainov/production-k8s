# Read by envs/dev/platform through terraform_remote_state.

output "region" {
  value = module.infra.region
}

output "cluster_name" {
  value = module.infra.cluster_name
}

output "cluster_endpoint" {
  value = module.infra.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.infra.cluster_certificate_authority_data
}

output "vpc_id" {
  value = module.infra.vpc_id
}

output "private_subnet_ids" {
  value = module.infra.private_subnet_ids
}

output "public_subnet_ids" {
  value = module.infra.public_subnet_ids
}

output "cluster_admin_role_arn" {
  value = module.infra.cluster_admin_role_arn
}

output "configure_kubectl" {
  value = module.infra.configure_kubectl
}

output "client_vpn_endpoint_id" {
  value = module.infra.client_vpn_endpoint_id
}

output "client_vpn_config" {
  value     = module.infra.client_vpn_config
  sensitive = true
}
