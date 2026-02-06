/*
  Terraform S3 backend for remote state. Replace BUCKET_NAME and LOCK_TABLE
  with the values created by terraform/backend_setup/create-backend.sh or pass
  backend config via CLI: terraform init -backend-config="bucket=..." -backend-config="dynamodb_table=..."
*/
terraform {
  backend "s3" {
    bucket = "BUCKET_NAME"
    key    = "hackathon/prod/terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "LOCK_TABLE"
    encrypt = true
  }
}
