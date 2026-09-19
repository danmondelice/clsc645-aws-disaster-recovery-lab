# Deployment verification and recovery playbook

Status: prepared procedures; not executed against AWS. Commands below can create
resources or cause outages. Run only after plan/cost review and authorization for
the specific deployment or simulation. Use the intended student account and record
all UTC timestamps. Keep raw captures in ignored `evidence/raw/`.

## 1. Predeployment review

1. Select an explicit WordPress apache image digest; use it in both Regions.
2. Verify current credentials with `aws sts get-caller-identity`; do not expose keys.
3. Confirm MariaDB engine availability and permitted DB class in both Regions:

```bash
aws rds describe-db-engine-versions --region us-east-1 --engine mariadb --engine-version 10.11
aws rds describe-db-engine-versions --region us-west-2 --engine mariadb --engine-version 10.11
aws rds describe-orderable-db-instance-options --region us-east-1 --engine mariadb --db-instance-class db.t3.micro
aws rds describe-orderable-db-instance-options --region us-west-2 --engine mariadb --db-instance-class db.t3.micro
```

4. Initialize, format and validate `terraform/environments/dr-lab`; generate a saved
   plan. Review resource counts, backup permissions, instance/image availability,
   account quotas, HTTP limitations, price estimates and intended running duration.
5. Set numerical target RTO/RPO and pass/fail criteria before experimentation.
6. Stop for review before apply. Never execute instructor diagnostic scripts as a
   substitute for validation: their logs may contain environment/plan information.

## 2. Initial deployment and service verification

After a separately approved apply, run from the environment directory:

```bash
terraform output
primary_url=$(terraform output -raw primary_wordpress_url)
dr_url=$(terraform output -raw dr_wordpress_url)
curl --fail --max-time 15 "$primary_url/wp-login.php"
curl --fail --max-time 15 "$dr_url/wp-login.php"
```

In each Region verify ECS desired/running counts, task events, healthy ALB targets,
private RDS endpoints, EFS mount connectivity and seven-day backup retention.
Complete WordPress installation in the browser with synthetic lab credentials.
Create numbered, timestamped posts and upload identifiable media on primary.
Record media checksums and expected records before testing. Verify persistence by
replacing a task in a separately approved test. DR initially has independent data.

## 3. S3 cross-Region replication

Run from the environment directory, after CRR configuration is active:

```bash
source_bucket=$(terraform output -raw primary_s3_bucket)
replica_bucket=$(terraform output -raw replica_s3_bucket)
object_key="evidence/replication-$(date -u +%Y%m%dT%H%M%SZ).txt"
printf 'Replication probe %s\n' "$(date -u +%FT%TZ)" > /tmp/dr-replication-probe.txt
aws s3api put-object --region us-east-1 --bucket "$source_bucket" --key "$object_key" --body /tmp/dr-replication-probe.txt
aws s3api head-object --region us-east-1 --bucket "$source_bucket" --key "$object_key"
aws s3api head-object --region us-west-2 --bucket "$replica_bucket" --key "$object_key"
aws s3api get-object --region us-west-2 --bucket "$replica_bucket" --key "$object_key" /tmp/dr-replication-copy.txt
cmp /tmp/dr-replication-probe.txt /tmp/dr-replication-copy.txt
```

A destination 404 before completion is not proof of failure: replication is
asynchronous. Recheck within a recorded test window; record timeout as a failed
trial rather than inventing an RPO. Check source `ReplicationStatus=COMPLETED` and
destination `REPLICA`, VersionId, bytes and timestamps. Objects written before the
rule existed require a separate backfill; delete markers are deliberately not copied.

## 4. Coordinated regional recovery points

The scheduled RDS and EFS backups are independent. For a reproducible lab recovery,
record the latest test post/media and freeze WordPress writes. A reviewed plan that
sets primary_desired_count=0 stops its tasks; this is a planned outage and must be
recorded separately from unexpected failure. Keep writers stopped until both source
backups have completed. Alternatively use a validated application maintenance mode
that actually prevents all writes, including background tasks.

