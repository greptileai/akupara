terraform {
  backend "s3" {}
}
# Configure bucket, dynamodb_table, profile, and region during terraform init via -backend-config.
