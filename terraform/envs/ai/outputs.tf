
output "docs_bucket" {
  value = module.knowledge_base.docs_bucket
}

output "vector_bucket" {
  value = module.knowledge_base.vector_bucket
}

output "vector_index" {
  value = module.knowledge_base.vector_index
}

output "gateway_id" {
  value = aws_bedrockagentcore_gateway.cloudmart.gateway_id
}

output "gateway_arn" {
  value = aws_bedrockagentcore_gateway.cloudmart.gateway_arn
}

output "gateway_url" {
  value = aws_bedrockagentcore_gateway.cloudmart.gateway_url
}

output "catalog_lambda_name" {
  value = aws_lambda_function.catalog_tool.function_name
}

output "orders_lambda_name" {
  value = aws_lambda_function.orders_tool.function_name
}

output "orders_target_id" {
  value = aws_bedrockagentcore_gateway_target.orders.target_id
}