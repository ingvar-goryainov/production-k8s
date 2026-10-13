variable "region" {
  description = "AWS region for the Terraform state bucket."
  type        = string
}

variable "state_bucket_name" {
  description = "Globally unique name of the S3 bucket that stores Terraform state."
  type        = string
}

variable "noncurrent_version_retention_days" {
  description = "Days to keep non-current (overwritten) state versions before expiring them."
  type        = number
  default     = 90
}

variable "tags" {
  description = "Tags applied to every resource via provider default_tags."
  type        = map(string)
  default     = {}
}
