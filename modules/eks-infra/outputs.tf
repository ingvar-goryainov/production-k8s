data "aws_region" "current" {}

output "region" {
  description = "AWS region of the cluster."
  value       = data.aws_region.current.region
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster CA certificate."
  value       = module.eks.cluster_certificate_authority_data
}

output "vpc_id" {
  description = "ID of the cluster VPC."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (nodes and internal load balancers)."
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Public subnet IDs (NAT gateways and internet-facing load balancers)."
  value       = module.vpc.public_subnets
}

output "cluster_admin_role_arn" {
  description = "IAM role with cluster-admin; assume it for kubectl and the platform stack."
  value       = aws_iam_role.cluster_admin.arn
}

output "configure_kubectl" {
  description = "Command that writes a kubeconfig entry that assumes the cluster-admin role."
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${data.aws_region.current.region} --role-arn ${aws_iam_role.cluster_admin.arn}"
}

output "client_vpn_endpoint_id" {
  description = "AWS Client VPN endpoint ID, or null when the VPN is disabled."
  value       = one(aws_ec2_client_vpn_endpoint.this[*].id)
}

output "client_vpn_config" {
  description = "OpenVPN profile with the embedded client certificate and key, or null when the VPN is disabled."
  sensitive   = true
  value = var.enable_client_vpn ? templatefile("${path.module}/client_vpn.ovpn.tftpl", {
    protocol    = aws_ec2_client_vpn_endpoint.this[0].transport_protocol
    remote      = trimprefix(aws_ec2_client_vpn_endpoint.this[0].dns_name, "*.")
    port        = aws_ec2_client_vpn_endpoint.this[0].vpn_port
    server_name = local.client_vpn_server_name
    ca_cert     = tls_self_signed_cert.client_vpn_ca[0].cert_pem
    client_cert = tls_locally_signed_cert.client_vpn_client[0].cert_pem
    client_key  = tls_private_key.client_vpn_client[0].private_key_pem
  }) : null
}
