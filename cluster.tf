resource "aws_eks_cluster" "this" {
  name     = local.resource_name
  role_arn = aws_iam_role.this.arn
  version  = var.kubernetes_version
  tags     = local.tags

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP" # TODO: Harden to API once platform/catalog supports
  }

  bootstrap_self_managed_addons = false

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]

  encryption_config {
    resources = ["secrets"]

    provider {
      key_arn = aws_kms_key.this.arn
    }
  }

  vpc_config {
    endpoint_private_access = var.private_endpoint_only
    subnet_ids              = local.private_subnet_ids
    security_group_ids      = [aws_security_group.node.id]
    endpoint_public_access  = true
    public_access_cidrs     = var.private_endpoint_only ? local.ns_agent_cidrs : ["0.0.0.0/0"]
  }

  timeouts {
    delete = "30m"
  }

  lifecycle {
    precondition {
      condition     = !var.private_endpoint_only || length(local.ns_agent_cidrs) > 0
      error_message = "private_endpoint_only requires at least one Nullstone agent IP (data.ns_agent.ip_addresses); the public endpoint cannot have an empty CIDR allow list."
    }
  }

  depends_on = [
    module.logs,
    aws_iam_role_policy_attachment.this_basic,
    aws_iam_role_policy_attachment.this_service,
    aws_iam_role_policy_attachment.this_vpc,
  ]
}

locals {
  cluster_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

resource "aws_security_group_rule" "cluster-dns-tcp-from-private-cidr" {
  description       = "Allow DNS over TCP from VPC private subnets (pods with pod-level SGs, nodes, etc.)"
  security_group_id = local.cluster_security_group_id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 53
  to_port           = 53
  cidr_blocks       = local.private_cidrs
}

resource "aws_security_group_rule" "cluster-dns-udp-from-private-cidr" {
  description       = "Allow DNS over UDP from VPC private subnets (pods with pod-level SGs, nodes, etc.)"
  security_group_id = local.cluster_security_group_id
  type              = "ingress"
  protocol          = "udp"
  from_port         = 53
  to_port           = 53
  cidr_blocks       = local.private_cidrs
}

resource "aws_security_group_rule" "cluster-https-from-vpc" {
  count = var.private_endpoint_only ? 1 : 0

  description       = "Allow HTTPS to the private API endpoint from anywhere in the VPC"
  security_group_id = local.cluster_security_group_id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = [local.vpc_cidr]
}
