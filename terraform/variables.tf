variable "central_automation_role_arn" {
  description = "ARN of the trusted Ansible automation role in the central account."
  type        = string
}

variable "automation_role_name" {
  description = "Cross-account role assumed by the central Ansible controller."
  type        = string
  default     = "DiskMonitoringAutomationRole"
}

variable "instance_role_name" {
  description = "IAM role used by monitored EC2 instances."
  type        = string
  default     = "DiskMonitoringInstanceRole"
}

variable "instance_profile_name" {
  description = "IAM instance profile used by monitored EC2 instances."
  type        = string
  default     = "DiskMonitoringInstanceProfile"
}


variable "ansible_ssm_bucket_name" {
  description = "S3 bucket used by the Ansible aws_ssm connection plugin for temporary module and file transfer."
  type        = string
}