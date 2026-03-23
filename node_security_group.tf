// See https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html
resource "aws_security_group" "node" {
  vpc_id      = local.vpc_id
  name        = "${local.resource_name} Node"
  description = "Security Group for EKS Nodes"

  tags = merge(local.tags, {
    Name                                           = "${local.resource_name}-node"
    "kubernetes.io/cluster/${local.resource_name}" = "owned"
  })
}

resource "aws_security_group_rule" "node-dns-tcp-from-self" {
  description       = "Allow nodes to access other node nameservers over TCP"
  security_group_id = aws_security_group.node.id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 53
  to_port           = 53
  self              = true
}

resource "aws_security_group_rule" "node-dns-udp-from-self" {
  description       = "Allow nodes to access other node nameservers over UDP"
  security_group_id = aws_security_group.node.id
  type              = "ingress"
  protocol          = "udp"
  from_port         = 53
  to_port           = 53
  self              = true
}

resource "aws_security_group_rule" "node-dns-tcp-to-self" {
  description       = "Allow nodes to reach other node nameservers over TCP"
  security_group_id = aws_security_group.node.id
  type              = "egress"
  protocol          = "tcp"
  from_port         = 53
  to_port           = 53
  self              = true
}

resource "aws_security_group_rule" "node-dns-udp-to-self" {
  description       = "Allow nodes to reach other node nameservers over UDP"
  security_group_id = aws_security_group.node.id
  type              = "egress"
  protocol          = "udp"
  from_port         = 53
  to_port           = 53
  self              = true
}

resource "aws_security_group_rule" "node-10250-to-self" {
  description       = "Allow nodes to reach other nodes on 10250"
  security_group_id = aws_security_group.node.id
  type              = "egress"
  protocol          = "tcp"
  from_port         = 10250
  to_port           = 10250
  self              = true
}

resource "aws_security_group_rule" "node-10250-from-self" {
  description       = "Allow nodes to access other nodes on 10250"
  security_group_id = aws_security_group.node.id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 10250
  to_port           = 10250
  self              = true
}

resource "aws_security_group_rule" "node-https-to-self" {
  description       = "Allow nodes to reach other nodes over HTTPS"
  security_group_id = aws_security_group.node.id
  type              = "egress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  self              = true
}

resource "aws_security_group_rule" "node-https-from-self" {
  description       = "Allow nodes to access other nodes over HTTPS"
  security_group_id = aws_security_group.node.id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  self              = true
}

resource "aws_security_group_rule" "node-to-world-ipv4" {
  description       = "Allow node to reach world for cluster introspection and node registration"
  security_group_id = aws_security_group.node.id
  type              = "egress"
  protocol          = "tcp"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}
