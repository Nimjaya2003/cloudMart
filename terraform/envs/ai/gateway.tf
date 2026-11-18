
variable "catalog_base_url" {
  type        = string
  description = "Base URL of the CloudMart catalog API"
}

data "aws_caller_identity" "gateway_account" {}

# ==========================================
# 1. Package the Lambda function
# ==========================================

data "archive_file" "catalog_tool" {
  type = "zip"

  source_file = "${path.root}/../../../tools/gateway/catalog/handler.py"

  output_path = "${path.root}/.terraform/catalog-tool.zip"
}

# ==========================================
# 2. Lambda execution role
# ==========================================

resource "aws_iam_role" "catalog_tool_lambda" {
  name = "cloudmart-dev-catalog-tool-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"

      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "catalog_tool_logs" {
  role = aws_iam_role.catalog_tool_lambda.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ==========================================
# 3. CloudWatch log group
# ==========================================

resource "aws_cloudwatch_log_group" "catalog_tool" {
  name              = "/aws/lambda/cloudmart-dev-catalog-tool"
  retention_in_days = 7
}

# ==========================================
# 4. Lambda function
# ==========================================

resource "aws_lambda_function" "catalog_tool" {
  function_name = "cloudmart-dev-catalog-tool"

  role    = aws_iam_role.catalog_tool_lambda.arn
  runtime = "python3.12"
  handler = "handler.lambda_handler"

  filename         = data.archive_file.catalog_tool.output_path
  source_code_hash = data.archive_file.catalog_tool.output_base64sha256

  timeout     = 15
  memory_size = 128

  environment {
    variables = {
      CLOUDMART_API_URL = var.catalog_base_url
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.catalog_tool_logs,
    aws_cloudwatch_log_group.catalog_tool
  ]
}

# ==========================================
# 5. AgentCore Gateway execution role
# ==========================================

resource "aws_iam_role" "agentcore_gateway" {
  name = "cloudmart-dev-agentcore-gateway-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"

      Principal = {
        Service = "bedrock-agentcore.amazonaws.com"
      }

      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.gateway_account.account_id
        }

        ArnLike = {
          "aws:SourceArn" = "arn:aws:bedrock-agentcore:ap-south-1:${data.aws_caller_identity.gateway_account.account_id}:gateway/cloudmart-dev-gateway-*"
        }
      }
    }]
  })
}

# Gateway may invoke only our catalog Lambda
resource "aws_iam_role_policy" "gateway_invoke_catalog" {
  name = "invoke-catalog-tool"
  role = aws_iam_role.agentcore_gateway.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.catalog_tool.arn
    }]
  })
}

# ==========================================
# 6. AgentCore Gateway
# ==========================================

resource "aws_bedrockagentcore_gateway" "cloudmart" {
  name            = "cloudmart-dev-gateway"
  description     = "CloudMart live microservice tools"
  role_arn        = aws_iam_role.agentcore_gateway.arn
  protocol_type   = "MCP"
  authorizer_type = "AWS_IAM"

  depends_on = [
    aws_iam_role_policy.gateway_invoke_catalog
  ]
}

# ==========================================
# 7. Register the catalog Lambda as a target
# ==========================================

resource "aws_bedrockagentcore_gateway_target" "catalog" {
  name               = "catalog"
  description        = "Read-only CloudMart catalog tools"
  gateway_identifier = aws_bedrockagentcore_gateway.cloudmart.gateway_id

  credential_provider_configuration {
    gateway_iam_role {}
  }

  target_configuration {
    mcp {
      lambda {
        lambda_arn = aws_lambda_function.catalog_tool.arn

        tool_schema {
          inline_payload {
            name = "search_products"

            description = "Search the live CloudMart catalog by product keywords and optional maximum price in USD. Returns current product details and available stock fields."

            input_schema {
              type = "object"

              property {
                name        = "query"
                type        = "string"
                description = "Product search keywords"
                required    = true
              }

              property {
                name        = "max_price"
                type        = "number"
                description = "Maximum product price in USD"
              }
            }
          }
          inline_payload {
            name = "get_product"

            description = "Retrieve current details, price and stock for a specific CloudMart product using its numeric product ID."

            input_schema {
              type = "object"

              property {
                name        = "product_id"
                type        = "integer"
                description = "Positive integer product identifier"
                required    = true
              }
            }
          }
        }
      }
    }
  }
}
