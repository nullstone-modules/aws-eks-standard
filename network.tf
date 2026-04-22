data "ns_connection" "network" {
  name     = "network"
  contract = "network/aws/vpc"
}

locals {
  vpc_id             = data.ns_connection.network.outputs.vpc_id
  public_subnet_ids  = data.ns_connection.network.outputs.public_subnet_ids
  private_subnet_ids = data.ns_connection.network.outputs.private_subnet_ids
  private_cidrs      = data.ns_connection.network.outputs.private_cidrs
}

resource "aws_ec2_tag" "cluster_subnets" {
  for_each = toset(concat(local.public_subnet_ids, local.private_subnet_ids))

  resource_id = each.value
  key         = "kubernetes.io/cluster/${local.resource_name}"
  value       = "shared"
}

resource "aws_ec2_tag" "elb" {
  for_each = toset(local.public_subnet_ids)

  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

resource "aws_ec2_tag" "internal_elb" {
  for_each = toset(local.private_subnet_ids)

  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}
