# WordPress uploads/plugins are EFS data, not S3 data. Back them up explicitly;
# S3 CRR alone cannot protect WordPress content stored on this file system.
resource "aws_backup_vault" "primary" {
  count = var.enable_efs_backup ? 1 : 0
  name  = "${var.project_name}-primary"
}
resource "aws_backup_vault" "dr" {
  provider    = aws.dr
  count       = var.enable_efs_backup ? 1 : 0
  name        = "${var.project_name}-dr"
  kms_key_arn = aws_kms_key.dr_backup.arn
}
resource "aws_iam_role" "backup" {
  count = var.enable_efs_backup ? 1 : 0
  name  = "${var.project_name}-backup"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "backup.amazonaws.com" }
  }] })
}
resource "aws_iam_role_policy_attachment" "backup" {
  for_each   = var.enable_efs_backup ? toset(["AWSBackupServiceRolePolicyForBackup", "AWSBackupServiceRolePolicyForRestores"]) : toset([])
  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/${each.key}"
}
resource "aws_backup_plan" "content" {
  count = var.enable_efs_backup ? 1 : 0
  name  = "${var.project_name}-content"
  rule {
    rule_name         = "daily-content-copy"
    target_vault_name = aws_backup_vault.primary[0].name
    schedule          = "cron(0 5 * * ? *)"
    start_window      = 60
    completion_window = 180
    lifecycle { delete_after = 7 }
    copy_action {
      destination_vault_arn = aws_backup_vault.dr[0].arn
      lifecycle { delete_after = 7 }
    }
  }
}
resource "aws_backup_selection" "content" {
  count        = var.enable_efs_backup ? 1 : 0
  name         = "${var.project_name}-content"
  plan_id      = aws_backup_plan.content[0].id
  iam_role_arn = aws_iam_role.backup[0].arn
  resources    = [module.primary.efs_arn]
  depends_on   = [aws_iam_role_policy_attachment.backup, aws_iam_role_policy.backup_key]
}

resource "aws_iam_role_policy" "backup_key" {
  count = var.enable_efs_backup ? 1 : 0
  role  = aws_iam_role.backup[0].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["kms:Decrypt", "kms:Encrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"], Resource = aws_kms_key.dr_backup.arn },
    { Effect = "Allow", Action = ["kms:CreateGrant"], Resource = aws_kms_key.dr_backup.arn, Condition = { Bool = { "kms:GrantIsForAWSResource" = "true" } } }
  ] })
}
