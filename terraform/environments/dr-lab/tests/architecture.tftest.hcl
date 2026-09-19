# Offline plan tests require Terraform >= 1.7; no AWS account or apply involved.
mock_provider "aws" {
  mock_data "aws_availability_zones" { defaults = { names = ["us-east-1a", "us-east-1b"] } }
  mock_data "aws_caller_identity" { defaults = { account_id = "123456789012" } }
  mock_data "aws_region" { defaults = { name = "us-east-1" } }
}
mock_provider "aws" {
  alias = "dr"
  mock_data "aws_availability_zones" { defaults = { names = ["us-west-2a", "us-west-2b"] } }
  mock_data "aws_caller_identity" { defaults = { account_id = "123456789012" } }
  mock_data "aws_region" { defaults = { name = "us-west-2" } }
}
mock_provider "random" {}
variables { wordpress_image = "wordpress:test-apache" }
run "default_without_domain" {
  command = plan
  assert {
    condition     = length(aws_route53_record.primary) == 0 && length(aws_route53_record.dr) == 0
    error_message = "Domain-free student accounts must not create DNS records."
  }
  assert {
    condition     = length(aws_db_instance_automated_backups_replication.primary) == 1 && length(aws_backup_selection.content) == 1
    error_message = "Both database and file-content backup paths must be enabled."
  }
  assert {
    condition     = aws_s3_bucket_versioning.primary.versioning_configuration[0].status == "Enabled" && aws_s3_bucket_versioning.replica.versioning_configuration[0].status == "Enabled"
    error_message = "Both replication buckets require versioning."
  }
}
run "reject_unverified_dns" {
  command = plan
  variables {
    enable_route53 = true
    hosted_zone_id = "Z123456789"
    domain_name    = "wordpress.example.com"
  }
  expect_failures = [aws_route53_record.primary]
}
run "verified_dns" {
  command = plan
  variables {
    enable_route53   = true
    hosted_zone_id   = "Z123456789"
    domain_name      = "wordpress.example.com"
    dr_data_verified = true
  }
  assert {
    condition     = length(aws_route53_record.primary) == 1 && length(aws_route53_record.dr) == 1
    error_message = "Verified DNS configuration must create both failover records."
  }
}
run "restricted_account_fallback" {
  command = plan
  variables {
    enable_rds_backup_replication = false
    enable_efs_backup             = false
  }
  assert {
    condition     = length(aws_db_instance_automated_backups_replication.primary) == 0 && length(aws_backup_selection.content) == 0
    error_message = "Unsupported backup features must be explicitly disableable."
  }
}
run "destination_restore_configuration" {
  command = plan
  variables {
    dr_snapshot_identifier   = "arn:aws:rds:us-west-2:123456789012:snapshot:lab-recovery"
    dr_db_identifier_suffix  = "-recovery1"
    dr_restored_efs_id       = "fs-1234567890abcdef0"
    dr_content_path          = "/aws-backup-restore_20260918/wordpress"
    dr_desired_count         = 0
    primary_ec2_instance_ids = ["i-1234567890abcdef0"]
  }
  assert {
    condition     = module.dr.efs_id == "fs-1234567890abcdef0"
    error_message = "Recovery must mount the selected destination file system."
  }
}
