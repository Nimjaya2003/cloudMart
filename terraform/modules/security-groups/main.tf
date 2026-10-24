# ---------- The three security groups (empty shells first) ----------
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Load balancer: accepts web traffic from the internet"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-alb-sg" }
}

resource "aws_security_group" "app" {
  name        = "${var.name}-app-sg"
  description = "ECS tasks: accept traffic only from the ALB"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-app-sg" }
}

resource "aws_security_group" "db" {
  name        = "${var.name}-db-sg"
  description = "Database: accept traffic only from the app tier"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-db-sg" }
}

# ---------- ALB rules ----------
# Inbound: HTTP from anywhere (HTTPS can be added later with a certificate)
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from the internet"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# Outbound: only to the app tier, only on the app port
resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward traffic to app tier"
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
}

# ---------- App rules ----------
# Inbound: only from the ALB's security group
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "App port from ALB only"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
}

# Outbound: all (needs the NAT to pull images from ECR and reach the DB)
resource "aws_vpc_security_group_egress_rule" "app_all_out" {
  security_group_id = aws_security_group.app.id
  description       = "Outbound for ECR pulls, logs and DB access"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------- DB rules ----------
# Inbound: only from the app's security group
resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "Database port from app tier only"
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
}
# No egress rules on purpose: the DB never starts outbound connections.