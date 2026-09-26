# Security

## Security Objectives

The design minimizes persistent credentials and avoids exposing EC2
management interfaces directly to the network.

## Identity and Access Management

The central Ansible automation identity assumes a dedicated role in each
workload account using AWS STS.

Temporary role credentials are preferred over IAM user access keys.

The workload role is intended only for the operations required for EC2
discovery and Systems Manager-based management.

## EC2 Instance Identity

Monitored instances use an IAM instance profile.

The reference Terraform configuration provides:

- Systems Manager managed-instance permissions
- Permission to publish CloudWatch metrics to the
  `Lucidity/DiskMonitoring` namespace

The CloudWatch metric publishing policy is constrained by namespace.

## Network Access

AWS Systems Manager is used instead of direct SSH for the monitoring
configuration workflow.

Therefore the design does not require:

- Public IP addresses solely for Ansible
- Inbound SSH from the Ansible controller
- Shared SSH private keys

Private EC2 instances require outbound access to the necessary AWS service
endpoints. Where appropriate, AWS PrivateLink/VPC endpoints can provide
private connectivity to supported AWS services.

## Secrets

No AWS credentials, SSH private keys, passwords, or other secrets should be
stored in this repository.

Runtime credentials should come from IAM roles, temporary STS credentials,
or the enterprise's approved credential mechanism.

## Encryption

Production deployments should use encryption in transit to AWS service
endpoints and apply the organization's encryption-at-rest standards to
monitoring and notification services.

## Auditability

Cross-account role assumptions and relevant AWS API activity can be audited
using AWS logging services such as AWS CloudTrail.

Systems Manager also provides a centralized AWS-native management path that
can be incorporated into enterprise auditing controls.

## Least Privilege

Permissions should be reviewed against the final production workflow.

The reference implementation intentionally separates:

1. The central automation/controller identity
2. The cross-account workload automation role
3. The EC2 instance role

This prevents one identity from unnecessarily performing every operation in
the monitoring system.

## Production Hardening

Additional production controls can include:

- Permission boundaries
- AWS Organizations Service Control Policies
- IAM Access Analyzer
- VPC endpoints for private AWS API connectivity
- CloudTrail centralization
- AWS Config rules
- Tag policies
- Session logging according to enterprise requirements
## Ansible SSM Transfer Bucket

The `amazon.aws.aws_ssm` Ansible connection plugin uses a dedicated S3
bucket for temporary module and file transfer while command execution is
performed through Systems Manager.

For production use, the transfer bucket should:

- Block all public access.
- Allow access only to the approved automation identity.
- Use encryption at rest.
- Use lifecycle cleanup for temporary objects.
- Keep versioning disabled or suspended where required to avoid retaining
  deleted temporary Ansible payloads in object history.

The target EC2 instance does not require general S3 credentials for this
transfer mechanism because the connection plugin uses presigned URLs.
