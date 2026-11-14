resource "aws_lb" "this" {
  name                       = "${var.name}-alb"
  load_balancer_type         = "application"
  internal                   = false
  security_groups            = [var.alb_sg_id]
  subnets                    = var.public_subnet_ids
  drop_invalid_header_fields = true
  tags                       = { Name = "${var.name}-alb" }
}

# One target group per service
resource "aws_lb_target_group" "this" {
  for_each = var.services

  name        = "${var.name}-${each.key}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Fargate tasks are registered by IP

  deregistration_delay = 30

  health_check {
    path                = each.value.health_path
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[var.default_service].arn
  }
}

# One path rule per non-default service
resource "aws_lb_listener_rule" "this" {
  for_each = { for k, v in var.services : k => v if k != var.default_service }

  listener_arn = aws_lb_listener.http.arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.key].arn
  }

  condition {
    path_pattern {
      values = each.value.path_patterns
    }
  }
}