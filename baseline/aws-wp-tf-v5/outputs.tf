output "elb_dns" {
    value = aws_lb.default.dns_name
    description = "The DNS name of the load balancer"
}

output "wordpress_url" {
    value = "http://${aws_lb.default.dns_name}/"
    description = "The URL to access the WordPress site"
}

output "rds_endpoint" {
    value = aws_db_instance.db.endpoint
    description = "The connection endpoint for the RDS database"
}

output "rds_port" {
    value = aws_db_instance.db.port
    description = "The port on which the RDS database accepts connections"
}

output "ecs_cluster_name" {
    value = aws_ecs_cluster.default.name
    description = "The name of the ECS cluster"
}

output "ecs_cluster_arn" {
    value = aws_ecs_cluster.default.arn
    description = "The ARN of the ECS cluster"
}

output "vpc_id" {
    value = aws_vpc.default.id
    description = "The ID of the VPC"
}

output "alb_security_group_id" {
    value = aws_security_group.wp-alb-tf.id
    description = "The ID of the ALB security group"
}

output "db_security_group_id" {
    value = aws_security_group.wp-db-sg-tf.id
    description = "The ID of the database security group"
}

output "alb_arn" {
    value = aws_lb.default.arn
    description = "The ARN of the Application Load Balancer"
}