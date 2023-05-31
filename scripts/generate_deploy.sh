#!/bin/bash

set -e

echo "In $0"

function alpha_only() {
    echo "$1" | tr -cd '[:alpha:]' | tr '[:upper:]' '[:lower:]'
}

function generate_var () {
  if [[ -n "$2" ]];then
    if [[ $(alpha_only "$2") == "true" ]] || [[ $(alpha_only "$2") == "false" ]]; then
      echo "$1 = $(alpha_only $2)"
    else
      echo "$1 = \"$2\""
    fi
  fi
}

GITHUB_ORG_NAME=$(echo $GITHUB_REPOSITORY | sed 's/\/.*//')
GITHUB_REPO_NAME=$(echo $GITHUB_REPOSITORY | sed 's/^.*\///')

if [ -n "$GITHUB_HEAD_REF" ]; then
  GITHUB_BRANCH_NAME=${GITHUB_HEAD_REF}
else
  GITHUB_BRANCH_NAME=${GITHUB_REF_NAME}
fi

GITHUB_IDENTIFIER="$($GITHUB_ACTION_PATH/scripts/generate_identifier.sh)"
echo "GITHUB_IDENTIFIER: [$GITHUB_IDENTIFIER]"

GITHUB_IDENTIFIER_SS="$($GITHUB_ACTION_PATH/scripts/generate_identifier.sh 30)"
echo "GITHUB_IDENTIFIER SS: [$GITHUB_IDENTIFIER_SS]"

SOURCE_FILES="$GITHUB_WORKSPACE/$AWS_SPA_SOURCE_FOLDER"
rsync -av --exclude=".*" $SOURCE_FILES/ "${GITHUB_ACTION_PATH}/upload"
SOURCE_FILES="${GITHUB_ACTION_PATH}/upload"

# Generate TF_STATE_BUCKET ID if empty 
if [ -z "${TF_STATE_BUCKET}" ]; then
  #  Add trailing id depending on name length - See AWS S3 bucket naming rules
  if [[ ${#GITHUB_IDENTIFIER} < 55 ]]; then
    export TF_STATE_BUCKET="${GITHUB_IDENTIFIER}-tf-state"
  else
    export TF_STATE_BUCKET="${GITHUB_IDENTIFIER}-tf"
  fi
fi

# -------------------------------------------------- #
# Generator # 
# Function to generate the variable content based on the fact that it could be empty. 
# This way, we only pass terraform variables that are defined, hence not overwriting terraform defaults. 

# Removes anything from the variable and leave only alpha characters, and lowers them. This is to validate if boolean.
# Fixed values - Values that are hardcoded or come from other variables.

app_org_name="app_org_name = \"${GITHUB_ORG_NAME}\""
app_repo_name="app_repo_name = \"${GITHUB_REPO_NAME}\""
app_branch_name="app_branch_name = \"${GITHUB_BRANCH_NAME}\""
aws_resource_identifier="aws_resource_identifier = \"${GITHUB_IDENTIFIER}\""
aws_resource_identifier_supershort="aws_resource_identifier_supershort = \"${GITHUB_IDENTIFIER_SS}\""

aws_r53_sub_domain_name=
if [ -n "${AWS_R53_SUB_DOMAIN_NAME}" ]; then
  aws_r53_sub_domain_name="aws_r53_sub_domain_name = \"${AWS_R53_SUB_DOMAIN_NAME}\""
else
  aws_r53_sub_domain_name="aws_r53_sub_domain_name = \"${GITHUB_IDENTIFIER}\""
fi

aws_tf_state_bucket=$(generate_var aws_tf_state_bucket $TF_STATE_BUCKET)
#-- AWS Specific --#
aws_additional_tags=$(generate_var aws_additional_tags $AWS_ADDITIONAL_TAGS)
aws_default_region=$(generate_var aws_default_region $AWS_DEFAULT_REGION)
#aws_spa_source_folder=$(generate_var aws_spa_source_folder $AWS_SPA_SOURCE_FOLDER)
aws_spa_source_folder="aws_spa_source_folder = \"${SOURCE_FILES}\""
aws_spa_website_bucket_name=$(generate_var aws_spa_website_bucket_name $AWS_SPA_WEBSITE_BUCKET_NAME)
aws_spa_cdn_enabled=$(generate_var aws_spa_cdn_enabled $AWS_SPA_CDN_ENABLED)
aws_spa_root_object=$(generate_var aws_spa_root_object $aws_spa_root_object)
aws_r53_domain_name=$(generate_var aws_r53_domain_name $AWS_R53_DOMAIN_NAME)
aws_r53_root_domain_deploy=$(generate_var aws_r53_root_domain_deploy $AWS_R53_ROOT_DOMAIN_DEPLOY)
aws_r53_enable_cert=$(generate_var aws_r53_enable_cert $AWS_R53_ENABLE_CERT)
aws_r53_cert_arn=$(generate_var aws_r53_cert_arn $AWS_R53_CERT_ARN)
aws_r53_create_root_cert=$(generate_var aws_r53_create_root_cert $AWS_R53_CREATE_ROOT_CERT)
aws_r53_create_sub_cert=$(generate_var aws_r53_create_sub_cert $AWS_R53_CREATE_SUB_CERT)

# -------------------------------------------------- #

echo "
$aws_resource_identifier
$aws_resource_identifier_supershort
$aws_additional_tags
$aws_tf_state_bucket
$aws_spa_source_folder
$aws_spa_website_bucket_name
$aws_spa_cdn_enabled
$aws_spa_root_object
$aws_r53_domain_name
$aws_r53_sub_domain_name
$aws_r53_root_domain_deploy
$aws_r53_enable_cert
$aws_r53_cert_arn
$aws_r53_create_root_cert
$aws_r53_create_sub_cert
#### The following are not being exposed directly to the end user
$app_repo_name
$app_org_name
$app_branch_name
" > "${GITHUB_ACTION_PATH}/terraform_code/terraform.tfvars"

echo "Creating TF-STATE bucket"
/bin/bash $GITHUB_ACTION_PATH/scripts/check_bucket_name.sh $TF_STATE_BUCKET
/bin/bash $GITHUB_ACTION_PATH/scripts/create_tf_state_bucket.sh 

echo "Creating provider.tf"
/bin/bash $GITHUB_ACTION_PATH/scripts/generate_provider.sh 