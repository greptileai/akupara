terraform {
  backend "s3" {
    key    = "terraform.tfstate"
  }
}
# Set bucket name, region, and profile in init -backend-config="[key]=[value]"