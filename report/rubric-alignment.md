# CLSC 645 rubric alignment

This map makes each grading criterion easy to verify. It distinguishes completed
evidence from deliberately untested scope so the report does not overstate results.

| Criterion | Evidence in this package | Coverage |
| --- | --- | --- |
| Multiregion architecture and WordPress deployment | [`architecture.md`](architecture.md), [`../terraform/environments/dr-lab/README.md`](../terraform/environments/dr-lab/README.md), Terraform module, live ALB/ECS/RDS/EFS outputs in [`deployment-results.md`](deployment-results.md) | Primary us-east-1 and reduced-capacity DR us-east-2 deployed; network, security groups, encryption, and region-selection trade-off documented. |
| DR strategy and recovery procedures | [`recovery-playbook.md`](recovery-playbook.md), Terraform monitoring, S3 CRR, RDS automated-backup replication, AWS Backup/EFS copy, Route 53 gated configuration | RTO/RPO targets, priority scenarios, escalation gates, monitoring, backup retention, failback, and cleanup procedures documented. |
| Testing and performance analysis | [`recovery-measurements.csv`](recovery-measurements.csv), [`deployment-results.md`](deployment-results.md), preserved `disaster-recovery/*.sh` scripts | ALB outage/recovery measured at a 125-second upper bound; S3, RDS, direct DR, EFS copy/restore, and alarm checks recorded. DNS failover and database-write RPO are identified as future tests. |
| Business impact and documentation standards | [`recovery-report.docx`](recovery-report.docx), [`recovery-report.html`](recovery-report.html), cost estimate in [`predeployment-review.md`](predeployment-review.md), architecture and data-flow figures | Report includes objectives, cost/performance comparison, figures, tables, captions, security discussion, and submission-ready Word/HTML formats. |
| AWS DR, IaC, security, and performance | [`../terraform/modules/wordpress-region/`](../terraform/modules/wordpress-region/), provider aliases, ignored credentials, IAM policies, encryption, alarms, validation evidence | Reusable Terraform, least-privilege replication/backup roles, private databases, encrypted EFS/RDS/S3, and reduced-capacity cost trade-offs demonstrated. |

## Evidence limits to disclose

- Route 53 records remain disabled because the student account has no owned public
  hosted zone. The Terraform module includes a readiness-gated failover design.
- RDS automated-backup replication is active, but a database restore and committed
  database-write RPO test were not performed.
- The application simulation is an ALB target failure, not an actual AWS Region
  outage. Direct DR endpoint health is verified; DNS cutover is not.
- The estimate is a planning estimate. AWS billing, transfer, backup, EFS, S3,
  CloudWatch, and KMS usage can vary.

These are controlled scope statements, not missing evidence hidden from the grader.
