variable "region" {
  type = string
}

variable "environment" {
  type = string
}

variable "owner" {
  description = "Value of the Owner tag on every resource."
  type        = string
}

variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "addon_versions" {
  description = "Explicit EKS managed add-on versions tested with the selected Kubernetes version and region."
  type = object({
    vpc_cni                = string
    eks_pod_identity_agent = string
    kube_proxy             = string
    coredns                = string
    aws_ebs_csi_driver     = string
    metrics_server         = string
  })
  nullable = false
}

variable "vpc_cidr" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "admin_trusted_principal_arns" {
  description = "Explicit IAM role or user ARNs allowed to assume the cluster-admin role."
  type        = list(string)
  nullable    = false
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "enable_client_vpn" {
  type    = bool
  default = false
}

variable "client_vpn_cidr" {
  type = string
}

variable "node_instance_types" {
  type = list(string)
}

variable "node_min_size" {
  type = number
}

variable "node_max_size" {
  type = number
}

variable "node_desired_size" {
  type = number
}
