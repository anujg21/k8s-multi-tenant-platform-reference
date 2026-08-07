# EKS control plane + IAM + a minimal static node group.
#
# The static node group exists ONLY to host cluster-critical add-ons
# (CoreDNS, the Karpenter controller itself, ingress controller) that must
# not depend on Karpenter's own scheduling loop being healthy to bootstrap.
# All tenant/application workloads are scheduled onto Karpenter-provisioned
# nodes (see ../karpenter).

resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access  = true
    endpoint_public_access   = false
  }

  access_config {
    authentication_mode = "API"
  }

  tags = var.tags

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}

# --- Minimal static node group for cluster-critical add-ons ---------------

resource "aws_iam_role" "node_group" {
  name = "${var.cluster_name}-static-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node_group_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ])
  role       = aws_iam_role.node_group.name
  policy_arn = each.value
}

resource "aws_eks_node_group" "static" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-static-critical-addons"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = var.static_node_group_instance_types

  scaling_config {
    min_size     = var.static_node_group_min_size
    max_size     = var.static_node_group_max_size
    desired_size = var.static_node_group_min_size
  }

  labels = {
    "platform.internal/role" = "critical-addons"
  }

  # Tenant workloads are never scheduled here — this taint keeps this
  # node group reserved for platform add-ons, with Karpenter-provisioned
  # nodes handling everything else.
  taint {
    key    = "platform.internal/critical-addons-only"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  tags = var.tags

  depends_on = [aws_iam_role_policy_attachment.node_group_policies]
}
