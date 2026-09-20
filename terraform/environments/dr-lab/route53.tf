# No hosted zone or domain purchase. ALB health drives alias failover only after
# the operator has verified recovered data; a fresh DR database is NOT a replica.
resource "aws_route53_record" "primary" {
  count          = var.enable_route53 ? 1 : 0
  zone_id        = var.hosted_zone_id
  name           = var.domain_name
  type           = "A"
  set_identifier = "primary-us-east-1"
  failover_routing_policy { type = "PRIMARY" }
  alias {
    name                   = module.primary.alb_dns
    zone_id                = module.primary.alb_zone_id
    evaluate_target_health = true
  }
  lifecycle {
    precondition {
      condition     = var.hosted_zone_id != null && var.domain_name != null && var.dr_data_verified
      error_message = "DNS failover requires a hosted zone, hostname, and verified restored DR data."
    }
  }
}
resource "aws_route53_record" "dr" {
  count          = var.enable_route53 ? 1 : 0
  zone_id        = var.hosted_zone_id
  name           = var.domain_name
  type           = "A"
  set_identifier = "secondary-us-west-2"
  failover_routing_policy { type = "SECONDARY" }
  alias {
    name                   = module.dr.alb_dns
    zone_id                = module.dr.alb_zone_id
    evaluate_target_health = true
  }
  depends_on = [aws_route53_record.primary]
}
