terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"

  # Every resource gets these tags automatically
  default_tags {
    tags = {
      Project     = "cloudmart"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}