Create an explicit RDS snapshot copy using the helper from the repository root:

```bash
bash scripts/copy-rds-snapshot.sh PRIMARY_DB_ID DESTINATION_KMS_ARN clsc645-checkpoint EXPECTED_ACCOUNT_ID
```

Obtain arguments from Terraform `primary.rds_identifier`, `dr_backup_kms_key_arn`
and the verified account. The helper waits for both snapshots and prints the
available destination ARN; record it. It does not delete snapshots or restore a DB.
If a waiter times out, inspect existing snapshot status and resume waiting instead
of starting duplicate copies. Temporary credentials must remain valid for the job.

For normal automated RDS backup evidence:

```bash
aws rds describe-db-instance-automated-backups --region us-west-2
```

Match source DB ARN, destination ARN, retention and restorable time window. Current
AWS documentation supports automated backup replication for MariaDB; actual account
permission and completion still need verification. [RDS backup support](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.RDS_Fea_Regions_DB-eng.Feature.CrossRegionAutomatedBackups.html).

Create an on-demand EFS backup using AWS Backup in us-east-1, selecting the primary
EFS ARN, primary vault, and Terraform backup role. Wait for COMPLETED, then use the
Copy action to the DR vault and wait for the copy job to complete. Scheduled copies
also run daily, but an on-demand paired copy avoids waiting for the daily schedule.
Record both recovery-point ARNs, timestamps and copy-job IDs. Verify the destination
RDS/EFS copies exist before resuming writes or beginning a regional exercise.

## 5. Preserve and test the instructor ALB exercise

Run from `disaster-recovery/` after confirming that only the intended lab is targeted:

```bash
bash setup.sh
bash backup.sh
# Select the primary ALB by NAME; option 1 is only correct if it is that ALB.
bash simulate_disaster.sh
# Capture the observed outage, HTTP checks and UTC timestamps.
bash recover.sh
# Independently verify healthy targets, site data and login.
```

The supplied `recover.sh` is preserved for comparison but broadly guesses EC2/ENI
candidates. Review it before execution, particularly in an account with other
workloads. For the enhanced deployment, prefer the scoped companion instead:

```bash
bash scripts/recover-ecs-targets.sh us-east-1 CLUSTER SERVICE TARGET_GROUP_ARN EXPECTED_ACCOUNT_ID
```

Run the companion from the repository root with Terraform primary outputs. Record
which recovery method was used; do not attribute helper recovery to the unchanged
course script. ECS may replace tasks or heal registration during the test. Capture
that behavior as a limitation, and record whether an actual outage was observed.
The course `backup.sh` protects ALB configuration only, not posts or media.

## 6. Regional data recovery and traffic switch

1. Record injection/detection times. Keep the primary writers fenced (desired count
   zero) throughout recovery and until a deliberate failback decision. This is a
   controlled loss-of-primary-service exercise, not a real AWS Region outage.
2. Verify the available destination snapshot and its paired EFS recovery point.
   Stop DR writers (dr_desired_count=0 through a reviewed plan) before changing data.
3. In AWS Backup us-west-2, restore the copied EFS recovery point to a **new encrypted
   Regional file system**, using the backup role. Record COMPLETED and the new EFS ID.
