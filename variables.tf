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

variable "node_labels" {
  type        = map(string)
  default     = {}
  description = <<EOF
Kubernetes labels applied to every node in the managed node group.
Use these to steer workloads with nodeSelector or node affinity.
EOF
}

variable "node_taints" {
  type = list(object({
    key    = string
    value  = optional(string)
    effect = string
  }))
  default     = []
  description = <<EOF
Kubernetes taints applied to every node in the managed node group.
Valid effects: NO_SCHEDULE, NO_EXECUTE, PREFER_NO_SCHEDULE.

This module creates a single node group, so a taint here applies to every node in the cluster.
Anything without a matching toleration will be unschedulable, including cluster-critical pods such as coredns and the CSI controllers.
EOF

  validation {
    condition     = alltrue([for taint in var.node_taints : contains(["NO_SCHEDULE", "NO_EXECUTE", "PREFER_NO_SCHEDULE"], taint.effect)])
    error_message = "node_taints effect must be one of NO_SCHEDULE, NO_EXECUTE, or PREFER_NO_SCHEDULE."
  }
}

variable "node_max_unavailable" {
  type        = number
  default     = 1
  description = <<EOF
Number of nodes that can be unavailable at once while the managed node group rolls through an update.
Raising this shortens Kubernetes version and AMI upgrades on larger node groups at the cost of reduced capacity during the rollout.
EOF

  validation {
    condition     = var.node_max_unavailable >= 1
    error_message = "node_max_unavailable must be at least 1."
  }
}

variable "node_force_update_version" {
  type        = bool
  default     = false
  description = <<EOF
Forces node replacement during a version update even when pods cannot be drained gracefully.
When false, a PodDisruptionBudget that never allows an eviction will stall the upgrade indefinitely.
When true, EKS evicts those pods anyway to complete the rollout.
EOF
}

variable "node_auto_repair" {
  type = object({
    enabled                  = optional(bool, true)
    max_parallel_count       = optional(number)
    max_parallel_percentage  = optional(number)
    max_unhealthy_count      = optional(number)
    max_unhealthy_percentage = optional(number)
    overrides = optional(list(object({
      node_monitoring_condition = string
      node_unhealthy_reason     = string
      min_repair_wait_time_mins = number
      repair_action             = string
    })), [])
  })
  default     = {}
  description = <<EOF
Configures EKS node auto repair for the managed node group.
When a node is reported unhealthy for a sustained period, EKS replaces or reboots it without manual intervention.
This requires the 'eks-node-monitoring-agent' addon, which detects and reports the node conditions that trigger a repair.

  enabled                     Whether node auto repair is enabled. Defaults to true.
  max_parallel_count          Maximum number of nodes repaired concurrently. Defaults to 1, matching EKS.
  max_parallel_percentage     Maximum percentage of unhealthy nodes repaired concurrently (0-100).
  max_unhealthy_count         Number of unhealthy nodes above which auto repair stops acting. Defaults to 5, matching EKS.
  max_unhealthy_percentage    Percentage of unhealthy nodes above which auto repair stops acting (0-100).
  overrides                   Per-condition repair actions and wait times. See below.

The max_unhealthy_* setting is a safety brake: during a cluster-wide incident it stops auto repair from cycling the entire node group. In-progress repairs still finish.
Each pair is mutually exclusive. Set the count or the percentage, never both, and omit both to keep the value EKS applies server-side.

Each entry in overrides replaces the default repair action and wait time for a single node health issue:

  node_monitoring_condition   Condition reported by the node monitoring agent, e.g. AcceleratedHardwareReady, ContainerRuntimeReady, KernelReady, NetworkingReady, StorageReady, Ready.
  node_unhealthy_reason       Reason code for the condition, e.g. NvidiaXID31Error, IPAMDNotRunning.
  min_repair_wait_time_mins   How long the condition must persist before the node is eligible for repair. Use this to avoid repairing transient issues.
  repair_action               Replace (terminate and replace the node), Reboot (reboot in place), or NoAction (never repair this condition).

Without an override, EKS replaces after 30m for most conditions, and replaces or reboots after 10m for AcceleratedHardwareReady.
EOF

  validation {
    condition     = var.node_auto_repair.max_parallel_count == null || var.node_auto_repair.max_parallel_percentage == null
    error_message = "node_auto_repair may set max_parallel_count or max_parallel_percentage, not both."
  }

  validation {
    condition     = var.node_auto_repair.max_unhealthy_count == null || var.node_auto_repair.max_unhealthy_percentage == null
    error_message = "node_auto_repair may set max_unhealthy_count or max_unhealthy_percentage, not both."
  }

  validation {
    condition     = var.node_auto_repair.max_parallel_count == null || var.node_auto_repair.max_parallel_count >= 1
    error_message = "node_auto_repair.max_parallel_count must be at least 1."
  }

  validation {
    condition     = var.node_auto_repair.max_unhealthy_count == null || var.node_auto_repair.max_unhealthy_count >= 1
    error_message = "node_auto_repair.max_unhealthy_count must be at least 1."
  }

  validation {
    condition     = var.node_auto_repair.max_parallel_percentage == null || (var.node_auto_repair.max_parallel_percentage >= 0 && var.node_auto_repair.max_parallel_percentage <= 100)
    error_message = "node_auto_repair.max_parallel_percentage must be between 0 and 100."
  }

  validation {
    condition     = var.node_auto_repair.max_unhealthy_percentage == null || (var.node_auto_repair.max_unhealthy_percentage >= 0 && var.node_auto_repair.max_unhealthy_percentage <= 100)
    error_message = "node_auto_repair.max_unhealthy_percentage must be between 0 and 100."
  }

  validation {
    condition     = alltrue([for override in var.node_auto_repair.overrides : contains(["Replace", "Reboot", "NoAction"], override.repair_action)])
    error_message = "node_auto_repair.overrides repair_action must be one of Replace, Reboot, or NoAction."
  }

  validation {
    condition     = alltrue([for override in var.node_auto_repair.overrides : override.min_repair_wait_time_mins >= 0])
    error_message = "node_auto_repair.overrides min_repair_wait_time_mins must be at least 0."
  }
}

