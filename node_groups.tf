locals {
  // The count and percentage forms are mutually exclusive, so a percentage nulls out its paired count.
  // When neither is set, fall back to the value EKS applies server-side, otherwise every plan shows a
  // diff that tries to null out the defaults EKS filled in.
  node_auto_repair_max_parallel_count  = var.node_auto_repair.max_parallel_percentage != null ? null : coalesce(var.node_auto_repair.max_parallel_count, 1)
  node_auto_repair_max_unhealthy_count = var.node_auto_repair.max_unhealthy_percentage != null ? null : coalesce(var.node_auto_repair.max_unhealthy_count, 5)
}

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
    enabled                                 = var.node_auto_repair.enabled
    max_parallel_nodes_repaired_count       = local.node_auto_repair_max_parallel_count
    max_parallel_nodes_repaired_percentage  = var.node_auto_repair.max_parallel_percentage
    max_unhealthy_node_threshold_count      = local.node_auto_repair_max_unhealthy_count
    max_unhealthy_node_threshold_percentage = var.node_auto_repair.max_unhealthy_percentage

    dynamic "node_repair_config_overrides" {
      for_each = var.node_auto_repair.overrides

      content {
        node_monitoring_condition = node_repair_config_overrides.value.node_monitoring_condition
        node_unhealthy_reason     = node_repair_config_overrides.value.node_unhealthy_reason
        min_repair_wait_time_mins = node_repair_config_overrides.value.min_repair_wait_time_mins
        repair_action             = node_repair_config_overrides.value.repair_action
      }
    }
  }

  lifecycle {
    precondition {
      condition     = !var.node_auto_repair.enabled || contains(toset(var.enabled_addons), "eks-node-monitoring-agent")
      error_message = "node_auto_repair.enabled requires the 'eks-node-monitoring-agent' addon to be present in enabled_addons."
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
  ]
}
