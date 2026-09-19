# Evidence checklist

Collect after reviewing the Terraform plan and explicitly authorizing deployment.
Review screenshots and logs for credentials before adding them to Git.

- [ ] Terraform plan screenshot
- [ ] Terraform apply success
- [ ] Primary WordPress screenshot
- [ ] DR WordPress screenshot
- [ ] Primary S3 bucket
- [ ] DR S3 bucket
- [ ] Replicated test object
- [ ] Primary RDS
- [ ] Replicated/copied RDS backup
- [ ] CloudWatch dashboard
- [ ] CloudWatch alarm
- [ ] Site before outage
- [ ] simulate_disaster.sh output
- [ ] Failed site screenshot
- [ ] recover.sh output
- [ ] Restored site screenshot
- [ ] Regional failover screenshot
- [ ] RTO measurement
- [ ] RPO measurement
- [ ] Final cost data
- [ ] Primary Region architecture diagram with caption
- [ ] DR Region architecture diagram with caption
- [ ] S3 replication data-flow chart
- [ ] RDS backup/copy/restore data-flow chart
- [ ] Recovery performance chart from measured trials
- [ ] Cost comparison table with dated sources and assumptions
- [ ] Post-recovery database and media integrity checks
- [ ] Recovery success rate, including unsuccessful attempts
- [ ] Lessons learned linked to test evidence

Use [the requirements map](../report/assignment-requirements.md) to check coverage
and [the report template](../report/recovery-report.md) to assemble the submission.
Record raw trial measurements in
[recovery-measurements.csv](../report/recovery-measurements.csv).

Record UTC timestamps for failure injection, detection, and verified recovery.
For RPO, compare the last committed test record before failure with the latest
record actually available after recovery. Measure ALB target recovery separately
from regional recovery. Record actual observations rather than desired targets.
