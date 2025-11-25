#!/bin/bash

set -e

GITHUB_IDENTIFIER="$($GITHUB_ACTION_PATH/scripts/generate_identifier.sh)"
GITHUB_IDENTIFIER_SS="$($GITHUB_ACTION_PATH/scripts/generate_identifier.sh 30)"

# Generate TF_STATE_BUCKET ID if empty 
if [ -z "${TF_STATE_BUCKET}" ]; then
  #  Add trailing id depending on name length - See AWS S3 bucket naming rules
  if [[ ${#GITHUB_IDENTIFIER} -lt 55 ]]; then
    export TF_STATE_BUCKET="${GITHUB_IDENTIFIER}-tf-state"
  else
    export TF_STATE_BUCKET="${GITHUB_IDENTIFIER}-tf"
  fi
fi

echo "Attempting to delete bucket: $TF_STATE_BUCKET"

aws s3 rb s3://$TF_STATE_BUCKET --force