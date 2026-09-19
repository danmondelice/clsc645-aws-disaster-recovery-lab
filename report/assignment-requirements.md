# Assignment requirements and evidence map

Source: assignment instructions supplied by the student. This map records required
deliverables; it does not claim that infrastructure or tests are complete.

| Requirement | Planned implementation or report coverage | Acceptance evidence |
| --- | --- | --- |
| Dual-Region WordPress | Primary us-east-1; reduced-capacity DR us-west-2; reusable Terraform module | Both sites accessible; regional resource inventory; Terraform validation |
| Automated S3 replication | Versioned source and destination; scoped replication role | Test object and version present at destination; measured replication delay |
| Cross-Region RDS snapshots | Document snapshot copy and restore procedures; assess automated backup replication after engine inspection | Completed destination recovery artifact and successful restore test |
| Monitoring and alerts | Requested ALB, EC2, and RDS metrics; dashboard and alarms | Dashboard screenshots with metric explanations; alarm transition evidence |
| Recovery playbook | Restoration rationale, prerequisites, commands, checks, automation, and rollback | Reviewed procedure for application and regional recovery |
| Major outage simulation | Preserve supplied ALB test; add controlled regional failover exercise | Failure scope, timestamps, commands, and observed outage |
| Recovery objectives | Define target RTO and RPO before testing | Measured recovery compared with targets; explanation of misses |
| Data protection and integrity | Timestamped database records and uploaded media; recovery comparison | Missing-record count, recovered timestamps, checksums, and functional checks |
| Cost analysis | Compare backup/restore, reduced-capacity standby, and active/active strategies | Assumptions, dated pricing sources, calculated estimates, actual lab costs |
| Recovery success rate | Record every attempt with a predetermined pass criterion | Successful attempts / all attempts; include failed and aborted trials |
| Lessons learned | Analyze failures, bottlenecks, limitations, and improvements | Findings tied to test IDs and evidence |
| Security | Credential exclusions, scoped access, network access, encryption decisions | Code references and verified configuration; redact sensitive screenshots |
| Incremental IaC | Preserve baseline; implement and validate modular enhancements | Baseline comparison, validation results, reviewed plan |

## Required visuals and presentation

- At least two architecture diagrams: primary Region and DR Region.
- Replication and backup data-flow charts.
- Performance charts using actual recovery measurements.
- Cost comparison tables for different DR strategies.
- Monitoring screenshots with metric, statistic, period, and alarm explanations.
- Numbered figures with captions and references in the report text.
- Consistent headings, fonts, spacing, and citation style in the final export.
- Syntax-highlighted code excerpts with explanations and repository references.

## Open decisions

- Baseline confirmed: ECS Fargate, ALB, MariaDB 10.11 and ephemeral WordPress files.
  Enhanced design retains these services and adds EFS content persistence.
- Assignment or student-selected numerical RTO and RPO targets; no target supplied yet.
- Automated RDS replication and an explicit manual snapshot-copy helper are implemented;
  destination-copy and actual restore evidence still need collection.
- Domain availability and account permissions for optional Route 53 failover.
- Account quotas, permitted instance classes, and deployment budget.
