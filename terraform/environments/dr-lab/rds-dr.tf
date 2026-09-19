# MariaDB supports automated backup replication. A destination KMS key protects
# copied encrypted backups; no application credentials are read by Terraform.
resource "aws_kms_key" "dr_backup" {
  provider                = aws.dr
  description             = "${var.project_name} DR backup encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}
resource "aws_kms_alias" "dr_backup" {
  provider      = aws.dr
  name          = "alias/${var.project_name}-dr-backup"
  target_key_id = aws_kms_key.dr_backup.key_id
}
resource "aws_db_instance_automated_backups_replication" "primary" {
  provider               = aws.dr
  count                  = var.enable_rds_backup_replication ? 1 : 0
  source_db_instance_arn = module.primary.rds_arn
  retention_period       = 7
  kms_key_id             = aws_kms_key.dr_backup.arn
}
