# aws-eks-standard

Creates a Kubernetes cluster in Standard mode that uses EKS managed node groups.

## Included Addons

The following EKS addons are installed by default with every cluster.

### Networking

- **VPC CNI** (`vpc-cni`) — Provides native AWS VPC networking for pods, assigning each pod a real IP address from the VPC subnet. This enables direct communication between pods and other AWS resources without overlays or NAT.
- **CoreDNS** (`coredns`) — Provides cluster-internal DNS resolution, allowing pods to discover services by name.
- **kube-proxy** (`kube-proxy`) — Maintains network rules on each node for Kubernetes Service routing. Handles load balancing of traffic to the correct pods backing a service.

### Storage

- **EBS CSI Driver** (`aws-ebs-csi-driver`) — Enables dynamic provisioning of EBS volumes as Kubernetes persistent volumes. Required for stateful workloads that need block storage (databases, message queues, etc.).
- **EFS CSI Driver** (`aws-efs-csi-driver`) — Enables mounting of EFS file systems as Kubernetes persistent volumes. Useful for shared storage that needs to be accessed by multiple pods simultaneously.

### Security

- **EKS Pod Identity Agent** (`eks-pod-identity-agent`) — Enables pods to assume IAM roles using EKS Pod Identity, providing fine-grained AWS permissions to individual workloads without managing OIDC trust relationships per service account.
- **GuardDuty Agent** (`aws-guardduty-agent`) — Runs the Amazon GuardDuty runtime monitoring agent on cluster nodes. Detects threats such as container compromise, privilege escalation, and suspicious network activity.

### Observability

- **CloudWatch Observability** (`amazon-cloudwatch-observability`) — Collects and ships container logs, metrics, and traces to Amazon CloudWatch. Provides out-of-the-box dashboards for cluster and workload monitoring.
- **Node Monitoring Agent** (`amazon-eks-node-monitoring-agent`) — Monitors node-level health and reports issues back to the EKS control plane. Helps surface node problems (disk pressure, network issues, etc.) as Kubernetes node conditions.
