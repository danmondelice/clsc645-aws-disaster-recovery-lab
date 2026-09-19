# Implementation validation

Validation performed locally and against a live account on 2026-09-18 with
Terraform 1.16.0, AWS provider 5.100.0 and random provider 3.7.2. The live plan
was reviewed and the approved apply completed the primary us-east-1 stack and
alternate DR stack in us-east-2 after us-west-2 policy denies were encountered.
The final plan reports no changes. See [deployment results](../report/deployment-results.md).

| Check | Result |
| --- | --- |
| `terraform fmt -recursive terraform` and subsequent `-check` | Pass |
| `terraform -chdir=terraform/environments/dr-lab init -backend=false -input=false` | Pass |
| `terraform -chdir=terraform/environments/dr-lab validate` | Pass |
| Mock Terraform plan tests | 5 passed |
| Scoped ECS recovery helper tests using fake AWS CLI | 2 passed |
| Bash syntax checks on original and added scripts | Pass |
| Baseline and course script hash verification | Pass; originals unchanged |
| Requested credential/state ignore paths | Pass |
| AWS access-key pattern scan of source and reviewed plan | No matches |

Mock plan cases: domain-free defaults; rejection of unverified DNS; verified DNS;
restricted-account backup toggles; destination RDS/EFS restoration with optional
EC2 monitoring. Helper tests prove wrong-account refusal and service-specific
IP selection. These are offline checks, not integration or restore tests.

Original baseline files were not reformatted or initialized. The obsolete baseline
`template_file` dependency is intentionally preserved for comparison; the enhanced
code uses `jsonencode`. Original trailing whitespace is retained as part of exact
preservation. The enhanced Terraform tree is formatted and validated.

Initialization required registry access, and provider execution required running
outside the local sandbox. No AWS credentials were printed or imported from the ZIP.
The archive's terraform.tfvars was excluded entirely. The unchanged baseline's
example database password is reference material only, never used by enhanced code.

## Remaining runtime checks

- Verify initial WordPress setup and EFS from an AWS-connected client.
- Confirm SNS subscriptions, dashboard metrics and actual alarm transitions.
- S3 CRR object replication and RDS automated-backup replication were verified;
  EFS recovery-point creation still requires a scheduled or on-demand backup.
- Restore a matched RDS/EFS checkpoint and verify application/data integrity.
- The preserved ALB exercise completed: HTTP 503 during target deregistration and
  HTTP 302 after both targets recovered.
- Test regional traffic cutover and optional DNS, then measure RTO/RPO and costs.
- Review/delete residual resources, including manual snapshots and restored EFS.

See the [playbook](../report/recovery-playbook.md) for steps and limitations.
