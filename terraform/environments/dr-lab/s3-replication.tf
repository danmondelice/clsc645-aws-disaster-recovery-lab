resource "aws_s3_bucket" "primary" {
  bucket        = "${var.project_name}-${data.aws_caller_identity.current.account_id}-use1"
  force_destroy = false
}
resource "aws_s3_bucket" "replica" {
  provider      = aws.dr
  bucket        = "${var.project_name}-${data.aws_caller_identity.current.account_id}-usw2"
  force_destroy = false
}
resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_versioning" "replica" {
  provider = aws.dr
  bucket   = aws_s3_bucket.replica.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "primary" {
  bucket = aws_s3_bucket.primary.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "replica" {
  provider = aws.dr
  bucket   = aws_s3_bucket.replica.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}
resource "aws_s3_bucket_public_access_block" "primary" {
  bucket                  = aws_s3_bucket.primary.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_public_access_block" "replica" {
  provider                = aws.dr
  bucket                  = aws_s3_bucket.replica.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_policy" "primary" {
  bucket = aws_s3_bucket.primary.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect = "Deny", Principal = "*", Action = "s3:*", Resource = [aws_s3_bucket.primary.arn, "${aws_s3_bucket.primary.arn}/*"], Condition = { Bool = { "aws:SecureTransport" = "false" } }
  }] })
}
resource "aws_s3_bucket_policy" "replica" {
  provider = aws.dr
  bucket   = aws_s3_bucket.replica.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect = "Deny", Principal = "*", Action = "s3:*", Resource = [aws_s3_bucket.replica.arn, "${aws_s3_bucket.replica.arn}/*"], Condition = { Bool = { "aws:SecureTransport" = "false" } }
  }] })
}
resource "aws_iam_role" "replication" {
  name = "${var.project_name}-s3-replication"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "s3.amazonaws.com" }
  }] })
}
resource "aws_iam_role_policy" "replication" {
  role = aws_iam_role.replication.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["s3:GetReplicationConfiguration", "s3:ListBucket"], Resource = aws_s3_bucket.primary.arn },
    { Effect = "Allow", Action = ["s3:GetObjectVersionForReplication", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging"], Resource = "${aws_s3_bucket.primary.arn}/*" },
    { Effect = "Allow", Action = ["s3:ReplicateObject", "s3:ReplicateTags"], Resource = "${aws_s3_bucket.replica.arn}/*" }
  ] })
}
resource "aws_s3_bucket_replication_configuration" "this" {
  bucket = aws_s3_bucket.primary.id
  role   = aws_iam_role.replication.arn
  rule {
    id       = "all-new-objects"
    priority = 1
    status   = "Enabled"
    filter { prefix = "" }
    # Preserve recovery copies when a source object is deleted.
    delete_marker_replication { status = "Disabled" }
    destination {
      bucket        = aws_s3_bucket.replica.arn
      storage_class = "STANDARD"
    }
  }
  depends_on = [aws_s3_bucket_versioning.primary, aws_s3_bucket_versioning.replica, aws_iam_role_policy.replication]
}
