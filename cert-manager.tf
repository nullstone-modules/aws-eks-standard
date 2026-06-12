# cert-manager is installed via Helm (there is no first-party EKS managed addon for it).
# It issues/renews in-cluster TLS certificates and is the prerequisite for webhook-based
# operators such as the ADOT/OpenTelemetry operator used by the aws-eks-otel-adot module.

ephemeral "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.this.name
}

provider "helm" {
  kubernetes = {
    host                   = aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
    token                  = ephemeral.aws_eks_cluster_auth.cluster.token
  }
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_chart_version
  namespace        = "cert-manager"
  create_namespace = true
  atomic           = true

  set = [{
    name  = "crds.enabled"
    value = "true"
  }]

  # Node group must be ready so cert-manager pods can schedule.
  depends_on = [aws_eks_node_group.this]
}
