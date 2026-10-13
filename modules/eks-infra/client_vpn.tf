# AWS Client VPN for workstation access to the private Kubernetes API endpoint.
# Mutual TLS: Terraform generates a private CA, a server certificate (imported into ACM)
# and one client certificate. Their private keys are stored in the KMS-encrypted state.
# The VPN only grants network reach; Kubernetes access still requires assuming the admin role.

locals {
  client_vpn_count       = var.enable_client_vpn ? 1 : 0
  client_vpn_server_name = "vpn-server.${var.name}.internal"
}

# --- Certificates (Client VPN supports RSA 1024/2048 only) ---

resource "tls_private_key" "client_vpn_ca" {
  count = local.client_vpn_count

  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "client_vpn_ca" {
  count = local.client_vpn_count

  private_key_pem       = tls_private_key.client_vpn_ca[0].private_key_pem
  is_ca_certificate     = true
  validity_period_hours = 87600 # 10 years
  allowed_uses          = ["cert_signing", "crl_signing"]

  subject {
    common_name = "${var.name} Client VPN CA"
  }
}

resource "tls_private_key" "client_vpn_server" {
  count = local.client_vpn_count

  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "client_vpn_server" {
  count = local.client_vpn_count

  private_key_pem = tls_private_key.client_vpn_server[0].private_key_pem
  dns_names       = [local.client_vpn_server_name]

  subject {
    common_name = local.client_vpn_server_name
  }
}

# Leaf certificates are re-issued by any apply within 30 days of expiry. ACM keeps the
# same ARN on re-import; the client certificate change requires re-exporting the profile.
resource "tls_locally_signed_cert" "client_vpn_server" {
  count = local.client_vpn_count

  cert_request_pem      = tls_cert_request.client_vpn_server[0].cert_request_pem
  ca_private_key_pem    = tls_private_key.client_vpn_ca[0].private_key_pem
  ca_cert_pem           = tls_self_signed_cert.client_vpn_ca[0].cert_pem
  validity_period_hours = 17520 # 2 years
  early_renewal_hours   = 720
  allowed_uses          = ["digital_signature", "key_encipherment", "server_auth"]
}

resource "tls_private_key" "client_vpn_client" {
  count = local.client_vpn_count

  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "client_vpn_client" {
  count = local.client_vpn_count

  private_key_pem = tls_private_key.client_vpn_client[0].private_key_pem

  subject {
    common_name = "${var.name}-vpn-client"
  }
}

resource "tls_locally_signed_cert" "client_vpn_client" {
  count = local.client_vpn_count

  cert_request_pem      = tls_cert_request.client_vpn_client[0].cert_request_pem
  ca_private_key_pem    = tls_private_key.client_vpn_ca[0].private_key_pem
  ca_cert_pem           = tls_self_signed_cert.client_vpn_ca[0].cert_pem
  validity_period_hours = 17520 # 2 years
  early_renewal_hours   = 720
  allowed_uses          = ["digital_signature", "client_auth"]
}

# Client certificates are issued by the same CA, so this ARN also serves as the client root chain.
resource "aws_acm_certificate" "client_vpn_server" {
  count = local.client_vpn_count

  private_key       = tls_private_key.client_vpn_server[0].private_key_pem
  certificate_body  = tls_locally_signed_cert.client_vpn_server[0].cert_pem
  certificate_chain = tls_self_signed_cert.client_vpn_ca[0].cert_pem

  tags = {
    Name = "${var.name}-client-vpn-server"
  }
}

# --- Network ---

# Client traffic is source-NATed to the endpoint ENIs, which carry this security group.
# The cluster security group admits it on 443 (security_group_additional_rules in eks.tf).
resource "aws_security_group" "client_vpn" {
  count = local.client_vpn_count

  name        = "${var.name}-client-vpn"
  description = "AWS Client VPN endpoint ENIs"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "${var.name}-client-vpn"
  }
}

resource "aws_vpc_security_group_egress_rule" "client_vpn_api" {
  count = local.client_vpn_count

  security_group_id            = aws_security_group.client_vpn[0].id
  description                  = "Kubernetes API"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = module.eks.cluster_security_group_id
}

resource "aws_cloudwatch_log_group" "client_vpn" {
  count = local.client_vpn_count

  name              = "/aws/clientvpn/${var.name}"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_stream" "client_vpn" {
  count = local.client_vpn_count

  name           = "connections"
  log_group_name = aws_cloudwatch_log_group.client_vpn[0].name
}

resource "aws_ec2_client_vpn_endpoint" "this" {
  count = local.client_vpn_count

  description            = "${var.name} workstation access"
  server_certificate_arn = aws_acm_certificate.client_vpn_server[0].arn
  client_cidr_block      = var.client_vpn_cidr
  vpc_id                 = module.vpc.vpc_id
  security_group_ids     = [aws_security_group.client_vpn[0].id]

  # Only VPC-bound traffic goes through the tunnel; DNS uses the VPC resolver.
  split_tunnel = true
  dns_servers  = [cidrhost(var.vpc_cidr, 2)]

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.client_vpn_server[0].arn
  }

  connection_log_options {
    enabled               = true
    cloudwatch_log_group  = aws_cloudwatch_log_group.client_vpn[0].name
    cloudwatch_log_stream = aws_cloudwatch_log_stream.client_vpn[0].name
  }

  tags = {
    Name = "${var.name}-client-vpn"
  }
}

# Each subnet association is billed hourly; one AZ is enough for workstation access.
# The association also adds the route to the VPC CIDR.
resource "aws_ec2_client_vpn_network_association" "this" {
  count = local.client_vpn_count

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this[0].id
  subnet_id              = module.vpc.private_subnets[0]
}

resource "aws_ec2_client_vpn_authorization_rule" "vpc" {
  count = local.client_vpn_count

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this[0].id
  target_network_cidr    = var.vpc_cidr
  authorize_all_groups   = true
  description            = "Cluster VPC"
}
