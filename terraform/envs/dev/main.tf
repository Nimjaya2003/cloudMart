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

module "alb" {
  source = "../../modules/alb"

  name              = "cloudmart-dev"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security_groups.alb_sg_id
}

module "rds" {
  source = "../../modules/rds"

  name          = "cloudmart-dev"
  db_subnet_ids = module.vpc.private_db_subnet_ids
  db_sg_id      = module.security_groups.db_sg_id
}
module "ecs" {
  source = "../../modules/ecs"

  name               = "cloudmart-dev"
  private_subnet_ids = module.vpc.private_app_subnet_ids
  app_sg_id          = module.security_groups.app_sg_id

  frontend_image = "${module.ecr.repository_urls["frontend"]}:v1"
  backend_image  = "${module.ecr.repository_urls["backend"]}:v1"

  frontend_tg_arn = module.alb.frontend_tg_arn
  backend_tg_arn  = module.alb.backend_tg_arn

  db_address    = module.rds.db_address
  db_port       = module.rds.db_port
  db_name       = module.rds.db_name
  db_secret_arn = module.rds.db_secret_arn

  # A target group must be attached to a listener before a service can use it
  depends_on = [module.alb]
}