variable "enabled_addons" {
  type = list(string)
  default = [
    "eks-pod-identity-agent",
    "vpc-cni",
    "kube-proxy",
    "coredns",
    "eks-node-monitoring-agent",
    "aws-guardduty-agent",
    "aws-secrets-store-csi-driver-provider",
    "aws-efs-csi-driver",
    "aws-ebs-csi-driver",
    "amazon-cloudwatch-observability",
  ]
  description = <<EOF
List of EKS addons to install on the cluster. Any IAM roles, policies, and Pod Identity associations required by an addon are provisioned only when that addon is included.

Supported addon names (these are the only values accepted; the list is the full set of addons this module knows how to install):
  - eks-pod-identity-agent                   Pod Identity agent for IAM-roles-for-service-accounts via Pod Identity.
  - vpc-cni                                  Pod networking. Required by coredns.
  - kube-proxy                               kube-proxy daemonset.
  - coredns                                  Cluster DNS. Requires vpc-cni and a running node group.
  - eks-node-monitoring-agent                EKS node health monitoring.
  - aws-guardduty-agent                      GuardDuty runtime monitoring.
  - aws-secrets-store-csi-driver-provider    Secrets Store CSI driver + AWS provider.
  - aws-efs-csi-driver                       EFS CSI driver (provisions an IAM role via IRSA).
  - aws-ebs-csi-driver                       EBS CSI driver (provisions an IAM role via IRSA).
  - amazon-cloudwatch-observability          CloudWatch agent + Container Insights (provisions an IAM role via IRSA).
EOF

  validation {
    condition = length(setsubtract(toset(var.enabled_addons), toset([
      "eks-pod-identity-agent",
      "vpc-cni",
      "kube-proxy",
      "coredns",
      "eks-node-monitoring-agent",
      "aws-guardduty-agent",
      "aws-secrets-store-csi-driver-provider",
      "aws-efs-csi-driver",
      "aws-ebs-csi-driver",
      "amazon-cloudwatch-observability",
    ]))) == 0
    error_message = "enabled_addons contains an unsupported addon name. See the variable description for the full list of supported addons."
  }
}

variable "cert_manager_chart_version" {
  type        = string
  default     = "v1.16.2"
  description = "The version of the cert-manager Helm chart (https://charts.jetstack.io) to install. cert-manager is required by webhook-based operators such as the ADOT operator."
}
