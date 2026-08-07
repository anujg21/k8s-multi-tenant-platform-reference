terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host                   = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks_cluster.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks_cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks_cluster.cluster_name]
    }
  }
}

# --- Plane 1: the cluster itself + a minimal static node group for
#     critical add-ons (see docs/architecture.md) --------------------------

module "eks_cluster" {
  source = "./modules/eks-cluster"

  cluster_name        = var.cluster_name
  vpc_id              = var.vpc_id
  private_subnet_ids  = var.private_subnet_ids
  tags                = var.tags
}

# --- Plane 2: dynamic compute provisioning (ADR-0001) ----------------------

module "karpenter" {
  source = "./modules/karpenter"

  cluster_name             = module.eks_cluster.cluster_name
  cluster_endpoint         = module.eks_cluster.cluster_endpoint
  cluster_oidc_issuer_url  = module.eks_cluster.cluster_oidc_issuer_url
  private_subnet_ids       = var.private_subnet_ids
  tags                     = var.tags

  depends_on = [module.eks_cluster]
}

# --- Plane 3: one tenancy boundary per team (ADR-0002) ----------------------
# Onboarding a new team = adding a name to var.tenant_teams (in practice,
# a directory in the deployment repo picked up by the ApplicationSet in
# gitops/argocd/applicationset-tenants.yaml) — not a new cluster, not a
# new Terraform module, not a new CI pipeline.

module "tenant" {
  source   = "./modules/tenancy"
  for_each = toset(var.tenant_teams)

  team_name = each.value
  labels    = var.tags

  depends_on = [module.karpenter]
}
