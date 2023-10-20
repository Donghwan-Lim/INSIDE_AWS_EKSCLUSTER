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
      version = "5.21.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.23.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.11.0"
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

### Helm Provider Settings
provider "helm" {
  # Configuration options
  kubernetes {
    #config_path = module.eks-kubeconfig.kubeconfig
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

/* 
 provider "kubectl" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}
*/

locals {
  common-tags = {
    author      = "DonghwanLim"
    system      = "LAB"
    Environment = "INSIDE_AWS_EKSCLUSTERS"
  }
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



locals {
  # Local Variable EKS Cluster Name
  cluster_name = "INSIDE_EKS_CLUSTER_1_24"
}

### EKS Module
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  # version = "~> 19.0" # module.eks.cluster_id output error 발생
  version = "~> 18.0"

  cluster_name                          = local.cluster_name
  cluster_version                       = "1.24"
  vpc_id                                = data.terraform_remote_state.network.outputs.vpc01_id
  subnet_ids                            = [data.terraform_remote_state.network.outputs.vpc01_public_subnet_01_id, data.terraform_remote_state.network.outputs.vpc01_public_subnet_02_id]
  cluster_additional_security_group_ids = [data.terraform_remote_state.security.outputs.vpc1-public-vm-sg-id]

  cluster_addons = {
    aws-ebs-csi-driver = {
      addon_version     = "v1.23.1-eksbuild.1"
    }
    aws-efs-csi-driver = {
      addon_version     = "v1.7.0-eksbuild.1"
    }
    coredns = {
      resolve_conflicts_on_create = "OVERWRITE"
      addon_version     = "v1.8.7-eksbuild.3"
    }
    kube-proxy = {
      addon_version = "v1.24.7-eksbuild.2"
    }
    vpc-cni = {
      resolve_conflicts_on_create = "OVERWRITE"
      addon_version     = "v1.11.4-eksbuild.1"
    }
  }

  eks_managed_node_group_defaults = {
    instance_types = ["m5.xlarge", "m5.large", "t3.medium", "t3.small"]
  }

  eks_managed_node_groups = {
    kbc-stg-eks-1-2-4 = {
      key_name      = "INSIDE_EC2_KEYPAIR"
      instance_types = ["m5.xlarge"]
      min_size     = 2
      max_size     = 2
      desired_size = 2
    }
  }
}

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0" #ensure to update this to the latest/desired version

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  depends_on = [ module.eks ] # eks 리소스 생성 후 addon 설치

  enable_aws_load_balancer_controller = true
  enable_cluster_autoscaler = true
  #enable_karpenter                       = true
  #enable_kube_prometheus_stack           = true
  enable_metrics_server = true
  enable_external_dns   = true
  enable_cert_manager   = true
  enable_argocd = true
  #cert_manager_route53_hosted_zone_arns  = ["arn:aws:route53:::hostedzone/XXXXXXXXXXXXX"]

  
  /*
  eks_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
    aws-efs-csi-driver = {
      most_recent = true
    }
    coredns = {
      version = "v1.9.3-eksbuild.6" # 작동 안함
    }
    vpc-cni = {
      version = "v1.14.0-eksbuild.3" # 작동 안함
    }
    kube-proxy = {
      version = "v1.24.17-eksbuild.2" # 작동안함
    }
  }
*/

}