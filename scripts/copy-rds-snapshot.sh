#!/usr/bin/env bash
# Creates an encrypted cross-Region recovery artifact. Never runs Terraform apply.
set -euo pipefail
export AWS_PAGER=""
if [[ $# -ne 4 ]]; then
  echo "Usage: $0 PRIMARY_DB_ID DESTINATION_KMS_ARN SNAPSHOT_PREFIX EXPECTED_ACCOUNT_ID" >&2
  exit 2
fi
db_id=$1; kms_arn=$2; snapshot_prefix=$3; expected_account=$4
[[ $snapshot_prefix =~ ^[a-z][a-z0-9-]{2,40}$ ]] || { echo 'Invalid snapshot prefix' >&2; exit 2; }
actual_account=$(aws sts get-caller-identity --query Account --output text)
[[ $actual_account == "$expected_account" && $kms_arn == arn:aws:kms:us-west-2:"$actual_account":key/* ]] || { echo 'Account or destination key mismatch' >&2; exit 1; }
snapshot_id="${snapshot_prefix}-$(date -u +%Y%m%d%H%M%S)"
source_arn=$(aws rds create-db-snapshot --region us-east-1 --db-instance-identifier "$db_id" --db-snapshot-identifier "$snapshot_id" --query DBSnapshot.DBSnapshotArn --output text)
echo "Waiting for source snapshot $snapshot_id" >&2
aws rds wait db-snapshot-available --region us-east-1 --db-snapshot-identifier "$snapshot_id"
destination_arn=$(aws rds copy-db-snapshot --region us-west-2 --source-region us-east-1 --source-db-snapshot-identifier "$source_arn" --target-db-snapshot-identifier "$snapshot_id" --kms-key-id "$kms_arn" --copy-tags --query DBSnapshot.DBSnapshotArn --output text)
echo "Waiting for destination snapshot $snapshot_id; if the waiter times out, inspect status before retrying." >&2
aws rds wait db-snapshot-available --region us-west-2 --db-snapshot-identifier "$snapshot_id"
printf 'Available destination snapshot: %s\n' "$destination_arn"
printf 'Source and destination snapshots are outside Terraform state; record both for cleanup.\n'
