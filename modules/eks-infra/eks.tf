module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.29"

  name               = var.name
  kubernetes_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Keep the Kubernetes API reachable only from VPC-connected administration paths.
  endpoint_private_access = true
  endpoint_public_access  = false

  # Kubernetes API access for AWS Client VPN users (client_vpn.tf).
  security_group_additional_rules = var.enable_client_vpn ? {
    ingress_client_vpn_443 = {
      description              = "Client VPN to cluster API"
      protocol                 = "tcp"
      from_port                = 443
      to_port                  = 443
      type                     = "ingress"
      source_security_group_id = aws_security_group.client_vpn[0].id
    }
  } : {}

  # Access entries only (no aws-auth ConfigMap). Whoever runs Terraform gets no
  # Kubernetes access; humans and the platform stack assume the dedicated admin role.
  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = false

  access_entries = {
    admin = {
      principal_arn = aws_iam_role.cluster_admin.arn
      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  enabled_log_types                      = var.enabled_log_types
  cloudwatch_log_group_retention_in_days = var.log_retention_days

  # Workload IAM uses EKS Pod Identity, so the IRSA OIDC provider is not needed.
  enable_irsa = false

  deletion_protection = var.deletion_protection

  # Add-on versions are explicit inputs so upgrades require a reviewed change.
  addons = {
    vpc-cni = {
      before_compute = true
      most_recent    = false
      addon_version  = var.addon_versions.vpc_cni
    }
    eks-pod-identity-agent = {
      before_compute = true
      most_recent    = false
      addon_version  = var.addon_versions.eks_pod_identity_agent
    }
    kube-proxy = {
      most_recent   = false
      addon_version = var.addon_versions.kube_proxy
    }
    coredns = {
      most_recent   = false
      addon_version = var.addon_versions.coredns
    }
    aws-ebs-csi-driver = {
      most_recent   = false
      addon_version = var.addon_versions.aws_ebs_csi_driver
      pod_identity_association = [{
        role_arn        = module.ebs_csi_pod_identity.iam_role_arn
        service_account = "ebs-csi-controller-sa"
      }]
    }
    metrics-server = {
      most_recent   = false
      addon_version = var.addon_versions.metrics_server
    }
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      block_device_mappings = {
        root = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = var.node_disk_size
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      # Shell access to nodes via SSM Session Manager instead of SSH.
      iam_role_additional_policies = {
        ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      labels = {
        role = "general"
      }
    }
  }
}
