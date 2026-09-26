output "automation_role_arn" {
  description = "Role ARN assumed by the central Ansible controller."
  value       = aws_iam_role.automation.arn
}

output "instance_role_arn" {
  description = "IAM role ARN used by monitored EC2 instances."
  value       = aws_iam_role.instance.arn
}

output "instance_profile_name" {
  description = "Instance profile to associate with monitored EC2 instances."
  value       = aws_iam_instance_profile.monitoring.name
}
