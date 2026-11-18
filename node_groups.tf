locals {
  // The count and percentage forms are mutually exclusive, so a percentage nulls out its paired count.
  // When neither is set, fall back to the value EKS applies server-side, otherwise every plan shows a
  // diff that tries to null out the defaults EKS filled in.
  node_auto_repair_max_parallel_count  = var.node_auto_repair.max_parallel_percentage != null ? null : coalesce(var.node_auto_repair.max_parallel_count, 1)
  node_auto_repair_max_unhealthy_count = var.node_auto_repair.max_unhealthy_percentage != null ? null : coalesce(var.node_auto_repair.max_unhealthy_count, 5)

  // Bottlerocket keeps the OS on a fixed 2 GiB /dev/xvda and puts data on /dev/xvdb; AL2/AL2023 boot from /dev/xvda.
  node_root_device_name = startswith(var.node_ami_type, "BOTTLEROCKET") ? "/dev/xvdb" : "/dev/xvda"
}

// EKS does not propagate node group tags to the EC2 instances, EBS volumes, or ENIs it launches.
// A custom launch template with tag_specifications is the only way to tag those billable resources.
// The node group's disk_size cannot be combined with a launch template, so the volume size lives here.
resource "aws_launch_template" "node" {
  name_prefix = "${local.resource_name}-node-"
  tags        = local.tags

  block_device_mappings {
    device_name = local.node_root_device_name

    ebs {
      volume_size           = var.node_disk_size
      delete_on_termination = true
    }
  }

  // Matches the IMDS settings EKS applies to its default launch template.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  dynamic "tag_specifications" {
    for_each = toset(["instance", "volume", "network-interface"])

    content {
      resource_type = tag_specifications.value
      tags          = merge(local.tags, { Name = "${local.resource_name}-node" })
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eks_node_group" "this" {
  cluster_name = aws_eks_cluster.this.name
  // A generated name lets a replacement node group run alongside the old one (see lifecycle below).
  // EKS caps node group names at 63 chars and the generated suffix uses 26, so the prefix is capped at 37.
  node_group_name_prefix = "${substr(local.resource_name, 0, 36)}-"
  node_role_arn          = aws_iam_role.node.arn
  subnet_ids             = local.private_subnet_ids
  instance_types         = var.node_instance_types
  ami_type               = var.node_ami_type
  labels                 = var.node_labels
  force_update_version   = var.node_force_update_version
  tags                   = local.tags

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

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
    // Changes that force a new node group (launch template id, instance types, AMI type, subnets) bring the
    // replacement up and wait for its nodes to be Ready before EKS cordons, drains (honoring PDBs), and
    // deletes the old one. Launch template version bumps never replace the group; EKS rolls nodes in place
    // under update_config.max_unavailable instead.
    create_before_destroy = true

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
