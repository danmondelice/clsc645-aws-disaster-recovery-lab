# Live deployment results

Date: 2026-09-18 America/New_York  
AWS account: `382352119953` (`school645`)  
Role: `AWSReservedSSO_StudentAdminAccess`  
Approved Terraform plan: `100 to add, 0 to change, 0 to destroy`  
Result: **primary and alternate-region DR deployment completed**

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

## Original disaster recovery blocker and alternate-region resolution

The first apply could not create the us-west-2 resources because the selected student
account has explicit policy denies. The errors included:

- `ec2:CreateVpc`
- `ecs:CreateCluster`
- `s3:CreateBucket`
- `kms:TagResource`
- `elasticfilesystem:TagResource`
- `ssm:PutParameter`
- `logs:CreateLogGroup`

An SNS request also returned a transient DNS resolution failure for
` sns.us-west-2.amazonaws.com `. The us-west-2 DR path was not deployed.

The earlier account `003643568742` was unusable because SSO returned
`ForbiddenException: No access`; switching accounts did not remove the us-west-2
policy restrictions in `school645`.

The configuration was then made Region-configurable and a reviewed `us-east-2`
plan completed with **50 to add, 0 to change, 0 to destroy**. The apply completed
the alternate DR stack, and the final plan reports **No changes**.

| DR check | Observed value |
| --- | --- |
| DR ALB | `clsc645-wp-dr-39503980.us-east-2.elb.amazonaws.com` |
| DR ECS service | `clsc645-wp-dr`, desired 1, running 1 |
| DR target health | One target reported `healthy` |
| DR RDS endpoint | `clsc645-wp-dr-db.c3qy668oon0f.us-east-2.rds.amazonaws.com:3306` |
| Replica bucket | `clsc645-wp-382352119953-usw2` (legacy suffix; bucket is in us-east-2) |
| Dashboard | `clsc645-wp-operations` |

## What was not claimed as a successful test

S3 CRR was verified with a timestamped object; the replica reported
`ReplicationStatus=REPLICA`. RDS automated-backup replication reported
`Status=replicating`. The preserved application-level simulation also completed:
the primary endpoint returned HTTP 503 after target deregistration, both targets
were re-registered, both became healthy, and the endpoint returned HTTP 302.
The measured restoration upper bound was 125 seconds. No regional DNS failover,
restored EFS content, or RPO data-write test has been performed.

The detailed measurement is recorded in
`report/recovery-measurements.csv` under test `APP-001`.

## Safe next step

Keep the saved state private. Complete the RDS restore, EFS restore, and regional
traffic-cutover tests before claiming full recovery success. Both Regions contain
billable resources.
