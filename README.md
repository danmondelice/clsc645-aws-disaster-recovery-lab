# CLSC 645 AWS Disaster Recovery Lab

A two-Region extension of the UMGC WordPress Terraform baseline: primary
`us-east-1` and reduced-capacity recovery in `us-west-2`. The baseline runs
**ECS Fargate, ALB and MariaDB**, not EC2-hosted WordPress.

## Status

Implementation prepared; Terraform validation and offline mock plan tests pass.
No live AWS plan, apply, outage test, or measured RTO/RPO has been performed.
The instructor's supplied exercise teaches ALB recovery basics; this repository
adds the separately requested regional architecture and recovery procedures.

## Repository layout

- [baseline/aws-wp-tf-v5](baseline/aws-wp-tf-v5): 12 original instructor files,
  unchanged; original tfvars excluded. [Import notes](baseline/README.md).
- [disaster-recovery](disaster-recovery): five unchanged course scripts.
- [terraform/modules/wordpress-region](terraform/modules/wordpress-region):
  reusable Fargate, ALB, MariaDB, EFS and regional alarm configuration.
- [terraform/environments/dr-lab](terraform/environments/dr-lab): both Regions,
  S3 CRR, RDS backup replication, EFS backup copies, dashboard and optional DNS.
- [scripts](scripts): snapshot-copy helper, scoped ECS target recovery, integrity check.
- [report/recovery-playbook.md](report/recovery-playbook.md): review, deployment
  verification, recovery and cleanup procedures.
- [report/architecture.md](report/architecture.md): regional and data-flow diagrams.
- [report/assignment-requirements.md](report/assignment-requirements.md): rubric map.
- [report/recovery-report.md](report/recovery-report.md): academic report template.
- [report/recovery-measurements.csv](report/recovery-measurements.csv): trial records.
- [evidence/README.md](evidence/README.md): required evidence checklist.
- [evidence/validation.md](evidence/validation.md): checks run and runtime limits.

## Start here

Read the [environment guide](terraform/environments/dr-lab/README.md), select a
reviewed WordPress apache image digest, initialize and validate that environment,
then generate a plan for review. **Stop before apply.** Do not initialize/deploy
the preserved baseline as part of the enhanced environment.

Keep AWS credentials in a local profile or temporary environment variables. Never
commit credentials, terraform.tfvars, state, saved plans or dr_config.txt. The
requested ignore rules cover these at any directory depth. The instructor's example
DB password remains only in the unchanged reference baseline; enhanced deployments
use a generated password injected through SSM. Local state still contains secrets.

The initial DR site has independent data. Restore RDS and EFS, verify records/media,
and then enable optional DNS failover. No-domain accounts can test manual endpoint
cutover. Fargate CPU is monitored; optional EC2 IDs add metrics for existing instances.

Never run outage or cleanup scripts as validation. The course recovery script can
select unrelated EC2/ENI candidates; use the service-scoped helper for the enhanced
lab and record that distinction. Review costs and account permissions before deployment.
