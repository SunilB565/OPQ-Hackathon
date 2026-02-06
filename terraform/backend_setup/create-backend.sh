#!/usr/bin/env bash
set -euo pipefail
AWS_REGION=${1:-us-east-1}
BUCKET_NAME=${2:-hackathon-terraform-state-$(date +%s)}
LOCK_TABLE=${3:-hackathon-terraform-lock}

echo "Creating S3 bucket: $BUCKET_NAME in region $AWS_REGION"
aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" --create-bucket-configuration LocationConstraint=$AWS_REGION || true

echo "Enabling versioning"
aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled

echo "Creating DynamoDB table: $LOCK_TABLE"
aws dynamodb create-table --table-name "$LOCK_TABLE" --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --region "$AWS_REGION" || true

echo "Backend setup complete. Use the following backend config in Terraform:"
cat <<EOF
terraform {
  backend "s3" {
    bucket = "$BUCKET_NAME"
    key    = "hackathon/terraform.tfstate"
    region = "$AWS_REGION"
    dynamodb_table = "$LOCK_TABLE"
    encrypt = true
  }
}
EOF
