
terraform {
  backend "s3" {
    bucket       = "cloudmart-tfstate-nimjaya-2003"
    key          = "ai/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
