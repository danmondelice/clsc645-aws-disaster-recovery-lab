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

Record UTC timestamps for failure injection, detection, and verified recovery.
For RPO, compare the last committed test record before failure with the latest
record actually available after recovery. Measure ALB target recovery separately
from regional recovery. Record actual observations rather than desired targets.
