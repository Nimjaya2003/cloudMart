module "vpc" {
  source = "../../modules/vpc"

  name                     = "cloudmart-dev"
  vpc_cidr                 = "10.0.0.0/16"
  azs                      = ["ap-south-1a", "ap-south-1b"]
  public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24"]
  private_app_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
  private_db_subnet_cidrs  = ["10.0.21.0/24", "10.0.22.0/24"]
}
module "security_groups" {
  source = "../../modules/security-groups"

  name   = "cloudmart-dev"
  vpc_id = module.vpc.vpc_id # output of the VPC module feeds this one
}

module "ecr" {
  source = "../../modules/ecr"

  name         = "cloudmart"
  repositories = ["frontend", "backend"]
}