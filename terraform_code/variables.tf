variable "aws_resource_identifier" {
  type        = string
  description = "Identifier to use for AWS resources (defaults to GITHUB_ORG-GITHUB_REPO-GITHUB_BRANCH)"
}

variable "aws_resource_identifier_supershort" {
  type        = string
  description = "Identifier to use for AWS resources (defaults to GITHUB_ORG-GITHUB_REPO-GITHUB_BRANCH) shortened to 30 chars"
}

variable "aws_additional_tags" {
  type        = map(string)
  description = "A list of strings that will be added to created resources"
  default     = {}
}

variable "aws_tf_state_bucket" {
  type        = string
  description = "Bucket to store tf-state file for the deployment"
}

variable "aws_site_source_folder" {
  description = "Sources to be stored in the bucket. Coma sepparated list of files possible."
  type        = string
  default     = ""
}

variable "aws_site_root_object" {
  description = "Root object. Defaults to index.html"
  type        = string
  default     = "index.html"
}

variable "aws_site_error_document" {
  description = "Error document. Defaults to none"
  type        = string
  default     = ""
}

variable "aws_site_bucket_name" {
  description = "Bucket name where all the files will be stored."
  type        = string
  default     = ""
}

variable "aws_site_cdn_enabled" {
  description = "Enable or not CDN for site"
  type        = bool
  default     = false
}

variable "aws_site_cdn_aliases" {
  description = "Aliases or CNAMES for CDN"
  type        = string
  default     = ""
}

variable "aws_site_cdn_custom_error_codes" {
  description = "Custom error codes for site"
  type        = string
  default     = "{}"
}

variable "aws_r53_domain_name" {
  description = "root domain name without any subdomains"
  type        = string
  default     = ""
}

variable "aws_r53_sub_domain_name" {
  type        = string
  description = "Subdomain name for DNS record"
  default     = ""
}

variable "aws_r53_root_domain_deploy" {
  type        = bool
  description = "deploy to root domain"
  default     = false
}

variable "aws_r53_enable_cert" {
  type        = bool
  description = "Enable AWS Certificate management."
  default     = true
}

variable "aws_r53_cert_arn" {
  type        = string
  description = "Certificate ARN to use"
  default     = ""
}

variable "aws_r53_create_root_cert" {
  type        = bool
  description = "deploy to root domain"
  default     = false
}

variable "aws_r53_create_sub_cert" {
  type        = bool
  description = "deploy to root domain"
  default     = false
}

#### The following are not being exposed directly to the end user

variable "app_repo_name" {
  type        = string
  description = "GitHub Repo Name"
}
variable "app_org_name" {
  type        = string
  description = "GitHub Org Name"
}
variable "app_branch_name" {
  type        = string
  description = "GitHub Branch Name"
}

locals {
  aws_tags = {
    AWSResourceIdentifier     = "${var.aws_resource_identifier}"
    GitHubOrgName             = "${var.app_org_name}"
    GitHubRepoName            = "${var.app_repo_name}"
    GitHubBranchName          = "${var.app_branch_name}"
    GitHubAction              = "bitovi/github-actions-deploy-static-site-to-aws"
    created_with              = "terraform"
  }
}
