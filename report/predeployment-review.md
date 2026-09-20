# Predeployment review

Status: the approved plan was applied in account 382352119953 (`school645`) on
2026-09-18 America/New_York. The primary us-east-1 stack and alternate DR
us-east-2 stack are deployed; the account explicitly denied the original
us-west-2 attempt. See `deployment-results.md` for the live result. Public pricing was checked
2026-09-19 UTC (2026-09-18 America/New_York). This is a configuration estimate,
not an AWS bill or spending limit.

## Prepared local inputs

The ignored terraform.tfvars contains two primary Fargate tasks, one DR task,
DNS disabled, and an immutable official WordPress apache image digest:

```text
wordpress@sha256:de65df4bf3ce6d5ce1899fb4ab5edc6fa36c6f54761bc4ac4a0ee5e0435e8a04
```

Resolved from `7.1.1-php8.3-apache`; verified linux/amd64 is available in the
registry manifest. No image vulnerability scan or application startup test has
been performed. No AWS credentials are stored in tfvars.

## Core infrastructure estimate

USD public on-demand pricing; 730 hours/month; no discounts, credits or taxes.
Both Regions currently have the same rates for the components below. Public IP
count assumes two ALB addresses per Region; scaling and deployments can add more.

| Component | USD/month equivalent |
| --- | ---: |
| Fargate: 3 tasks, each 0.5 vCPU + 1 GiB | $54.06 |
| Two ALBs, fixed hourly charge | $32.85 |
| Two MariaDB db.t3.micro instances | $24.82 |
| RDS gp3 storage: 20 GiB per Region | $4.60 |
| Public IPv4: assumed 4 ALB + 3 task addresses | $25.55 |
| **Core subtotal** | **$141.88** |

Core subtotal: **$0.194/hour**, **$4.66/day**,
or **$0.78 for four hours** at steady capacity.

This is **not an all-in estimate or cost cap**. Add ALB LCU usage ($0.008 per
LCU-hour in each Region), EFS storage, EFS/RDS backup storage and restore/copy jobs,
S3 storage/versions/requests, cross-Region/internet data transfer, CloudWatch
alarms/dashboard/logs, KMS key/requests, SNS, and RDS surplus CPU credits if used.
Volume/retention/test duration must be set to estimate those costs. Running task
counts can temporarily increase during ECS rolling deployments. No NAT is configured.

Sources: [Fargate pricing](https://aws.amazon.com/fargate/pricing/),
[ALB pricing](https://aws.amazon.com/elasticloadbalancing/pricing/),
[IPv4 pricing](https://aws.amazon.com/vpc/pricing/),
[RDS us-east-1 price list](https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonRDS/current/us-east-1/index.json),
[RDS us-west-2 price list](https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonRDS/current/us-west-2/index.json).
Regional ECS and ELB public offer files were also used; all arithmetic was computed
with Decimal, rather than estimated mentally. ECS/ELB offer publication date:
2026-09-11; RDS: 2026-09-17.

## Next checks after authentication

The first selected account, 003643568742 (`StudentAdminAccess-003643568742`), returned `ForbiddenException: No access`. The account administrator/course IAM assignment must grant that user the StudentAdminAccess role, or the user must select an account where that role is assigned. The lab was switched to account 382352119953 (`school645`), where SSO access succeeded as `AWSReservedSSO_StudentAdminAccess`.

The switched account has a 30-vCPU Fargate quota and no existing VPCs in us-east-1. MariaDB 10.11.13 is available in us-east-1. An explicit identity policy deny prevents `rds:DescribeDBEngineVersions` in us-west-2, and the same restriction blocked `ec2:DescribeAvailabilityZones` there. The environment now uses explicit `us-east-1a/us-east-1b` and `us-west-2a/us-west-2b` inputs so the plan does not require AZ discovery; verify those AZs are enabled before apply.

The live read-only plan succeeded after that adjustment: **100 to add, 0 to change, 0 to destroy**. It was saved locally at `/tmp/clsc645-dr.tfplan` and is not in Git. The plan contained no access-key pattern. The alternate-region plan for us-east-2 then applied **50 to add, 0 to change, 0 to destroy**, and the final plan reports no changes.

## Plan review findings

- Two primary tasks and one DR task are configured; both Regions receive an ALB,
  single-AZ `db.t3.micro` MariaDB instance, EFS file system, and CloudWatch logs.
- RDS is private (`publicly_accessible=false`) with seven-day automated retention.
  The lab cleanup setting intentionally uses `skip_final_snapshot=true` and
  `delete_automated_backups=true`; capture required recovery evidence before cleanup.
- Fargate tasks receive public IPs because no NAT gateway is provisioned. The task
  security group accepts HTTP only from its ALB; database and EFS ingress remains
  security-group scoped. Public IPv4 and transfer charges apply.
- Both S3 buckets have versioning, encryption, public-access blocks, and
  `force_destroy=false`; cleanup must remove object versions explicitly.
- Backup vaults also use `force_destroy=false`; recovery points must be removed
  before Terraform destroy can delete the vaults.
- The plan creates two IAM roles for ECS per Region, an S3 replication role, a
  backup role with AWS managed backup policies, a destination KMS key, two SNS
  topics, one dashboard, and eight metric alarms.
- Route 53 is absent because `enable_route53=false`; no domain is required for
  this deployment. The plan has no destroy or replacement actions.

The core steady-state estimate is approximately **$4.66/day** before EFS, backup,
S3, LCU, logs, KMS, transfer, and other usage charges. This is a planning estimate,
not an AWS bill or spending limit.
