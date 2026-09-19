# Two-Region WordPress lab

This is a new deployment derived from the instructor's Fargate/ALB/MariaDB design.
It does not migrate an existing baseline state. Do not deploy both copies without
reviewing duplicate resources and cost. Primary: us-east-1; DR: us-west-2.

## Validate, then stop for plan review

From this directory, using a local AWS profile or temporary environment credentials:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit wordpress_image to a reviewed apache tag/digest; do not use the placeholder.
terraform init
terraform fmt -recursive ../../
terraform validate
terraform plan -out=review.tfplan
terraform show -no-color review.tfplan
```

No apply is authorized by these instructions. Review the saved plan, account,
quotas, and cost before a separately authorized `terraform apply review.tfplan`.
Plans, tfvars, provider locks, and state are ignored as requested by the student.
Local state contains the generated database password; keep a protected backup of
state and do not print/export it into public evidence. Do not delete it before cleanup.

Offline tests: `terraform test` (Terraform >= 1.7; mocks, plan only). Infrastructure
syntax supports >= 1.5.7. The tests cannot establish live permissions or service health.

## What the plan creates

| Component | Primary | DR |
| --- | --- | --- |
| ALB | One across two public subnets | One across two public subnets |
| Fargate | Two 0.5-vCPU / 1-GiB tasks | One 0.5-vCPU / 1-GiB task |
| MariaDB | Single-AZ db.t3.micro, 20 GiB gp3 | Same small class; initially independent DB |
| Network | Separate public and private subnets; no NAT | Separate VPC; no NAT |
| WordPress files | Encrypted EFS wp-content | Encrypted EFS; replace mount with restored content |
| S3 | Versioned source; SSE-S3 | Versioned destination; SSE-S3 |
| Database backups | Seven-day automated retention | Encrypted cross-Region backup copies |
| File backups | Daily AWS Backup selection | Seven-day copied recovery points |
| Monitoring | ALB/ECS/RDS alarms, SNS | ALB/ECS/RDS alarms, SNS |

A combined dashboard shows both Regions. Optional EC2 IDs add CPU metrics/alarms
for existing EC2 instances; no EC2 instance is invented for a Fargate workload.
Optional Route 53 records require an existing public hosted zone and verification
of recovered DR data. Subscribe/confirm both SNS emails to receive notifications.

## Limits and required permissions

- Both Regions and enough VPC, ALB, Fargate vCPU, RDS, EFS and public-IP quota.
- IAM CreateRole/PutRolePolicy/AttachRolePolicy and narrowly scoped PassRole to ECS
  and AWS Backup; ECS/RDS service-linked roles may need creation permission.
- S3 versioning/replication and object access, RDS automated backup replication,
  snapshot create/copy/restore, KMS create/grants/encrypt/decrypt, SSM SecureString,
  EFS access points/mount targets, AWS Backup plans/vaults/jobs and cross-Region copy.
- AWS Backup uses AWS-managed backup/restore role policies. S3 replication uses
  a custom policy limited to the two buckets. Account boundaries/SCPs can deny either.
- Verify MariaDB 10.11 patch and db.t3.micro availability in both Regions before
  applying. An explicit compatible image must be available from its registry.
- If automatic RDS replication is denied, set enable_rds_backup_replication=false
  and use the documented snapshot-copy helper. This fallback is manual, not continuous.
- If AWS Backup is denied, disabling enable_efs_backup removes file recovery
  protection; the full assignment remains incomplete until an approved alternative
  file backup/restore procedure is tested. Do not assert regional recoverability.
- RDS encryption cross-Region signing and KMS grants must work with the account's
  temporary credentials. If replication creation is rejected, retain the error and
  use the explicit snapshot fallback rather than weakening encryption.
- Two always-on ALBs and RDS instances, three Fargate tasks, public IPv4 addresses,
  EFS, backup storage/copies, transfer, KMS, metrics/alarms and DNS may incur costs.
  There is no cost estimate or free-tier guarantee. Review duration and AWS pricing.
- HTTP follows the course baseline. Use only synthetic lab accounts/data. Add
  HTTPS listeners and certificates before using this for production or real secrets.

## Recovery semantics

The initial DR site is a separate WordPress installation. Green ALB targets do not
mean its data matches primary. EFS and RDS snapshots have separate schedules and
are not transactionally coordinated. The playbook freezes writes for paired lab
recovery points, restores both, validates records/media, and only then enables
DNS. This is an operator-led recovery design, not continuous active/active replication.

The EFS access point must reference the actual restored directory, often
`/aws-backup-restore_<timestamp>/wordpress`, rather than a newly created empty
`/wordpress`. Verify the directory exists before starting WordPress.

Follow [the deployment and recovery playbook](../../../report/recovery-playbook.md)
and collect [the evidence checklist](../../../evidence/README.md).
