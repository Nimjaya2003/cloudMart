
# =============================================
# 1. Dedicated agent security group
# =============================================

resource "aws_security_group" "agent_ecs" {
  name        = "${local.agent_ecs_name}-sg"
  description = "Private access to CloudMart intelligent agent"
  vpc_id      = var.agent_vpc_id

  tags = {
    Name = "${local.agent_ecs_name}-sg"
  }
}


# =============================================
# 2. Allow trusted application services
# =============================================

resource "aws_vpc_security_group_ingress_rule" "agent_from_app" {
  for_each = var.agent_client_security_group_ids

  security_group_id = aws_security_group.agent_ecs.id

  referenced_security_group_id = each.value

  description = "Allow existing CloudMart applications"

  ip_protocol = "tcp"
  from_port   = 8080
  to_port     = 8080
}


# =============================================
# 3. Allow outbound network connectivity
# =============================================

resource "aws_vpc_security_group_egress_rule" "agent_outbound" {
  security_group_id = aws_security_group.agent_ecs.id

  description = "Outbound agent connectivity"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}


# =============================================
# 4. Private Cloud Map namespace
# =============================================

resource "aws_service_discovery_private_dns_namespace" "agent" {
  name        = "cloudmart-dev-ai.internal"
  description = "Private DNS for CloudMart AI services"

  vpc = var.agent_vpc_id
}


# =============================================
# 5. Register the agent as a discoverable service
# =============================================

resource "aws_service_discovery_service" "agent" {
  name = "agent"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.agent.id

    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}
