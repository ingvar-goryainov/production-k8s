variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "region" {
  description = "AWS region of the cluster."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID, passed to the LB controller because pods cannot reach IMDS (hop limit 1)."
  type        = string
}

variable "aws_lb_controller_chart_version" {
  description = "Version of the aws-load-balancer-controller Helm chart."
  type        = string
}

variable "argocd_chart_version" {
  description = "Version of the argo-cd Helm chart."
  type        = string
}

variable "argocd_apps_chart_version" {
  description = "Version of the argocd-apps Helm chart that creates the root Application."
  type        = string
}

variable "gitops_repo_url" {
  description = "Git repository the root Application syncs gitops/apps from."
  type        = string
}

variable "grafana_admin_password" {
  description = "Password of the Grafana admin user."
  type        = string
  sensitive   = true
}

variable "telegram_bot_token" {
  description = "Telegram bot token used by the Grafana alert contact point."
  type        = string
  sensitive   = true
}

variable "telegram_chat_id" {
  description = "Telegram chat ID that receives Grafana alerts."
  type        = string
  sensitive   = true
}
