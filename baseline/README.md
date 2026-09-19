# Instructor baseline

Imported from the student-supplied `aws-wp-tf-v5.zip`. All 12 retained files are
byte-for-byte unchanged. `source-sha256.json` records their original hashes.
`terraform.tfvars` and `__MACOSX` metadata were deliberately excluded.

The source uses Fargate (512 CPU units, 1 GiB, one task), a public ALB across three
subnets, a private-access MariaDB 10.11 instance (`db.t3.micro`, 20 GiB gp2), and
CloudWatch logs. No EC2 instances, S3 buckets, backups policy, persistent content
volume, alarms, dashboard, or second Region are defined.

`variables.tf` contains the instructor's example database password; it is not an
AWS credential and must never be used for a deployment. The enhanced environment
uses a generated password and runtime SSM injection. Do not deploy this reference
copy with its defaults. Original diagnostic scripts can include sensitive data in
logs; do not execute them or publish their output without review.

The baseline uses the obsolete `template_file` provider and AWS provider 5.40.
The enhanced environment replaces template rendering with `jsonencode` and uses
AWS provider 5.100. Baseline formatting is intentionally preserved; format and
validate the enhanced `terraform/` tree separately.
