# CLSC 645 submission package

This package contains the report, evidence, Terraform implementation, reusable
module, baseline, and preserved course scripts for the WordPress disaster-recovery
lab.

## Start here

1. Read [`report/recovery-report.docx`](../report/recovery-report.docx) and export it
   to PDF from Word or Pages.
2. Use [`report/rubric-alignment.md`](../report/rubric-alignment.md) to map each
   rubric criterion to evidence.
3. Review [`report/recovery-measurements.csv`](../report/recovery-measurements.csv)
   and [`evidence/validation.md`](../evidence/validation.md).
4. Reproduce the infrastructure from [`README.md`](../README.md), using temporary
   AWS credentials through the environment or an AWS profile.

## Security

The submission archive intentionally excludes `terraform.tfvars`, `.env` files,
AWS credential files, Terraform state, provider caches, and local lock metadata.
Create local variables from `terraform.tfvars.example`; never paste credentials
into tracked files.

## Live scope

The tested deployment uses us-east-1 as primary and us-east-2 as DR because the
course account denied resource creation in us-west-2. Route 53 is optional and
disabled without an owned hosted zone. The package records these limitations
explicitly and does not present unperformed tests as successful results.
