variable "project_name" {
  type    = string
  default = "clsc645-wp"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,18}[a-z0-9]$", var.project_name))
    error_message = "Use 4-20 lowercase letters, digits, or hyphens, starting with a letter and ending with a letter or digit."
  }
}
variable "dr_region" {
  description = "AWS Region for the reduced-capacity disaster-recovery environment."
  type        = string
  default     = "us-west-2"
  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$", var.dr_region)) && var.dr_region != "us-east-1"
    error_message = "Choose a distinct commercial or GovCloud DR Region; it must differ from us-east-1."
  }
}
variable "dr_availability_zones" {
  description = "Two enabled AZs in dr_region. Explicit values avoid restricted AZ discovery APIs."
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]
  validation {
    condition     = length(var.dr_availability_zones) == 2 && var.dr_availability_zones[0] != var.dr_availability_zones[1]
    error_message = "Provide two distinct availability zones in dr_region."
  }
}
variable "wordpress_image" {
  description = "Explicit apache image tag/digest required; use the same image in both Regions. Pin a digest before deployment."
  type        = string
  validation {
    condition     = length(var.wordpress_image) > 0 && !endswith(var.wordpress_image, ":latest") && !strcontains(var.wordpress_image, "REPLACE_WITH")
    error_message = "Supply an explicit WordPress apache tag or digest; latest is not accepted."
  }
}
variable "db_engine_version" {
  type    = string
  default = "10.11"
}
variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}
variable "primary_desired_count" {
  type    = number
  default = 2
  validation {
    condition     = var.primary_desired_count >= 0 && var.primary_desired_count <= 4 && floor(var.primary_desired_count) == var.primary_desired_count
    error_message = "Choose 0-4 tasks; zero is reserved for controlled outage tests."
  }
}
variable "dr_desired_count" {
  type    = number
  default = 1
  validation {
    condition     = var.dr_desired_count >= 0 && var.dr_desired_count <= 2 && floor(var.dr_desired_count) == var.dr_desired_count
    error_message = "Choose 0-2 DR tasks."
  }
}
variable "dr_snapshot_identifier" {
  description = "Destination snapshot ARN for restoring DR database; changing this replaces the DR DB. Review plan first."
  type        = string
  default     = null
}
variable "dr_db_identifier_suffix" {
  description = "Use a unique suffix such as -recovery1 when restoring a copied snapshot."
  type        = string
  default     = ""
}
variable "dr_restored_efs_id" {
  description = "Optional destination EFS ID restored from AWS Backup."
  type        = string
  default     = null
}
variable "enable_rds_backup_replication" {
  type    = bool
  default = true
}
variable "enable_efs_backup" {
  type    = bool
  default = true
}
variable "enable_route53" {
  type    = bool
  default = false
}
variable "hosted_zone_id" {
  type    = string
  default = null
}
variable "domain_name" {
  type    = string
  default = null
  validation {
    condition     = var.domain_name == null ? true : can(regex("^[A-Za-z0-9][A-Za-z0-9.-]+[A-Za-z0-9]$", var.domain_name))
    error_message = "Supply a DNS hostname without scheme, path, or trailing dot."
  }
}
variable "dr_data_verified" {
  description = "Explicit readiness gate: enable DNS only after restoring and validating DR data."
  type        = bool
  default     = false
}
variable "alarm_email" {
  description = "Optional SNS subscription; recipient must confirm separately in each Region."
  type        = string
  default     = null
}
variable "primary_ec2_instance_ids" {
  type    = set(string)
  default = []
}
variable "dr_ec2_instance_ids" {
  type    = set(string)
  default = []
}

variable "dr_content_path" {
  description = "Set to /aws-backup-restore_<actual timestamp>/wordpress after EFS restore."
  type        = string
  default     = "/wordpress"
}
