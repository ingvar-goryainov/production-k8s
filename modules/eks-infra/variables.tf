variable "name" {
  description = "Cluster name, also used as a prefix for the VPC and IAM roles."
  type        = string
}

variable "kubernetes_version" {
  description = "EKS Kubernetes minor version, e.g. \"1.36\"."
  type        = string
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

  validation {
    condition = alltrue([
      for version in values(var.addon_versions) : trimspace(version) != ""
    ])
    error_message = "Every managed EKS add-on must have an explicit non-empty version."
  }
}

# --- Network ---

variable "vpc_cidr" {
  description = "CIDR block of the VPC. Must not overlap with peered or existing VPCs."
  type        = string
}

variable "azs" {
  description = "Availability zones to spread subnets, NAT gateways and nodes across."
  type        = list(string)
}

variable "admin_trusted_principal_arns" {
  description = "Explicit IAM role or user ARNs allowed to assume the <name>-admin role."
  type        = list(string)
  nullable    = false

  validation {
    condition = length(var.admin_trusted_principal_arns) > 0 && alltrue([
      for arn in var.admin_trusted_principal_arns : can(regex("^arn:[^:]+:iam::[0-9]{12}:(role|user)/.+$", arn))
    ])
    error_message = "Provide at least one explicit IAM role or user ARN; account-wide or wildcard trust is not allowed."
  }
}

# --- Client VPN ---

variable "enable_client_vpn" {
  description = "Create an AWS Client VPN endpoint (mutual TLS, split tunnel) for workstation access to the private API endpoint."
  type        = bool
  default     = false
}

variable "client_vpn_cidr" {
  description = "Address pool assigned to VPN clients (/12 to /22). Must not overlap the VPC or the workstation's local network."
  type        = string
  default     = "10.200.0.0/22"

  validation {
    condition     = can(cidrhost(var.client_vpn_cidr, 0)) && tonumber(split("/", var.client_vpn_cidr)[1]) >= 12 && tonumber(split("/", var.client_vpn_cidr)[1]) <= 22
    error_message = "client_vpn_cidr must be an IPv4 CIDR between /12 and /22."
  }
}

variable "enabled_log_types" {
  description = "Control plane log types sent to CloudWatch Logs."
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "log_retention_days" {
  description = "Retention of the control plane CloudWatch log group."
  type        = number
  default     = 30
}

variable "deletion_protection" {
  description = "Block cluster deletion until this is turned off. Recommended for prod."
  type        = bool
  default     = false
}

# --- Nodes ---

variable "node_instance_types" {
  description = "Instance types of the default managed node group."
  type        = list(string)
}

variable "node_min_size" {
  description = "Minimum number of nodes in the default node group."
  type        = number
}

variable "node_max_size" {
  description = "Maximum number of nodes in the default node group."
  type        = number
}

variable "node_desired_size" {
  description = "Initial number of nodes. Ignored after creation (the EKS module ignores drift on it)."
  type        = number
}

variable "node_disk_size" {
  description = "Root EBS volume size (GiB) of each node."
  type        = number
  default     = 50
}
