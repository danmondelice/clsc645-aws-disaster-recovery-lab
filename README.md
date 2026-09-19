# CLSC 645 AWS Disaster Recovery Lab

Extend the UMGC instructor WordPress baseline into a two-Region lab:
primary `us-east-1`, reduced-capacity recovery environment `us-west-2`.

## Current status

Repository preparation only. The instructor's `aws-wp-tf-v5` baseline is not
available in this workspace yet. Infrastructure implementation and validation
are pending inspection of that baseline.

## Layout

- `baseline/aws-wp-tf-v5/`: reserved for the original instructor Terraform.
- `disaster-recovery/`: original course shell scripts, preserved unchanged.
- `terraform/`: planned enhanced regional module and DR lab environment.
- `evidence/README.md`: screenshot and measurement checklist.
- `report/lab-notes.md`: assumptions, implementation plan, and observations.

## Credentials and execution

Never commit AWS credentials, `terraform.tfvars`, state, generated DR configuration,
or saved Terraform plans. `.gitignore` excludes these at any directory depth.
Review staged content before each commit; ignore rules cannot detect secrets
embedded in otherwise tracked source files.

The course scripts perform live AWS mutations. Do not execute them during repository
preparation. Run scripts from `disaster-recovery/` when deployment has been authorized,
because they use relative paths for other scripts and `dr_config.txt`.

Deployment sequence: format, validate, plan, review resources and cost, explicitly
authorize apply, verify both Regions and replication, test application recovery,
test regional recovery, collect RTO/RPO evidence, and clean up resources.
