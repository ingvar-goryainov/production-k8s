region      = "eu-west-1"
environment = "dev"
owner       = "Ihor Pysmennyi"

cluster_name       = "eks-dev"
kubernetes_version = "1.36"

# addon_versions is set in local.auto.tfvars; use versions reviewed for this
# Kubernetes version and eu-west-1.

# Must not overlap other VPCs in the account (an existing one uses 172.31.0.0/16).
vpc_cidr = "10.0.0.0/16"
azs      = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]

# AWS Client VPN for laptop access to the private API endpoint. The client pool must
# not overlap the VPC or your local network. Set to false to stop the hourly charges.
enable_client_vpn = true
client_vpn_cidr   = "10.200.0.0/22"

# No Cluster Autoscaler: scale by changing the node group in the console/CLI,
# or by raising node_min_size (desired_size is ignored after creation).
node_instance_types = ["m6i.large"]
node_min_size       = 3
node_max_size       = 6
node_desired_size   = 3
