terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 6.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.4" }
  }
  backend "s3" {} # filled in by backend.hcl
}

provider "aws" {
  region = "us-east-1" # CloudFront certificates must live here
  default_tags {
    tags = { Project = var.project_name, ManagedBy = "terraform" }
  }
}
