variable "state_bucket" {
  description = "S3 bucket holding the infra stack's state."
  type        = string
}

variable "infra_state_key" {
  description = "State key of the infra stack for this environment."
  type        = string
}

variable "state_region" {
  type = string
}

variable "aws_lb_controller_chart_version" {
  type = string
}

variable "argocd_chart_version" {
  type = string
}

variable "argocd_apps_chart_version" {
  type = string
}

variable "gitops_repo_url" {
  type = string
}
