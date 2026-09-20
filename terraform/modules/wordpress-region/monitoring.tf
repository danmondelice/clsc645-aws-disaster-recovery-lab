locals {
  alarms = merge({
    no-healthy-targets = { namespace = "AWS/ApplicationELB", metric = "HealthyHostCount", statistic = "Minimum", threshold = 1, comparison = "LessThanThreshold", missing = "breaching", dimensions = { LoadBalancer = aws_lb.this.arn_suffix, TargetGroup = aws_lb_target_group.wordpress.arn_suffix } },
    alb-5xx            = { namespace = "AWS/ApplicationELB", metric = "HTTPCode_ELB_5XX_Count", statistic = "Sum", threshold = 5, comparison = "GreaterThanOrEqualToThreshold", missing = "notBreaching", dimensions = { LoadBalancer = aws_lb.this.arn_suffix } },
    ecs-cpu            = { namespace = "AWS/ECS", metric = "CPUUtilization", statistic = "Average", threshold = 80, comparison = "GreaterThanThreshold", missing = "notBreaching", dimensions = { ClusterName = aws_ecs_cluster.this.name, ServiceName = var.name } },
    rds-cpu            = { namespace = "AWS/RDS", metric = "CPUUtilization", statistic = "Average", threshold = 80, comparison = "GreaterThanThreshold", missing = "missing", dimensions = { DBInstanceIdentifier = aws_db_instance.this.identifier } }
  }, { for id in var.ec2_instance_ids : "ec2-cpu-${id}" => { namespace = "AWS/EC2", metric = "CPUUtilization", statistic = "Average", threshold = 80, comparison = "GreaterThanThreshold", missing = "missing", dimensions = { InstanceId = id } } })
}
resource "aws_cloudwatch_metric_alarm" "this" {
  for_each            = local.alarms
  alarm_name          = "${var.name}-${each.key}"
  alarm_description   = "Lab threshold; tune from observations. ECS CPU replaces EC2 CPU for Fargate."
  namespace           = each.value.namespace
  metric_name         = each.value.metric
  statistic           = each.value.statistic
  threshold           = each.value.threshold
  comparison_operator = each.value.comparison
  dimensions          = each.value.dimensions
  period              = startswith(each.key, "ec2-") ? 300 : 60
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  treat_missing_data  = each.value.missing
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions
}
