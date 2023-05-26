#  AWS_ACCESS_KEY_ID: ${{ inputs.aws_access_key_id }}
#  AWS_SECRET_ACCESS_KEY: ${{ inputs.aws_secret_access_key }}
#  AWS_SESSION_TOKEN: ${{ inputs.aws_session_token }}
#  AWS_DEFAULT_REGION: ${{ inputs.aws_default_region }}

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

variable "aws_spa_website_bucket_name" {
  description = "Bucket name where all the files will be stored."
  type        = string
  default     = ""
}

variable "aws_spa_cdn_enabled" {
  description = "Enable or not CDN for site"
  type        = boolean
  default     = false
}

variable "aws_spa_cdn_root_object" {
  description = "Root object for CDN. Defaults to index.html"
  type        = string
  default     = index.html
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
  default     = false
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