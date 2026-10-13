region = "eu-west-1"

# state_bucket_name is set in local.auto.tfvars (gitignored); see local.auto.tfvars.example.

tags = {
  Project   = "kubernetes-in-production"
  Component = "terraform-state"
  ManagedBy = "terraform"
  Owner     = "Ihor Pysmennyi"
}
