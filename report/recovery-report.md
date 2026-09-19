# Establishing Infrastructure Resilience: WordPress Disaster Recovery

**Course:** CLSC 645 Cloud Infrastructure Planning and Design
**Author:** [Student name]
**Date:** [Submission date]
**Status:** Report template; implementation prepared, deployment and measurements pending.

## 1. Purpose and recovery objectives

[Explain why restoring service, recovering application data, and verifying integrity
matter to the selected workload. Identify the consequences of outages and data loss.]

| Objective | Target set before testing | Observed result |
| --- | --- | --- |
| RTO: maximum acceptable service outage | TBD | Not measured |
| RPO: maximum acceptable age of lost data | TBD | Not measured |
| Recovery success rate | TBD | Not measured |
| Deployment cost limit and operating duration | TBD | Not measured |

Distinguish target RTO/RPO from observed restoration time and recovered-data gap.

## 2. Baseline and regional architecture

[Inventory the instructor baseline after receiving its source. Explain what is
preserved, what changes, and why each enhancement supports recovery.]

**Figure 1. Primary Region architecture (us-east-1).** Pending verified design.

**Figure 2. Disaster recovery Region architecture (us-west-2).** Pending verified design.

[Show availability zones, network boundaries, ALB, compute, database, storage,
monitoring, and relevant traffic paths. Label intended designs separately from
deployed configurations. Discuss reduced DR capacity and cost/performance trade-offs.]

## 3. Replication and backup strategy

**Figure 3. S3 replication data flow.** Pending verified design.

**Figure 4. RDS cross-Region copy and restore data flow.** Pending verified design.

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

**Figure 5. CloudWatch dashboard.** Pending deployment screenshot.

**Figure 6. Alarm transition during the outage.** Pending test screenshot.

[For each widget/alarm, state Region, dimensions, units, statistic, period,
evaluation window, missing-data behavior, and notification destination if configured.]

## 6. Recovery playbook and automation

Complete each scenario with exact validated commands and expected outputs before
executing it. Use shell code fences and explain command effects.

| Phase | Required procedure |
| --- | --- |
| Preconditions | Verify account/Region, approved scope, backups, permissions, and primary/DR health |
| Detection | Identify alarm, affected resources, failure scope, and start timestamp |
| Application outage | Run preserved setup and backup scripts; select intended ALB; simulate and recover |
| Regional recovery | Choose destination recovery point; restore data; configure application; verify DR; switch traffic |
| Integrity checks | Verify database records, uploaded media, login, and read/write operations |
| Failback | Define source of truth, reconcile writes, validate primary, and restore routing |
| Cleanup | Inventory Terraform-managed and script-created resources, then remove authorized lab resources |

[Describe manual gates, retry behavior, timeouts, logs, failure handling, and how
automation avoids targeting unintended resources. Distinguish controlled regional
failover from an actual AWS Region outage. Include partial-failure scenarios.]

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

**Figure 7. Recovery time by scenario and attempt.** Generate from measured data only;
show target RTO alongside observations and identify unsuccessful attempts.

[Compare application recovery and regional recovery independently. Explain database
restore time, routing delay, capacity limitations, and integrity-check duration.]

## 8. Cost and performance trade-offs

| Strategy | Resource/capacity assumptions | Estimated cost for stated duration | Measured RTO/RPO or untested status | Pricing source and date |
| --- | --- | --- | --- | --- |
| Backup and restore | TBD | TBD | Untested | TBD |
| Reduced-capacity standby | TBD | TBD | Untested | TBD |
| Active/active comparison | TBD | TBD | Untested | TBD |

[Separate estimates from actual billing. Include compute, databases, load balancers,
storage/versions/snapshots, transfer, monitoring, DNS, and applicable networking costs.
State operating hours, currencies, pricing date, and scope of actual cost attribution.]

## 9. Lessons learned and limitations

[For each finding, cite a test ID, describe expected versus observed behavior,
identify the cause, and propose a concrete improvement. Address account restrictions,
untested failure modes, recovery-point limitations, and security considerations.]

## References

[Add course materials and the official documentation actually used. Cite figures,
pricing, technical claims, and adapted code consistently. Do not invent references.]
