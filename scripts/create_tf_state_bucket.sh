#!/bin/bash

set -e

# Constants
readonly MAX_BUCKET_NAME_LENGTH=63

echo ""
if [[ ${#TF_STATE_BUCKET} -gt $MAX_BUCKET_NAME_LENGTH ]]; then
  echo "::error::Bucket name exceeds ${MAX_BUCKET_NAME_LENGTH} character limit: ${TF_STATE_BUCKET} (${#TF_STATE_BUCKET} characters)"
  exit 63
else
  echo "Creating TF_STATE_BUCKET: $TF_STATE_BUCKET"
  if [ "$AWS_DEFAULT_REGION" == "us-east-1" ]; then
    aws s3api create-bucket --bucket "$TF_STATE_BUCKET" --region "$AWS_DEFAULT_REGION" || true
  else
    aws s3api create-bucket --bucket "$TF_STATE_BUCKET" --region "$AWS_DEFAULT_REGION" --create-bucket-configuration LocationConstraint="$AWS_DEFAULT_REGION" || true
  fi
  touch bitovi-test-file.txt
  if ! [[ -z $(aws s3api put-object --bucket "$TF_STATE_BUCKET" --key bitovi-test-file.txt --body ./bitovi-test-file.txt 2>&1 >/dev/null ) ]]; then
    echo "::error::Permission issue: Unable to write to the bucket ${TF_STATE_BUCKET}"
    echo "::error::Verify AWS credentials have s3:PutObject permission"
    exit 63
  else
      if ! [[ $(aws s3 rm "s3://$TF_STATE_BUCKET/bitovi-test-file.txt" 2>&1 >/dev/null ) ]]; then
            echo "Access to bucket confirmed. Can create and delete a tf-state file"
      fi
  fi
  rm bitovi-test-file.txt
fi