terraform {
  required_version = ">= 1.5.7, < 2.0"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.100.0" }
    random = { source = "hashicorp/random", version = "~> 3.7.2" }
  }
}
# Use AWS_PROFILE, environment credentials, or CloudShell's credential chain.
# Never put access keys in source code or provider arguments.
provider "aws" {
  region = "us-east-1"
  default_tags { tags = { Project = var.project_name, Course = "CLSC645", ManagedBy = "terraform" } }
}
provider "aws" {
  alias  = "dr"
  region = var.dr_region
  default_tags { tags = { Project = var.project_name, Course = "CLSC645", ManagedBy = "terraform" } }
}
data "aws_caller_identity" "current" {}
