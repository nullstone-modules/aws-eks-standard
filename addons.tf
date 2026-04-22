# -----------------------------------------------
# Addons that require no additional IAM role
# -----------------------------------------------

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "eks-pod-identity-agent"
  resolve_conflicts_on_update = "PRESERVE"
  tags                        = local.tags

  timeouts {
    create = "30m"
  }
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_update = "PRESERVE"
  tags                        = local.tags

  configuration_values = jsonencode({
    env = {
      ENABLE_POD_ENI                    = "true"
      POD_SECURITY_GROUP_ENFORCING_MODE = "standard"
    }
  })

  timeouts {
    create = "30m"
  }
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_update = "PRESERVE"
  tags                        = local.tags

  timeouts {
    create = "30m"
  }
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  resolve_conflicts_on_update = "PRESERVE"
  tags                        = local.tags

  timeouts {
    create = "30m"
  }

  depends_on = [aws_eks_node_group.this]
}

resource "aws_eks_addon" "node_monitoring_agent" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "eks-node-monitoring-agent"
  resolve_conflicts_on_update = "PRESERVE"
  tags                        = local.tags

  timeouts {
    create = "30m"
  }
}

resource "aws_eks_addon" "guardduty" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-guardduty-agent"
  resolve_conflicts_on_update = "PRESERVE"
  tags                        = local.tags

  timeouts {
    create = "30m"
  }
}

# -----------------------------------------------
# Secrets Store CSI Driver + AWS Provider
# -----------------------------------------------

resource "aws_eks_addon" "secrets_store_csi_aws_provider" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-secrets-store-csi-driver-provider"
  resolve_conflicts_on_update = "PRESERVE"
  tags                        = local.tags

  configuration_values = jsonencode({
    "secrets-store-csi-driver" = {
      enableSecretRotation = true
      syncSecret = {
        enabled = true
      }
    }
  })

  timeouts {
    create = "30m"
  }
}

# -----------------------------------------------
# EFS CSI Driver
# -----------------------------------------------

resource "aws_iam_role" "efs_csi" {
  name               = "${local.resource_name}-efs-csi"
  assume_role_policy = data.aws_iam_policy_document.efs_csi_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "efs_csi_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.this.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:efs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.this.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "efs_csi" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
  role       = aws_iam_role.efs_csi.name
}

resource "aws_eks_addon" "efs_csi" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-efs-csi-driver"
  resolve_conflicts_on_update = "PRESERVE"
  service_account_role_arn    = aws_iam_role.efs_csi.arn
  tags                        = local.tags

  timeouts {
    create = "30m"
  }
}

# -----------------------------------------------
# EBS CSI Driver
# -----------------------------------------------

resource "aws_iam_role" "ebs_csi" {
  name               = "${local.resource_name}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "ebs_csi_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.this.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.this.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi.name
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_update = "PRESERVE"
  service_account_role_arn    = aws_iam_role.ebs_csi.arn
  tags                        = local.tags

  timeouts {
    create = "30m"
  }
}

# -----------------------------------------------
# CloudWatch Observability
# -----------------------------------------------

resource "aws_iam_role" "cloudwatch_observability" {
  name               = "${local.resource_name}-cw-obs"
  assume_role_policy = data.aws_iam_policy_document.cloudwatch_observability_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "cloudwatch_observability_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.this.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:amazon-cloudwatch:cloudwatch-agent"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.this.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "cloudwatch_observability" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.cloudwatch_observability.name
}

resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "amazon-cloudwatch-observability"
  resolve_conflicts_on_update = "PRESERVE"
  service_account_role_arn    = aws_iam_role.cloudwatch_observability.arn
  tags                        = local.tags

  configuration_values = jsonencode({
    "manager" = {
      applicationSignals = {
        autoMonitor = {
          monitorAllServices = false
        }
      }
    }
  })

  timeouts {
    create = "30m"
  }
}
