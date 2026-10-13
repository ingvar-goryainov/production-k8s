locals {
  # /20 private subnets (4096 IPs each): VPC CNI gives every pod a VPC IP.
  private_subnets = [for i, _ in var.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  # /24 public subnets, placed after the private range: only NAT gateways and load balancers live here.
  public_subnets = [for i, _ in var.azs : cidrsubnet(var.vpc_cidr, 8, 48 + i)]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7"

  name = var.name
  cidr = var.vpc_cidr
  azs  = var.azs

  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  # One NAT gateway per AZ so an AZ outage does not cut egress for the others.
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Subnet discovery tags used by the AWS Load Balancer Controller.
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}
