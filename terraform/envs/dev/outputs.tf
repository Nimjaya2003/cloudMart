output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_app_subnet_ids" {
  value = module.vpc.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  value = module.vpc.private_db_subnet_ids
}

output "alb_sg_id" {
  value = module.security_groups.alb_sg_id
}

output "app_sg_id" {
  value = module.security_groups.app_sg_id
}

output "db_sg_id" {
  value = module.security_groups.db_sg_id
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "db_address" {
  value = module.rds.db_address
}

output "cart_table_name" {
  value = module.dynamodb.table_name
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_service_names" {
  value = module.ecs.service_names
}

output "github_actions_role_arn" {
  value = module.github_oidc.role_arn
}

output "order_events_topic_arn" {
  value = module.order_events.topic_arn
}

output "notifications_queue_url" {
  value = module.order_events.queue_url
}

output "notifications_dlq_url" {
  value = module.order_events.dlq_url
}

output "notifier_function_name" {
  value = module.order_events.function_name
}