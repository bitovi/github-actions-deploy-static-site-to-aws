#!/bin/bash

set -e

# TODO: use templating
#    provide '.tf.tmpl' files in the 'operations/deployment' repo
#    and iterate over all of them to provide context with something like jinja
#    Example: https://github.com/mattrobenolt/jinja2-cli
#    jinja2 some_file.tmpl data.json --format=json

echo "In generate_provider.sh"

function generate_tf_state_file_name () {
  if [ -n "$TF_STATE_FILE_NAME" ]; then
    filename="$TF_STATE_FILE_NAME"
  else
    filename="tf-state-$1"
  fi

  if [ -n "$TF_STATE_FILE_NAME_APPEND" ]; then
    filename="${filename}-${TF_STATE_FILE_NAME_APPEND}"
  fi
  echo $filename
}

#echo "
#terraform {
#  required_providers {
#    aws = {
#      source  = \"hashicorp/aws\"
#      version = \"~> 4.30\"
#    }
#    random = {
#      source  = \"hashicorp/random\"
#      version = \">= 2.2\"
#    }
#  }
#
#  backend \"s3\" {
#    region  = \"${AWS_DEFAULT_REGION}\"
#    bucket  = \"${TF_STATE_BUCKET}\"
#    key     = \"$(generate_tf_state_file_name site)\"
#    encrypt = true #AES-256encryption
#  }
#}

if [ "$LOCALSTACK" = "true" ]; then
  cat <<EOF > "${GITHUB_ACTION_PATH}/terraform_code/provider.tf"
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.30"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 2.2"
    }
  }

  backend "s3" {
    region  = "${AWS_DEFAULT_REGION}"
    bucket  = "${TF_STATE_BUCKET}"
    key     = "$(generate_tf_state_file_name site)"
    encrypt = true #AES-256encryption
  }
}

provider "aws" {
  access_key                  = var.aws_access_key
  secret_key                  = var.aws_secret_key
  region                      = var.aws_region
  s3_force_path_style         = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  endpoints = {
    s3         = var.endpoint_url
    cloudfront = var.endpoint_url
    route53    = var.endpoint_url
    acm        = var.endpoint_url
    iam        = var.endpoint_url
    sts        = var.endpoint_url
  }
}
EOF
else
  cat <<EOF > "${GITHUB_ACTION_PATH}/terraform_code/provider.tf"
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.30"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 2.2"
    }
  }

  backend "s3" {
    region  = "${AWS_DEFAULT_REGION}"
    bucket  = "${TF_STATE_BUCKET}"
    key     = "$(generate_tf_state_file_name site)"
    encrypt = true #AES-256encryption
  }
}

provider "aws" {
  region = "${AWS_DEFAULT_REGION}"
  default_tags {
    tags = merge(
      local.aws_tags,
      var.aws_additional_tags
    )
  }
}
EOF
fi