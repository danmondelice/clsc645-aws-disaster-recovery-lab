resource "aws_sns_topic" "primary" { name = "${var.project_name}-primary-alarms" }
resource "aws_sns_topic" "dr" {
  provider = aws.dr
  name     = "${var.project_name}-dr-alarms"
}
resource "aws_sns_topic_subscription" "primary" {
  count     = var.alarm_email == null ? 0 : 1
  topic_arn = aws_sns_topic.primary.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}
resource "aws_sns_topic_subscription" "dr" {
  provider  = aws.dr
  count     = var.alarm_email == null ? 0 : 1
  topic_arn = aws_sns_topic.dr.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}
locals {
  monitoring_regions = [
    { region = "us-east-1", name = "Primary", infra = module.primary, ec2 = var.primary_ec2_instance_ids },
    { region = var.dr_region, name = "DR", infra = module.dr, ec2 = var.dr_ec2_instance_ids }
  ]
}
resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = "${var.project_name}-operations"
  dashboard_body = jsonencode({ start = "-PT3H", periodOverride = "inherit", widgets = concat(flatten([
    for index, r in local.monitoring_regions : [
      { type = "alarm", x = index * 12, y = 0, width = 12, height = 3, properties = { title = "${r.name} alarms", alarms = r.infra.alarm_arns, region = r.region } },
      { type = "metric", x = index * 12, y = 3, width = 12, height = 6, properties = { title = "${r.name} ALB targets", region = r.region, period = 60, stat = "Minimum", metrics = [
        ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", r.infra.alb_arn_suffix, "TargetGroup", r.infra.target_group_arn_suffix],
        ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", r.infra.alb_arn_suffix, "TargetGroup", r.infra.target_group_arn_suffix, { stat = "Maximum" }]
      ] } },
      { type = "metric", x = index * 12, y = 9, width = 12, height = 6, properties = { title = "${r.name} ALB and target 5XX", region = r.region, period = 60, stat = "Sum", metrics = [
        ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", r.infra.alb_arn_suffix],
        ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", r.infra.alb_arn_suffix]
      ] } },
      { type = "metric", x = index * 12, y = 15, width = 12, height = 6, properties = { title = "${r.name} compute CPU (Fargate)", region = r.region, period = 60, stat = "Average", metrics = concat([
        ["AWS/ECS", "CPUUtilization", "ClusterName", r.infra.ecs_cluster, "ServiceName", r.infra.ecs_service]
      ], [for id in r.ec2 : ["AWS/EC2", "CPUUtilization", "InstanceId", id, { period = 300 }]]) } },
      { type = "metric", x = index * 12, y = 21, width = 12, height = 6, properties = { title = "${r.name} RDS CPU", region = r.region, period = 60, stat = "Average", metrics = [
        ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", r.infra.rds_identifier]
      ] } },
      { type = "metric", x = index * 12, y = 27, width = 12, height = 6, properties = { title = "${r.name} RDS connections", region = r.region, period = 60, stat = "Average", metrics = [
        ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", r.infra.rds_identifier]
      ] } },
      { type = "metric", x = index * 12, y = 33, width = 12, height = 6, properties = { title = "${r.name} RDS free storage (bytes)", region = r.region, period = 60, stat = "Minimum", metrics = [
        ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", r.infra.rds_identifier]
      ] } }
    ]
  ]), [{ type = "text", x = 0, y = 39, width = 24, height = 2, properties = { markdown = "Fargate has no customer EC2 instances. ECS CPU is the baseline compute metric; optional EC2 IDs add real EC2 metrics. DR data freshness requires restore verification, not just green ALB targets." } }]) })
}
