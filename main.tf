### Terraform Cloud Info as Backend Storage and execution ###
terraform {
  cloud {
    hostname     = "app.terraform.io"
    organization = "Insideinfo"
    workspaces {
      name = "INSIDE_AWS_LAB_EKSCLUSTER"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.10.0"
    }
  }
}

### AWS Provider Info ###
provider "aws" {
  region = var.region
}

### KUBE Provider Settings
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

locals {
  common-tags = {
    author      = "DonghwanLim"
    system      = "LAB"
    Environment = "INSIDE_AWS_EKSCLUSTERS"
  }
}

locals {
  cluster_name = "INSIDE_learnk8s"
}

### AWS NETWORK Config GET ###
data "terraform_remote_state" "network" {
  backend = "remote"
  config = {
    organization = "Insideinfo"
    workspaces = {
      name = "INSIDE_AWS_LABNET"
    }
  }
}

### AWS SGs Config GET ###
data "terraform_remote_state" "security" {
  backend = "remote"
  config = {
    organization = "Insideinfo"
    workspaces = {
      name = "INSIDE_AWS_LABSGs"
    }
  }
}

### GET AWS AZs in Region
data "aws_availability_zones" "available" {}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

### EKS Kube Config

module "eks-kubeconfig" {
  source  = "hyperbadger/eks-kubeconfig/aws"
  version = "1.0.0"

  depends_on = [module.eks]
  cluster_id = module.eks.cluster_id
}


resource "local_file" "kubeconfig" {
  content  = module.eks-kubeconfig.kubeconfig
  filename = "kubeconfig_${local.cluster_name}"
}


### EKS Module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = local.cluster_name
  cluster_version = "1.24"
  vpc_id = data.terraform_remote_state.network.outputs.vpc01_id
  subnet_ids      = [data.terraform_remote_state.network.outputs.vpc01_public_subnet_01_id, data.terraform_remote_state.network.outputs.vpc01_public_subnet_02_id]

  eks_managed_node_group_defaults = {
    instance_types = ["t3.small", "t3.micro"]
  }

  eks_managed_node_groups = {
    first = {
      desired_capacity = 1
      max_capacity     = 10
      min_capacity     = 1

      instance_type   = ["t3.small"]
      key_name        = "INSIDE_EC2_KEYPAIR"
    }
  }
}

module "eks_blueprints_addons" {
  source = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0" #ensure to update this to the latest/desired version

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  eks_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
  }

  enable_aws_load_balancer_controller    = true
  enable_cluster_proportional_autoscaler = true
  enable_karpenter                       = true
  enable_kube_prometheus_stack           = true
  enable_metrics_server                  = true
  enable_external_dns                    = true
  enable_cert_manager                    = true
  #cert_manager_route53_hosted_zone_arns  = ["arn:aws:route53:::hostedzone/XXXXXXXXXXXXX"]

  tags = {
    Environment = "dev"
  }
}