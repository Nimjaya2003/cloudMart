
# ==========================================
# 1. Demo order configuration
# ==========================================

variable "demo_order_id" {
  type        = number
  description = "Allowed synthetic development order ID"

  validation {
    condition = (
      var.demo_order_id >= 1 &&
      floor(var.demo_order_id) == var.demo_order_id
    )
    error_message = "Demo order ID must be a positive integer."
  }
}

variable "demo_cart_id" {
  type        = string
  description = "Cart ID belonging to the synthetic order"

  validation {
    condition     = length(var.demo_cart_id) > 0
    error_message = "Demo cart ID must not be empty."
  }
}


# ==========================================
# 2. Package Orders Lambda code
# ==========================================

data "archive_file" "orders_tool" {
  type = "zip"

  source_file = "${path.root}/../../../tools/gateway/orders/handler.py"

  output_path = "${path.root}/.terraform/orders-tool.zip"
}


# ==========================================
# 3. Orders Lambda execution role
# ==========================================

resource "aws_iam_role" "orders_tool_lambda" {
  name = "cloudmart-dev-orders-tool-role"

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


# ==========================================
# 4. CloudWatch logging permissions
# ==========================================

resource "aws_iam_role_policy_attachment" "orders_tool_logs" {
  role = aws_iam_role.orders_tool_lambda.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "orders_tool" {
  name              = "/aws/lambda/cloudmart-dev-orders-tool"
  retention_in_days = 7
}


# ==========================================
# 5. Orders Lambda function
# ==========================================

resource "aws_lambda_function" "orders_tool" {
  function_name = "cloudmart-dev-orders-tool"

  role    = aws_iam_role.orders_tool_lambda.arn
  runtime = "python3.12"
  handler = "handler.lambda_handler"

  filename         = data.archive_file.orders_tool.output_path
  source_code_hash = data.archive_file.orders_tool.output_base64sha256

  timeout     = 15
  memory_size = 128

  environment {
    variables = {
      CLOUDMART_API_URL = var.catalog_base_url
      DEMO_ORDER_ID     = tostring(var.demo_order_id)
      DEMO_CART_ID      = var.demo_cart_id
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.orders_tool_logs,
    aws_cloudwatch_log_group.orders_tool
  ]
}


# ==========================================
# 6. Allow existing Gateway to invoke Lambda
# ==========================================

resource "aws_iam_role_policy" "gateway_invoke_orders" {
  name = "invoke-orders-tool"

  role = aws_iam_role.agentcore_gateway.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.orders_tool.arn
    }]
  })
}


# ==========================================
# 7. Register Orders Gateway target
# ==========================================

resource "aws_bedrockagentcore_gateway_target" "orders" {
  name               = "orders"
  description        = "Restricted CloudMart demo order status tool"
  gateway_identifier = aws_bedrockagentcore_gateway.cloudmart.gateway_id

  credential_provider_configuration {
    gateway_iam_role {}
  }

  target_configuration {
    mcp {
      lambda {
        lambda_arn = aws_lambda_function.orders_tool.arn

        tool_schema {
          inline_payload {
            name = "get_order_status"

            description = "Retrieve the current status of the configured synthetic CloudMart demo order. Not authorized for arbitrary customer orders."

            input_schema {
              type = "object"

              property {
                name        = "order_id"
                type        = "integer"
                description = "Positive integer demo order identifier"
                required    = true
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    aws_iam_role_policy.gateway_invoke_orders
  ]
}
