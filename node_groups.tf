resource "aws_eks_node_group" "this" {
  cluster_name         = aws_eks_cluster.this.name
  node_group_name      = "${local.resource_name}-default"
  node_role_arn        = aws_iam_role.node.arn
  subnet_ids           = local.private_subnet_ids
  instance_types       = var.node_instance_types
  disk_size            = var.node_disk_size
  ami_type             = var.node_ami_type
  labels               = var.node_labels
  force_update_version = var.node_force_update_version
  tags                 = local.tags

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = var.node_max_unavailable
  }

  dynamic "taint" {
    for_each = var.node_taints

    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  node_repair_config {
    enabled = var.node_auto_repair_enabled
  }

  lifecycle {
    precondition {
      condition     = !var.node_auto_repair_enabled || contains(toset(var.enabled_addons), "eks-node-monitoring-agent")
      error_message = "node_auto_repair_enabled requires the 'eks-node-monitoring-agent' addon to be present in enabled_addons."
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
  ]
}
