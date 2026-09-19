# Live deployment results

Date: 2026-09-18 America/New_York  
AWS account: `382352119953` (`school645`)  
Role: `AWSReservedSSO_StudentAdminAccess`  
Approved Terraform plan: `100 to add, 0 to change, 0 to destroy`  
Result: **partial deployment**

## Verified primary environment

The us-east-1 stack reached a provisioned state before the regional policy
failures. ECS and ALB target health were healthy; an independent local HTTP check
could not resolve the ALB hostname from this workstation, so application
accessibility still requires verification from an AWS-connected client.

| Check | Observed value |
| --- | --- |
| WordPress URL | `http://clsc645-wp-primary-634662928.us-east-1.elb.amazonaws.com` |
| ALB | `clsc645-wp-primary-634662928.us-east-1.elb.amazonaws.com` |
| ALB target health | Two targets reported `healthy` |
| ECS service | `clsc645-wp-primary`, desired 2 and running 2 |
| RDS | `clsc645-wp-primary-db`, status `available` |
| RDS endpoint | `clsc645-wp-primary-db.cs7m2k68qplw.us-east-1.rds.amazonaws.com:3306` |
| S3 source bucket | `clsc645-wp-382352119953-use1` |
| CloudWatch dashboard | `clsc645-wp-operations` was in the configuration output; live existence was not verified and it is absent from the post-failure Terraform state list |
| Alarm state | 5XX, ECS CPU, and RDS CPU `OK`; no-healthy-target alarm was `ALARM` during the check and requires investigation before a production test |

The local `curl` check returned `Could not resolve host` and HTTP `000`; this is
recorded as an unverified external connectivity check rather than a WordPress
success.

The no-healthy-target alarm was observed while the ALB target query showed both
targets healthy. This is a timing or evaluation-window discrepancy that should be
rechecked after the service has been stable for a full alarm evaluation period.

## Disaster recovery blocker

The apply could not create the us-west-2 resources because the selected student
account has explicit policy denies. The errors included:

- `ec2:CreateVpc`
- `ecs:CreateCluster`
- `s3:CreateBucket`
- `kms:TagResource`
- `elasticfilesystem:TagResource`
- `ssm:PutParameter`
- `logs:CreateLogGroup`

An SNS request also returned a transient DNS resolution failure for
` sns.us-west-2.amazonaws.com `. Terraform state contains the primary resources
and a remaining recovery plan of **50 to add, 0 to change, 0 to destroy**. The DR
region, S3 replica, and cross-region recovery path are therefore **not deployed**.

The earlier account `003643568742` was unusable because SSO returned
`ForbiddenException: No access`; switching accounts did not remove the us-west-2
policy restrictions in `school645`.

## What was not claimed as a successful test

No regional failover, S3 replication, RDS cross-region copy, RTO, RPO, or recovery
success-rate measurement is reported. The preserved course scripts were not run
against the new stack after the partial apply. These items require a second account
or an administrator-approved policy change, followed by a fresh plan review.

## Safe next step

Before retrying Terraform, obtain permission to create and tag the listed resources
in us-west-2, refresh SSO, run `terraform plan`, and review the resulting recovery
plan. If access cannot be granted, destroy the partial primary deployment to stop
ongoing charges and submit the implementation/report as a documented account-
restriction limitation rather than presenting an unexecuted DR test as evidence.
