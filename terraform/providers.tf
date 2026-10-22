provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project    = "eks-gitops-platform"
      ManagedBy  = "terraform"
      Repository = "github.com/dami-wasabi/eks-gitops-platform"
    }
  }
}

# Talks to the new cluster with a short-lived token from the AWS CLI, so no
# kubeconfig or long-lived credentials are written anywhere.
provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
    }
  }
}
