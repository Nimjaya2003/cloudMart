locals {
  # First images, pushed by hand in Step 9. The pipeline replaces them (Part C).
  image_tag = "bootstrap"

  db_env = {
    DB_HOST = module.rds.db_address
    DB_PORT = tostring(module.rds.db_port)
    DB_NAME = module.rds.db_name
  }

  # The password comes from Secrets Manager, never from code
  db_secrets = {
    DB_USER     = "${module.rds.db_secret_arn}:username::"
    DB_PASSWORD = "${module.rds.db_secret_arn}:password::"
  }
}

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
  vpc_id = module.vpc.vpc_id
}

module "ecr" {
  source = "../../modules/ecr"

  name         = "cloudmart"
  repositories = ["frontend", "catalog", "cart", "orders"]
}

module "dynamodb" {
  source = "../../modules/dynamodb"

  name = "cloudmart-dev"
}

module "alb" {
  source = "../../modules/alb"

  name              = "cloudmart-dev"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security_groups.alb_sg_id

  services = {
    frontend = { health_path = "/" } # default: everything not matched below
    catalog = {
      health_path   = "/health"
      path_patterns = ["/api/catalog/*"]
      priority      = 10
    }
    cart = {
      health_path   = "/health"
      path_patterns = ["/api/cart/*"]
      priority      = 20
    }
    orders = {
      health_path   = "/health"
      path_patterns = ["/api/orders", "/api/orders/*"] # POST /api/orders has no trailing path
      priority      = 30
    }
  }
}

module "rds" {
  source = "../../modules/rds"

  name          = "cloudmart-dev"
  db_subnet_ids = module.vpc.private_db_subnet_ids
  db_sg_id      = module.security_groups.db_sg_id
}

# The cart service may touch ONLY the carts table, and only with these actions
data "aws_iam_policy_document" "cart_task" {
  statement {
    actions = [
      "dynamodb:Query",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:BatchWriteItem",
    ]
    resources = [module.dynamodb.table_arn]
  }
}

module "ecs" {
  source = "../../modules/ecs"

  name               = "cloudmart-dev"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_app_subnet_ids
  app_sg_id          = module.security_groups.app_sg_id
  db_secret_arn      = module.rds.db_secret_arn

  services = {
    frontend = {
      image            = "${module.ecr.repository_urls["frontend"]}:${local.image_tag}"
      target_group_arn = module.alb.target_group_arns["frontend"]
    }

    catalog = {
      image            = "${module.ecr.repository_urls["catalog"]}:${local.image_tag}"
      target_group_arn = module.alb.target_group_arns["catalog"]
      environment      = local.db_env
      secrets          = local.db_secrets
      discovery        = true # orders calls catalog.cloudmart.local
    }

    cart = {
      image            = "${module.ecr.repository_urls["cart"]}:${local.image_tag}"
      target_group_arn = module.alb.target_group_arns["cart"]
      environment = {
        AWS_REGION = "ap-south-1"
        CART_TABLE = module.dynamodb.table_name
      }
      discovery = true # orders calls cart.cloudmart.local
    }

    orders = {
      image            = "${module.ecr.repository_urls["orders"]}:${local.image_tag}"
      target_group_arn = module.alb.target_group_arns["orders"]
      environment = merge(local.db_env, {
        CATALOG_URL = "http://catalog.cloudmart.local:8080"
        CART_URL    = "http://cart.cloudmart.local:8080"
      })
      secrets = local.db_secrets
    }
  }

  task_policies = {
    cart = data.aws_iam_policy_document.cart_task.json
  }

  # Target groups must be attached to the listener before services can use them
  depends_on = [module.alb]
}

module "github_oidc" {
  source = "../../modules/github-oidc"

  name            = "cloudmart-dev"
  github_repo     = "Nimjaya2003/cloudMart"
  github_owner_id = "214961230"
  github_repo_id  = "1427944852"
}