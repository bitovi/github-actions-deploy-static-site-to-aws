terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.30"
    }
  }

  backend "s3" {
    region  = "${var.aws_default_region}"
    bucket  = "${var.aws_tf_state_bucket}"
    key     = "tf-state-spa"
    encrypt = true #AES-256encryption
  }
}

provider "aws" {
  region = "${var.aws_default_region}"
  default_tags {
    tags = merge(
      local.aws_tags,
      var.aws_additional_tags
    )
  }
}

locals {
  aws_tags = {
    AWSResourceIdentifier     = "${var.aws_resource_identifier}"
    GitHubOrgName             = "${var.app_org_name}"
    GitHubRepoName            = "${var.app_repo_name}"
    GitHubBranchName          = "${var.app_branch_name}"
    GitHubAction              = "bitovi/github-actions-deploy-serverless-website"
    created_with              = "terraform"
  }
}
