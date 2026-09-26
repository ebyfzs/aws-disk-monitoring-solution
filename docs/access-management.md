# Access Management

## Overview

The solution uses a central automation/monitoring account to manage EC2
instances across multiple AWS workload accounts.

Long-lived IAM user access keys and shared SSH keys are not required.

## Cross-Account Access

Each workload account contains a dedicated IAM role named:

`DiskMonitoringAutomationRole`

The role trusts the approved automation identity in the central account.

The central automation identity is permitted to call `sts:AssumeRole` for
the workload-account roles.

This provides the following access pattern:

Central Automation Account
-> AWS STS AssumeRole
-> Workload Account
-> EC2 discovery and Systems Manager operations

The role should follow least privilege and allow only the AWS API operations
required for instance discovery and Systems Manager-based management.

## Instance Access

Managed EC2 instances use AWS Systems Manager (SSM).

Each instance must:

- Have SSM Agent installed and running.
- Be registered as a Systems Manager managed node.
- Use an IAM instance profile with the required SSM permissions.
- Have outbound connectivity to the required AWS service endpoints.

For private instances, connectivity can be provided using appropriate VPC
endpoints rather than requiring public IP addresses or inbound SSH access.

## Security Benefits

This model avoids:

- Public IP addresses solely for administration.
- Inbound SSH (TCP/22) solely for Ansible management.
- Shared SSH private keys.
- Long-lived AWS access keys stored in the repository.

Access is controlled using IAM roles and temporary STS credentials and can
be audited through AWS logging services.

## Account Onboarding

To onboard a new workload account:

1. Deploy the `DiskMonitoringAutomationRole`.
2. Establish the trust relationship with the central automation identity.
3. Ensure target EC2 instances are SSM managed nodes.
4. Apply the required monitoring enrollment tag.
5. Run the Ansible discovery/enrollment workflow.

No static list of VM IP addresses is required.
