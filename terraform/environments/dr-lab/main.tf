resource "random_password" "database" {
  length  = 32
  special = false
}
locals {
  site_url = var.enable_route53 && var.domain_name != null ? "http://${var.domain_name}" : null
}
module "primary" {
  source             = "../../modules/wordpress-region"
  name               = "${var.project_name}-primary"
  vpc_cidr           = "10.10.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
  desired_count      = var.primary_desired_count
  db_password        = random_password.database.result
  db_instance_class  = var.db_instance_class
  db_engine_version  = var.db_engine_version
  wordpress_image    = var.wordpress_image
  site_url           = local.site_url
  alarm_actions      = [aws_sns_topic.primary.arn]
  ec2_instance_ids   = var.primary_ec2_instance_ids
}
module "dr" {
  source                 = "../../modules/wordpress-region"
  providers              = { aws = aws.dr }
  name                   = "${var.project_name}-dr"
  vpc_cidr               = "10.20.0.0/16"
  availability_zones     = ["us-west-2a", "us-west-2b"]
  desired_count          = var.dr_desired_count
  db_password            = random_password.database.result
  db_instance_class      = var.db_instance_class
  db_engine_version      = var.db_engine_version
  db_snapshot_identifier = var.dr_snapshot_identifier
  db_identifier_suffix   = var.dr_db_identifier_suffix
  content_path           = var.dr_content_path
  restored_efs_id        = var.dr_restored_efs_id
  wordpress_image        = var.wordpress_image
  site_url               = local.site_url
  alarm_actions          = [aws_sns_topic.dr.arn]
  ec2_instance_ids       = var.dr_ec2_instance_ids
}
