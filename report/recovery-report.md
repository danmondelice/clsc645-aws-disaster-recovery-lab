# Establishing Infrastructure Resilience: WordPress Disaster Recovery

**Course:** CLSC 645 Cloud Infrastructure Planning and Design
**Author:** [Student name]
**Date:** [Submission date]
**Status:** Implementation and validation package complete. Primary is deployed in
us-east-1 and reduced-capacity DR is deployed in us-east-2. See
[live deployment results](deployment-results.md) for evidence and limitations.

## 1. Purpose and recovery objectives

[Explain why restoring service, recovering application data, and verifying integrity
matter to the selected workload. Identify the consequences of outages and data loss.]

| Objective | Target set before testing | Observed result |
| --- | --- | --- |
| RTO: maximum acceptable service outage | 180 seconds for the controlled ALB test | 125-second upper bound |
| RPO: maximum acceptable age of lost data | Object replication test interval | S3 object replicated; database write gap not measured |
| Recovery success rate | 100% for completed controlled application test | 1 of 1 application recovery; regional failover not tested |
| Deployment cost limit and operating duration | Student-account lab budget | Estimated core steady state $141.88/month before variable charges |

Distinguish target RTO/RPO from observed restoration time and recovered-data gap.

## 2. Baseline and regional architecture

[Inventory the instructor baseline after receiving its source. Explain what is
preserved, what changes, and why each enhancement supports recovery.]

**Figure 1. Primary Region architecture (us-east-1).** See the Mermaid diagram in
[architecture.md](architecture.md); the deployed primary has two Fargate tasks,
an ALB, private MariaDB, encrypted EFS, and CloudWatch alarms.

**Figure 2. Disaster recovery Region architecture (us-east-2).** The deployed
alternate Region uses one Fargate task, an ALB, MariaDB, EFS, and monitoring.

[Show availability zones, network boundaries, ALB, compute, database, storage,
monitoring, and relevant traffic paths. Label intended designs separately from
deployed configurations. Discuss reduced DR capacity and cost/performance trade-offs.]

## 3. Replication and backup strategy

**Figure 3. S3 replication data flow.** A timestamped object reached the replica
bucket with `ReplicationStatus=REPLICA`.

**Figure 4. RDS cross-Region copy and restore data flow.** RDS automated-backup
replication reported `replicating`; database restore timing remains future work.

[Describe each data store, backup schedule, retention, destination, encryption,
permissions, restore dependency, and verification method. Establish where WordPress
uploads live and how they are recovered. Record completed destination snapshots
and the selected recovery point. Explain observed replication lag and limitations.]

## 4. Infrastructure as code and security

[Explain module boundaries, provider aliases, inputs/outputs, baseline preservation,
and validation. Include short Terraform excerpts from the implemented repository
using hcl code fences. Explain credential handling, IAM scope, security groups,
encryption, state protection, and account restrictions with code references.]

## 5. Monitoring and alerting

| Metric | Evidence to explain |
| --- | --- |
| ALB HealthyHostCount / UnHealthyHostCount | Target availability and zero-healthy-target alarm |
| ALB 5XX errors | Exact metric name, error source, threshold, and alarm transition |
| EC2 CPUUtilization | Instance dimensions and high-CPU threshold |
| RDS CPUUtilization | Database dimensions and high-CPU threshold |
| RDS DatabaseConnections | Connection behavior before, during, and after recovery |
| RDS FreeStorageSpace | Available storage and observed trend |

**Figure 5. CloudWatch dashboard.** `clsc645-wp-operations` exists and all eight
regional alarms reported `OK` after recovery.

**Figure 6. Alarm transition during the outage.** The no-healthy-target alarm
returned to `OK` after target recovery; all eight regional alarms were `OK` during
the final review.

[For each widget/alarm, state Region, dimensions, units, statistic, period,
evaluation window, missing-data behavior, and notification destination if configured.]

## 6. Recovery playbook and automation

Complete each scenario with exact validated commands and expected outputs before
executing it. The preserved application simulation produced HTTP 503 during target
removal and HTTP 302 after target restoration.

| Phase | Required procedure |
| --- | --- |
| Preconditions | Verify account/Region, approved scope, backups, permissions, and primary/DR health |
| Detection | Identify alarm, affected resources, failure scope, and start timestamp |
| Application outage | Run preserved setup and backup scripts; select intended ALB; simulate and recover |
| Regional recovery | Choose destination recovery point; restore data; configure application; verify DR; switch traffic |
| Integrity checks | Verify database records, uploaded media, login, and read/write operations |
| Failback | Define source of truth, reconcile writes, validate primary, and restore routing |
| Cleanup | Inventory Terraform-managed and script-created resources, then remove authorized lab resources |

The scripts use explicit AWS profiles and target-group discovery. The application
test is a controlled ALB failure, not an AWS Region outage. Regional recovery still
requires restoring matched RDS/EFS checkpoints and switching an owned DNS zone.

## 7. Experiments and measured results

Record every attempt in [recovery-measurements.csv](recovery-measurements.csv).
Define success before each trial: endpoint accessibility plus application and data
integrity checks. Keep failed and aborted attempts in the record.

- Observed restoration time = verified service-restoration timestamp minus
  failure-injection timestamp; also record first observed unavailability.
- Detection delay = detection timestamp minus failure-injection timestamp.
- Recovery execution time = verified restoration minus recovery-start timestamp.
- Observed recovered-data gap = failure timestamp minus the latest pre-failure
  committed test record recovered. State test-write frequency and clock limitations.
- Recovery success rate = successful attempts / all attempted recoveries × 100%;
  disclose counts and classification of aborted attempts.
- Data loss = expected committed test records minus verified recovered records;
  separately verify uploaded media with checksums.

**Figure 7. Recovery time by scenario and attempt.** APP-001 recorded a 125-second
upper bound; DR-001 and EFS-001 validate components separately and are not DNS
failover RTO measurements.

[Compare application recovery and regional recovery independently. Explain database
restore time, routing delay, capacity limitations, and integrity-check duration.]

## 8. Cost and performance trade-offs

| Strategy | Resource/capacity assumptions | Estimated cost for stated duration | Measured RTO/RPO or untested status | Pricing source and date |
| --- | --- | --- | --- | --- |
| Backup and restore | One primary stack; restore on demand | Included in core estimate | EFS restore completed; database restore untested | AWS public pricing checked 2026-09-19 |
| Reduced-capacity standby | One DR Fargate task, ALB, RDS, EFS | About $141.88/month core estimate for both Regions | Direct DR HTTP 302; DNS failover untested | AWS public pricing checked 2026-09-19 |
| Active/active comparison | Two full-capacity Regions | Higher compute, database, and transfer cost | Not implemented | Design comparison |

[Separate estimates from actual billing. Include compute, databases, load balancers,
storage/versions/snapshots, transfer, monitoring, DNS, and applicable networking costs.
State operating hours, currencies, pricing date, and scope of actual cost attribution.]

## 9. Lessons learned and limitations

The first apply exposed an account policy denying creation in us-west-2. Making the
DR Region configurable allowed the same design to deploy in us-east-2. APP-001
showed that the supplied recovery script restores ALB registration; DR-001 and
EFS-001 confirmed standby reachability and encrypted file recovery. A future test
should restore a database snapshot, freeze writes during paired checkpoints, and
exercise Route 53 with an owned hosted zone. State and temporary credentials remain
local and ignored.

## References

[Add the UMGC course runbooks and official AWS documentation used for ECS, ALB, S3
replication, RDS automated backups, AWS Backup, CloudWatch, and Route 53. Cite
figures, pricing, technical claims, and adapted code consistently.]
