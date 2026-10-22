# Partial configuration: supply bucket and region at init time.
#   terraform init -backend-config="bucket=<state-bucket>" -backend-config="region=us-east-1"
terraform {
  backend "s3" {
    key          = "eks-gitops-platform/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
