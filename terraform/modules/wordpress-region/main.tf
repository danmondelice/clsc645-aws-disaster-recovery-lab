terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.100.0" }
  }
}
data "aws_region" "current" {}
locals {
  azs    = var.availability_zones
  efs_id = var.restored_efs_id != null ? var.restored_efs_id : aws_efs_file_system.wordpress.id
}
# Two AZs retain the ALB topology. Public task ENIs avoid NAT hourly charges;
# only the ALB security group may reach the application. RDS stays private.
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = var.name }
}
resource "aws_internet_gateway" "this" { vpc_id = aws_vpc.this.id }
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = local.azs[count.index]
}
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = local.azs[count.index]
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
}
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
resource "aws_security_group" "alb" {
  name_prefix = "${var.name}-alb-"
  vpc_id      = aws_vpc.this.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.tasks.id]
  }
}
resource "aws_security_group" "tasks" {
  name_prefix = "${var.name}-tasks-"
  vpc_id      = aws_vpc.this.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group_rule" "application" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.tasks.id
  source_security_group_id = aws_security_group.alb.id
}
resource "aws_security_group" "database" {
  name_prefix = "${var.name}-db-"
  vpc_id      = aws_vpc.this.id
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.tasks.id]
  }
}
resource "aws_security_group" "efs" {
  name_prefix = "${var.name}-efs-"
  vpc_id      = aws_vpc.this.id
  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.tasks.id]
  }
}
resource "aws_lb" "this" {
  name                       = var.name
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = aws_subnet.public[*].id
  drop_invalid_header_fields = true
}
resource "aws_lb_target_group" "wordpress" {
  name                 = var.name
  port                 = 80
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = aws_vpc.this.id
  deregistration_delay = 30
  health_check {
    path                = "/wp-login.php"
    matcher             = "200-399"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress.arn
  }
}
resource "aws_db_subnet_group" "this" {
  name       = var.name
  subnet_ids = aws_subnet.private[*].id
}
resource "aws_db_instance" "this" {
  identifier              = "${var.name}-db${var.db_identifier_suffix}"
  engine                  = "mariadb"
  engine_version          = var.db_engine_version
  instance_class          = var.db_instance_class
  allocated_storage       = 20
  storage_type            = "gp3"
  storage_encrypted       = true
  db_name                 = var.db_snapshot_identifier == null ? "wordpressdb" : null
  username                = var.db_snapshot_identifier == null ? "wordpress" : null
  password                = var.db_password
  snapshot_identifier     = var.db_snapshot_identifier
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.database.id]
  publicly_accessible     = false
  multi_az                = false
  backup_retention_period = 7
  backup_window           = "07:00-08:00"
  maintenance_window      = "sun:09:00-sun:10:00"
  copy_tags_to_snapshot   = true
  # Lab cleanup: recovery artifacts must be captured before destroying.
  skip_final_snapshot      = true
  delete_automated_backups = true
}
# wp-content survives task replacement. Core/config remain image/environment driven.
# Keep the initial file system managed even when a restored one is selected;
# changing the recovery mount must not silently delete existing DR files.
resource "aws_efs_file_system" "wordpress" {
  encrypted       = true
  throughput_mode = "bursting"
  tags            = { Name = var.name }
}
resource "aws_efs_access_point" "wordpress" {
  file_system_id = local.efs_id
  posix_user {
    uid = 33
    gid = 33
  }
  root_directory {
    path = var.content_path
    creation_info {
      owner_uid   = 33
      owner_gid   = 33
      permissions = "0755"
    }
  }
}
resource "aws_efs_mount_target" "wordpress" {
  count           = 2
  file_system_id  = local.efs_id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.efs.id]
}
resource "aws_ssm_parameter" "database_password" {
  name  = "/${var.name}/database-password"
  type  = "SecureString"
  value = var.db_password
}
resource "aws_cloudwatch_log_group" "wordpress" {
  name              = "/ecs/${var.name}"
  retention_in_days = 7
}
resource "aws_iam_role" "execution" {
  name = "${var.name}-execution"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "ecs-tasks.amazonaws.com" }
  }] })
}
resource "aws_iam_role_policy" "execution" {
  role = aws_iam_role.execution.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.wordpress.arn}:*" },
    { Effect = "Allow", Action = ["ssm:GetParameters"], Resource = aws_ssm_parameter.database_password.arn }
  ] })
}
resource "aws_iam_role" "task" {
  name               = "${var.name}-task"
  assume_role_policy = aws_iam_role.execution.assume_role_policy
}
resource "aws_iam_role_policy" "efs" {
  role = aws_iam_role.task.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect    = "Allow", Action = ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite"],
    Resource  = "arn:aws:elasticfilesystem:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:file-system/${local.efs_id}",
    Condition = { StringEquals = { "elasticfilesystem:AccessPointArn" = aws_efs_access_point.wordpress.arn } }
  }] })
}
data "aws_caller_identity" "current" {}
resource "aws_ecs_cluster" "this" { name = var.name }
resource "aws_ecs_task_definition" "wordpress" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn
  volume {
    name = "content"
    efs_volume_configuration {
      file_system_id     = local.efs_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.wordpress.id
        iam             = "ENABLED"
      }
    }
  }
  container_definitions = jsonencode([{
    name         = "wordpress", image = var.wordpress_image, essential = true,
    portMappings = [{ containerPort = 80, protocol = "tcp" }],
    mountPoints  = [{ sourceVolume = "content", containerPath = "/var/www/html/wp-content", readOnly = false }],
    environment = [
      { name = "WORDPRESS_DB_HOST", value = aws_db_instance.this.endpoint },
      { name = "WORDPRESS_DB_NAME", value = "wordpressdb" },
      { name = "WORDPRESS_DB_USER", value = "wordpress" },
      # An explicit URL avoids redirects to the source ALB after database restore.
      { name = "WORDPRESS_CONFIG_EXTRA", value = "define('WP_HOME', '${coalesce(var.site_url, "http://${aws_lb.this.dns_name}")}'); define('WP_SITEURL', '${coalesce(var.site_url, "http://${aws_lb.this.dns_name}")}');" }
    ],
    secrets = [{ name = "WORDPRESS_DB_PASSWORD", valueFrom = aws_ssm_parameter.database_password.arn }],
    logConfiguration = { logDriver = "awslogs", options = {
      awslogs-group         = aws_cloudwatch_log_group.wordpress.name,
      awslogs-region        = data.aws_region.current.name,
      awslogs-stream-prefix = "wordpress"
    } }
  }])
}
resource "aws_ecs_service" "wordpress" {
  name                              = var.name
  cluster                           = aws_ecs_cluster.this.id
  task_definition                   = aws_ecs_task_definition.wordpress.arn
  desired_count                     = var.desired_count
  launch_type                       = "FARGATE"
  platform_version                  = "1.4.0"
  health_check_grace_period_seconds = 180
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.wordpress.arn
    container_name   = "wordpress"
    container_port   = 80
  }
  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = true
  }
  depends_on = [aws_lb_listener.http, aws_efs_mount_target.wordpress, aws_iam_role_policy.execution, aws_iam_role_policy.efs, aws_route_table_association.public, aws_security_group_rule.application]
}
