variable "kubernetes_version" {
  type        = string
  default     = "1.35"
  description = <<EOF
Desired Kubernetes master version.
If you do not specify a value, the latest available version at resource creation is used and no upgrades will occur except those automatically triggered by EKS.
The value must be configured and increased to upgrade the version when desired.
Downgrades are not supported by EKS.
EOF

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+$", var.kubernetes_version))
    error_message = "kubernetes_version must be in the format 'MAJOR.MINOR' (e.g. '1.35')."
  }
}

variable "log_retention_in_days" {
  type        = number
  default     = 365
  description = <<EOF
This defines the retention period for the CloudWatch logs for this Kubernetes cluster.
EOF

  validation {
    condition     = var.log_retention_in_days >= 1
    error_message = "log_retention_in_days must be at least 1 day"
  }
}

variable "node_instance_types" {
  type        = list(string)
  default     = ["t3.medium"]
  description = <<EOF
List of EC2 instance types for the managed node group.
The first instance type in the list is used as the primary type.
EOF
}

variable "node_desired_size" {
  type        = number
  default     = 2
  description = "Desired number of nodes in the managed node group."

  validation {
    condition     = var.node_desired_size >= 1
    error_message = "node_desired_size must be at least 1."
  }
}

variable "node_min_size" {
  type        = number
  default     = 1
  description = "Minimum number of nodes in the managed node group."

  validation {
    condition     = var.node_min_size >= 1
    error_message = "node_min_size must be at least 1."
  }
}

variable "node_max_size" {
  type        = number
  default     = 5
  description = "Maximum number of nodes in the managed node group."

  validation {
    condition     = var.node_max_size >= 1
    error_message = "node_max_size must be at least 1."
  }
}

variable "node_disk_size" {
  type        = number
  default     = 20
  description = "Disk size in GiB for each node in the managed node group."

  validation {
    condition     = var.node_disk_size >= 20
    error_message = "node_disk_size must be at least 20 GiB."
  }
}

variable "node_ami_type" {
  type        = string
  default     = "AL2023_x86_64_STANDARD"
  description = <<EOF
AMI type for the managed node group.
Valid values: AL2023_x86_64_STANDARD, AL2023_ARM_64_STANDARD, AL2_x86_64, AL2_ARM_64, BOTTLEROCKET_x86_64, BOTTLEROCKET_ARM_64.
EOF
}

variable "enable_aws_load_balancer_controller" {
  type        = bool
  default     = true
  description = <<EOF
Whether to install the AWS Load Balancer Controller EKS addon.
When enabled, provisions the IAM role/policy, Pod Identity association, and addon required to manage ALBs/NLBs from Kubernetes Ingress and Service resources.
EOF
}
