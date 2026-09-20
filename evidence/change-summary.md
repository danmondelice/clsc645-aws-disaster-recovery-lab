# Change summary

Imported the actual instructor baseline unchanged (excluding tfvars and macOS
metadata), then added a reusable Fargate regional module, two-Region environment,
S3 CRR, RDS backup replication/snapshot helper, persistent EFS and backup copies,
monitoring, optional DNS failover, scoped ALB recovery, tests and report materials.

The five original DR scripts remain unchanged. ECS CPU is used because the
baseline has no EC2 instances; optional EC2 IDs enable real EC2 CPU monitoring.
No deployment or recovery measurement has been performed.

## Added or modified files

- `.gitignore`
- `README.md`
- `baseline/README.md`
- `baseline/aws-wp-tf-v5/alb.tf`
- `baseline/aws-wp-tf-v5/aws.tf`
- `baseline/aws-wp-tf-v5/check-aws-credentials.sh`
- `baseline/aws-wp-tf-v5/ecs.tf`
- `baseline/aws-wp-tf-v5/outputs.tf`
- `baseline/aws-wp-tf-v5/rds.tf`
- `baseline/aws-wp-tf-v5/security-groups.tf`
- `baseline/aws-wp-tf-v5/task-definitions/wordpress.json`
- `baseline/aws-wp-tf-v5/templates.tf`
- `baseline/aws-wp-tf-v5/terraform-debug.sh`
- `baseline/aws-wp-tf-v5/variables.tf`
- `baseline/aws-wp-tf-v5/vpc.tf`
- `baseline/source-sha256.json`
- `disaster-recovery/source-sha256.json`
- `evidence/README.md`
- `evidence/change-summary.md`
- `evidence/validation.md`
- `report/architecture.md`
- `report/assignment-requirements.md`
- `report/lab-notes.md`
- `report/recovery-measurements.csv`
- `report/recovery-playbook.md`
- `report/recovery-report.md`
- `scripts/check-integrity.py`
- `scripts/copy-rds-snapshot.sh`
- `scripts/recover-ecs-targets.sh`
- `terraform/environments/dr-lab/README.md`
- `terraform/environments/dr-lab/efs-backup.tf`
- `terraform/environments/dr-lab/main.tf`
- `terraform/environments/dr-lab/monitoring.tf`
- `terraform/environments/dr-lab/outputs.tf`
- `terraform/environments/dr-lab/providers.tf`
- `terraform/environments/dr-lab/rds-dr.tf`
- `terraform/environments/dr-lab/route53.tf`
- `terraform/environments/dr-lab/s3-replication.tf`
- `terraform/environments/dr-lab/terraform.tfvars.example`
- `terraform/environments/dr-lab/tests/architecture.tftest.hcl`
- `terraform/environments/dr-lab/variables.tf`
- `terraform/modules/wordpress-region/main.tf`
- `terraform/modules/wordpress-region/monitoring.tf`
- `terraform/modules/wordpress-region/outputs.tf`
- `terraform/modules/wordpress-region/variables.tf`
- `tests/test_recovery_helpers.py`
