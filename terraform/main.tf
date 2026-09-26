terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {}

#
# Cross-account role used by the central Ansible controller.
#

data "aws_iam_policy_document" "automation_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [var.central_automation_role_arn]
    }
  }
}

resource "aws_iam_role" "automation" {
  name               = var.automation_role_name
  assume_role_policy = data.aws_iam_policy_document.automation_trust.json
}

data "aws_iam_policy_document" "automation_permissions" {
  statement {
    sid    = "DiscoverInstances"
    effect = "Allow"

    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "ssm:DescribeInstanceInformation"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "ManageInstancesThroughSSM"
    effect = "Allow"

    actions = [
      "ssm:StartSession",
      "ssm:TerminateSession",
      "ssm:ResumeSession"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AnsibleSSMTransferBucket"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]

    resources = [
      "arn:aws:s3:::${var.ansible_ssm_bucket_name}"
    ]
  }

  statement {
    sid    = "AnsibleSSMTransferObjects"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = [
      "arn:aws:s3:::${var.ansible_ssm_bucket_name}/*"
    ]
  }
}


resource "aws_iam_role_policy" "automation" {
  name   = "DiskMonitoringAutomationPolicy"
  role   = aws_iam_role.automation.id
  policy = data.aws_iam_policy_document.automation_permissions.json
}

#
# EC2 instance role.
#

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = var.instance_role_name
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

#
# Systems Manager permissions for the managed EC2 node.
#
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

#
# Minimal CloudWatch permission required by the agent to publish metrics.
#
data "aws_iam_policy_document" "cloudwatch_metrics" {
  statement {
    sid    = "PublishDiskMetrics"
    effect = "Allow"

    actions = [
      "cloudwatch:PutMetricData"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["Lucidity/DiskMonitoring"]
    }
  }
}

resource "aws_iam_role_policy" "cloudwatch_metrics" {
  name   = "DiskMonitoringCloudWatchMetrics"
  role   = aws_iam_role.instance.id
  policy = data.aws_iam_policy_document.cloudwatch_metrics.json
}

resource "aws_iam_instance_profile" "monitoring" {
  name = var.instance_profile_name
  role = aws_iam_role.instance.name
}
