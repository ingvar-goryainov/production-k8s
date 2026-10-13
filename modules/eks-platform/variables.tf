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

variable "kyverno_chart_version" {
  description = "Version of the kyverno Helm chart. The manifests in k8s/policies/ use the policies.kyverno.io/v1 types, which need Kyverno 1.17 or later."
  type        = string
}
