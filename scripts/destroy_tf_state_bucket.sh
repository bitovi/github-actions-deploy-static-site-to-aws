#!/bin/bash

set -e

# Constants
readonly SHORT_IDENTIFIER_LENGTH=30
readonly MIN_BUCKET_NAME_FOR_TF_STATE_SUFFIX=55

GITHUB_IDENTIFIER="$($GITHUB_ACTION_PATH/scripts/generate_identifier.sh)"
GITHUB_IDENTIFIER_SS="$($GITHUB_ACTION_PATH/scripts/generate_identifier.sh $SHORT_IDENTIFIER_LENGTH)"

# Generate TF_STATE_BUCKET ID if empty 
if [ -z "${TF_STATE_BUCKET}" ]; then
  #  Add trailing id depending on name length - See AWS S3 bucket naming rules
  if [[ ${#GITHUB_IDENTIFIER} -lt $MIN_BUCKET_NAME_FOR_TF_STATE_SUFFIX ]]; then
    export TF_STATE_BUCKET="${GITHUB_IDENTIFIER}-tf-state"
  else
    export TF_STATE_BUCKET="${GITHUB_IDENTIFIER}-tf"
  fi
fi

echo "Attempting to delete bucket: $TF_STATE_BUCKET"

if ! aws s3 rb "s3://$TF_STATE_BUCKET" --force 2>&1; then
  echo "::warning::Failed to delete bucket ${TF_STATE_BUCKET}. It may not exist or may contain versioned objects."
fi
