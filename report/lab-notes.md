# Lab notes

## Source and scope

The instructor clarified that Unit 4 demonstrates DR basics, not a complete
multi-Region recovery course. Preserve that exercise separately from the student's
requested two-Region extension. No deployment or measured recovery is claimed.

The student supplied `aws-wp-tf-v5.zip` from Downloads. Twelve source files were
imported unchanged; credential-bearing tfvars and macOS metadata were excluded.
The five original DR scripts remain unchanged. Hash manifests verify preservation.

## Baseline findings

- WordPress runs on ECS Fargate, not EC2: one 0.5-vCPU/1-GiB task.
- ALB and Fargate share a broadly accessible security group; three public subnets.
- MariaDB 10.11, db.t3.micro, single AZ, 20 GiB gp2; public DB access disabled.
- WordPress uses `wordpress:latest` and ephemeral files. Credentials appear in the
  baseline task environment; a sample database password is hardcoded in variables.
- No S3 CRR, persistent content backup, configured automated RDS backup retention,
  second Region, DNS failover, metric dashboard, or alarms.
- Original backup.sh records ALB configuration, not database or WordPress content.
- Original recover.sh guesses targets from unrelated EC2 resources/ENIs. ECS may
  replace or re-register tasks during simulation, so outages may self-heal.

## Implementation decisions

1. Retain ECS/Fargate, ALB, and MariaDB in a reusable regional module. Primary has
   two tasks; DR has one. Both have a small single-AZ RDS instance. No NAT gateway.
2. Separate ALB/task/database/EFS security groups; private database/EFS subnets.
3. Add per-Region EFS for wp-content; back up primary EFS with AWS Backup and copy
   to the DR vault. This adds storage and backup costs but closes the upload gap.
4. Add versioned SSE-S3 buckets and least-privilege one-way replication. S3 objects
   are independent lab backup/test objects; WordPress media stays on EFS.
5. Enable MariaDB automated backup replication with encrypted destination copies,
   plus a manual snapshot-copy helper for explicit assignment evidence/fallback.
6. Monitor Fargate CPU; optional existing EC2 IDs enable the requested EC2 metric
   without introducing an unrelated EC2 architecture. Explain this in the report.
7. Gate optional DNS failover on explicit DR data verification. Initial DR WordPress
   is independent; it is not a live replica or safe automatic data recovery target.
8. Pin provider versions and require an explicit WordPress image. Credentials use
   the AWS credential chain; database password stays sensitive but exists in local
   Terraform state. Keep state and diagnostic output out of Git.

## Assumptions and unresolved runtime checks

The student account must permit both Regions, IAM/PassRole, ECS service-linked
roles, RDS, KMS, SSM, EFS, AWS Backup and cross-Region operations. Domain ownership
is optional. Actual engine patch support, image availability, account quotas,
backup/restore runtime behavior, budget, and numerical RTO/RPO targets require
predeployment review. HTTP follows the baseline; use synthetic lab data, with
TLS/ACM required before using real credentials or treating this as production.

## Validation

See `evidence/validation.md` for checks run. No Terraform apply, AWS mutation,
outage simulation, or cost-producing deployment has been executed by the agent.