4. Identify the actual recovery directory from the restore results and a mount/file
   inspection. AWS Backup places restored content below `aws-backup-restore_<timestamp>`;
   do not assume `/wordpress` contains it. If inspection requires a temporary client,
   permit NFS only from that client's security group and remove that access afterward.
   [EFS restore behavior](https://docs.aws.amazon.com/aws-backup/latest/devguide/restoring-efs.html).
5. Update ignored terraform.tfvars with the destination snapshot ARN, unique DR DB
   suffix, restored EFS ID and verified content directory:

```hcl
dr_desired_count        = 0
dr_snapshot_identifier = "arn:aws:rds:us-west-2:ACCOUNT:snapshot:ACTUAL_SNAPSHOT"
dr_db_identifier_suffix = "-recovery1"
dr_restored_efs_id       = "fs-ACTUAL_RESTORED_ID"
dr_content_path          = "/aws-backup-restore_ACTUAL_TIMESTAMP/wordpress"
dr_data_verified         = false
enable_route53           = false
```

6. Review a new plan. The DR DB is **replaced**, and EFS mount targets/access point
   change. Protect any DR-only data before proceeding. The snapshot must originate
   from this enhanced primary DB (username `wordpress` and this state's generated
   password), not the instructor baseline DB with username `ecs`.
7. After authorized apply and DB availability, verify restored directory permissions
   for UID/GID 33, posts and media; then set dr_desired_count=1 in another reviewed
   plan and start the DR application. Check ECS events and the DR ALB directly.
8. Verify posts, media checksums, login and test writes. Record latest recovered
   pre-failure timestamp, data gaps and service-restoration time. Successful HTTP
   alone does not satisfy integrity or data-loss checks.
9. With a domain: set existing hosted_zone_id/domain_name, dr_data_verified=true,
   enable_route53=true after data validation. Review/apply the DNS plan, then use
   `dig HOSTNAME` and request the hostname. Keep primary targets unavailable while
   demonstrating failover. Retest login/media after the common URL is configured;
   absolute URLs embedded in posts may require a reviewed WordPress search/replace.
10. Without a domain: use the DR ALB URL and label the evidence **manual endpoint
    cutover**. Do not claim automatic DNS failover was tested.
11. Because alias routing can return traffic to a healthy primary, do not restart
    stale primary writers. For failback, freeze DR writes, create a new paired
    checkpoint, restore/reconcile primary, validate it, and only then restore routing.
    Reverse replication/failback automation is not implemented in this lab.

DNS routing evaluates ALB health; it does not restore a database or verify data
freshness. [Route 53 alias health](https://docs.aws.amazon.com/Route53/latest/APIReference/API_AliasTarget.html).

## 7. Monitoring and evidence

Open the named dashboard and explain each metric's dimensions, statistic and period.
Zero-healthy-targets uses Minimum <1, 2 of 3 one-minute periods, missing=breaching.
ALB-generated 5XX uses Sum >=5, 2 of 3 minutes, missing=notBreaching. ECS/RDS CPU
uses Average >80%, 2 of 3 minutes. Optional existing EC2 IDs use five-minute periods.
The dashboard also shows unhealthy targets, target 5XX, RDS connections and storage.
Confirm SNS subscriptions in both Regions; no confirmed subscriber means no email.

Capture actual alarm transitions from the controlled test. Record all attempts in
`report/recovery-measurements.csv`; do not omit failures. Report application-only
and regional recovery separately. Generate performance charts after measurements
exist. The initial report template intentionally contains no fabricated results.

## 8. Cleanup and residual cost review

The instructor cleanup.sh deletes only its own script-created S3 bucket/config; it
does not destroy WordPress or enhanced Terraform. Do not point it at the versioned
Terraform replication buckets. After evidence retention and cleanup authorization:

1. Stop writes/copies; preserve approved academic evidence separately.
2. Inventory and remove manual source/destination DB snapshots and AWS Backup
   recovery points/copy jobs when no longer needed. Vaults must be empty to delete.
3. Empty **all object versions and delete markers** in both Terraform S3 buckets.
   force_destroy=false intentionally prevents an unnoticed loss of backup data.
4. Review `terraform plan -destroy`, then authorize/run destroy separately.
5. Remove external AWS Backup-restored EFS filesystems and any temporary inspection
   clients/mount targets. They are not created or owned by the Terraform EFS resource.
6. Check both Regions for RDS instances/snapshots/retained backups, EFS, vaults,
   buckets, ECS tasks, ALBs, ENIs/public IPs, logs, alarms, SNS and optional DNS records.
7. The KMS key has a seven-day scheduled deletion period. Do not delete its key while
   retaining backup artifacts that require it. Check billing after data settles.

Record actual cost attribution, operating hours and any residual resources. No
fixed price or recovery target is claimed until measured and reviewed.
