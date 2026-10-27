locals {
  scalable_services = {
    frontend = aws_ecs_service.frontend.name
    backend  = aws_ecs_service.backend.name
  }
}

# Register each service as something that can scale between min and max tasks
resource "aws_appautoscaling_target" "this" {
  for_each = local.scalable_services

  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"
  resource_id        = "service/${aws_ecs_cluster.this.name}/${each.value}"
  min_capacity       = var.min_capacity
  max_capacity       = var.max_capacity
}

# Target tracking: keep average CPU near the target, like a thermostat
resource "aws_appautoscaling_policy" "cpu" {
  for_each = aws_appautoscaling_target.this

  name               = "${var.name}-${each.key}-cpu-target"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = each.value.service_namespace
  scalable_dimension = each.value.scalable_dimension
  resource_id        = each.value.resource_id

  target_tracking_scaling_policy_configuration {
    target_value       = var.cpu_target
    scale_out_cooldown = 60  # add tasks quickly
    scale_in_cooldown  = 120 # remove tasks cautiously

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}