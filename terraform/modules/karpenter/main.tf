# Karpenter controller + the NodePool/EC2NodeClass that define what it's
# allowed to provision for tenant workloads.
#
# See docs/adr/0001-karpenter-over-cluster-autoscaler.md for why Karpenter
# was chosen over Cluster Autoscaler for this platform.

data "aws_caller_identity" "current" {}

# --- IRSA role for the Karpenter controller --------------------------------

resource "aws_iam_role" "karpenter_controller" {
  name = "${var.cluster_name}-karpenter-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(var.cluster_oidc_issuer_url, "https://", "")}"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(var.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:karpenter"
          "${replace(var.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "karpenter_controller" {
  name = "${var.cluster_name}-karpenter-controller-policy"
  role = aws_iam_role.karpenter_controller.id

  # Scoped to EC2 fleet/instance lifecycle actions only — Karpenter never
  # needs broader account access than provisioning and terminating the
  # nodes it manages.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateTags",
          "ec2:DeleteLaunchTemplate",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstances",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.cluster_name}-static-node-group-role"
      }
    ]
  })
}

# --- Karpenter controller (Helm) --------------------------------------------

resource "helm_release" "karpenter" {
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = var.karpenter_helm_chart_version
  namespace        = "kube-system"
  create_namespace = false

  set {
    name  = "settings.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = var.cluster_endpoint
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.karpenter_controller.arn
  }

  # Pin the controller to the static, non-Karpenter-managed node group so
  # it can never accidentally schedule itself onto a node it is
  # responsible for provisioning.
  set {
    name  = "tolerations[0].key"
    value = "platform.internal/critical-addons-only"
  }
  set {
    name  = "tolerations[0].operator"
    value = "Exists"
  }
  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }
}

# --- EC2NodeClass: what a Karpenter-provisioned node looks like ------------

resource "kubernetes_manifest" "ec2_node_class" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "default"
    }
    spec = {
      amiFamily = "AL2023"
      role      = "${var.cluster_name}-static-node-group-role"
      subnetSelectorTerms = [
        for id in var.private_subnet_ids : { id = id }
      ]
      securityGroupSelectorTerms = [
        { tags = { "karpenter.sh/discovery" = var.cluster_name } }
      ]
      tags = var.tags
    }
  }

  depends_on = [helm_release.karpenter]
}

# --- NodePool: how tenant workloads get scheduled onto new nodes -----------

resource "kubernetes_manifest" "default_node_pool" {
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "tenant-default"
    }
    spec = {
      template = {
        spec = {
          requirements = [
            { key = "karpenter.k8s.aws/instance-family", operator = "In", values = var.instance_families },
            { key = "karpenter.sh/capacity-type", operator = "In", values = var.capacity_type },
            { key = "kubernetes.io/arch", operator = "In", values = ["amd64"] },
          ]
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "default"
          }
        }
      }
      disruption = {
        consolidationPolicy = var.consolidation_policy
        expireAfter         = "720h" # force node recycling at 30 days regardless of activity
      }
      limits = {
        cpu = "1000"
      }
    }
  }

  depends_on = [kubernetes_manifest.ec2_node_class]
}
