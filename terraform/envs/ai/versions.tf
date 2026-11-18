
terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28"
    }
  }
}

provider "aws" {
  region = "ap-south-1"

  default_tags {
    tags = {
      Project     = "cloudmart"
      Environment = "dev"
      Stack       = "ai"
      ManagedBy   = "terraform"
    }
  }
}
