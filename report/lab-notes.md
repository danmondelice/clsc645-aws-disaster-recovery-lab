# Lab notes

## Inspection and assumptions

- The initial workspace was empty and had no Git repository.
- Five course DR scripts were found in the local Downloads directory.
- The instructor WordPress Terraform baseline has not yet been located.
- Downloads/terraform is a different regional API example, not the WordPress baseline.
- Do not substitute a new architecture for the missing instructor baseline.
- Preserve baseline code and course scripts; add enhanced infrastructure separately.
- Do not run Terraform apply or execute the DR scripts during implementation.

## Implementation plan

1. Import the supplied WordPress baseline after checking for embedded credentials;
   inventory its networking, compute, ALB, database, bootstrap, and outputs.
2. Derive a reusable regional WordPress module, retaining baseline behavior;
   instantiate primary us-east-1 and reduced-capacity DR us-west-2 environments.
3. Add versioned S3 replication with scoped IAM, and engine-compatible RDS
   cross-Region automated backups or documented snapshot copies.
4. Add the requested dashboard, alarms, optional Route 53 failover, and outputs.
5. Document database restoration and WordPress content recovery, along with the
   preserved ALB deregistration/re-registration test. DNS failover alone is not
   evidence that application data has been recovered.
6. Format enhanced Terraform, verify baseline integrity, initialize without a
   backend and validate, then document account limitations and verification steps.
   Stop before apply; review a deployment plan separately.

## Validation status

Terraform formatting and validation are pending the actual Terraform baseline
and implementation. No AWS infrastructure has been deployed.
