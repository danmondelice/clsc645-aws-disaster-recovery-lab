variable "name" { type = string }
variable "vpc_cidr" { type = string }
variable "desired_count" { type = number }
variable "db_password" {
  type      = string
  sensitive = true
}
variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}
variable "db_engine_version" {
  type    = string
  default = "10.11"
}
variable "db_snapshot_identifier" {
  type    = string
  default = null
}
variable "db_identifier_suffix" {
  type    = string
  default = ""
}
variable "restored_efs_id" {
  description = "Optional EFS restored by AWS Backup in this Region; retained outside Terraform."
  type        = string
  default     = null
}
variable "wordpress_image" { type = string }
variable "site_url" {
  type    = string
  default = null
}
variable "alarm_actions" {
  type    = list(string)
  default = []
}
variable "ec2_instance_ids" {
  description = "Optional existing EC2 instances to monitor. Baseline uses Fargate, so empty by default."
  type        = set(string)
  default     = []
}

variable "content_path" {
  description = "EFS access point path; restored backups live in a recovery subdirectory."
  type        = string
  default     = "/wordpress"
  validation {
    condition     = startswith(var.content_path, "/") && length(var.content_path) <= 100
    error_message = "Use an absolute EFS access point path of at most 100 characters."
  }
}
