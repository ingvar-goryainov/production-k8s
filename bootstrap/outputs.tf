output "state_bucket_name" {
  description = "Name of the S3 bucket to use in every stack's backend \"s3\" block."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "ARN of the Terraform state bucket."
  value       = aws_s3_bucket.state.arn
}

output "state_kms_key_arn" {
  description = "ARN of the customer-managed KMS key used for Terraform state."
  value       = aws_kms_key.state.arn
}
