# Scalable AWS Disk Monitoring Solution

A reference architecture and minimal implementation for monitoring guest
filesystem utilization across a multi-account AWS environment using Ansible,
AWS Systems Manager, Amazon CloudWatch, IAM, and Terraform.

The solution is designed to detect low disk capacity before filesystem
exhaustion causes application degradation or downtime.

## Architecture

```text
                              AWS ORGANIZATION
                                     │
                 ┌───────────────────┴────────────────────┐
                 │                                        │
                 │       CENTRAL AUTOMATION ACCOUNT       │
                 │                                        │
                 │   ┌───────────────────────────────┐    │
                 │   │      Ansible Controller       │    │
                 │   │                               │    │
                 │   │ • Ansible                     │    │
                 │   │ • amazon.aws collection       │    │
                 │   │ • Dynamic inventory           │    │
                 │   │ • Playbooks / Roles           │    │
                 │   └───────────────┬───────────────┘    │
                 │                   │                    │
                 └───────────────────┼────────────────────┘
                                     │
                                STS AssumeRole
                                     │
                     ┌───────────────┴───────────────┐
                     │                               │
                     V                               V
             PRODUCTION ACCOUNT              DEVELOPMENT ACCOUNT
                     │                               │
          DiskMonitoringAutomationRole    DiskMonitoringAutomationRole
                     │                               │
                     V                               V
                EC2 Instances                   EC2 Instances
                     │                               │
                 SSM Agent                         SSM Agent
                     │                               │
              CloudWatch Agent                 CloudWatch Agent
                     │                               │
                     V                               V
             Production CloudWatch             Dev CloudWatch
                     │                               │
                     │        OAM Links              │
                     └──────────────┬────────────────┘
                                    │
                                    V
                         CENTRAL MONITORING
                              OAM Sink
                                    │
                                    V
                         CloudWatch Dashboard
                                    │
                              CloudWatch Alarm
                                    │
                                    V
                                   SNS
                                    │
                                    V
                            Operations Team
```

## Design Goals

The solution addresses four primary requirements:

- Secure management of EC2 instances across multiple AWS accounts
- Dynamic discovery and enrollment without static IP inventories
- Continuous guest filesystem monitoring and centralized visibility
- A scalable operating model as accounts, regions, and instances increase

## Architecture Summary

The architecture separates two responsibilities.

### Management Plane

A central Ansible controller manages configuration.

For each workload account, the automation identity assumes a dedicated
`DiskMonitoringAutomationRole` using AWS STS.

EC2 instances are dynamically discovered through AWS APIs using the
`DiskMonitoring=enabled` tag.

AWS Systems Manager is used for instance connectivity instead of requiring
public IP addresses, inbound SSH, or shared SSH keys.

### Monitoring Plane

Ansible installs and configures the Amazon CloudWatch Agent.

After enrollment, the agent continuously publishes guest filesystem metrics
to the custom namespace:

`Lucidity/DiskMonitoring`

The primary capacity metric is:

`disk_used_percent`

`disk_free` is also collected.

The reference configuration collects metrics every 60 seconds.

Because telemetry is published by the agent, continuous monitoring does not
depend on the Ansible controller remaining available.

## Why CloudWatch Agent?

Standard EC2/EBS infrastructure metrics do not provide guest filesystem
utilization such as the percentage used for `/`, `/var`, or `/data`.

The CloudWatch Agent provides the guest operating-system visibility required
to identify filesystem-capacity risk.

Filesystem dimensions are preserved so that a nearly full mount point is
not hidden by an instance-wide average.

## Discovery and Enrollment

The sample dynamic inventory selects running EC2 instances tagged:

`DiskMonitoring=enabled`

It can also group discovered instances using metadata such as Environment
and Application tags.

A typical enrollment flow is:

1. EC2 instance receives the required IAM instance profile.
2. The instance becomes an SSM managed node.
3. `DiskMonitoring=enabled` is applied.
4. Dynamic inventory discovers the instance.
5. Ansible deploys the CloudWatch Agent configuration.
6. The agent begins publishing filesystem metrics.
7. The verification playbook confirms agent status and filesystem usage.

See [Discovery and Enrollment](./docs/discovery-and-enrollment.md).

## Multi-Account Access

The design uses a central automation identity and a dedicated
`DiskMonitoringAutomationRole` in each workload account.

The controller uses AWS STS `AssumeRole` to obtain temporary credentials.

The EC2 instances use a separate instance profile for:

- Systems Manager managed-node functionality
- CloudWatch metric publishing

This separates controller permissions from instance permissions.

See [Access Management](./docs/access-management.md).

## Alerting

Example capacity thresholds are:

- Warning: disk utilization >= 80%
- Critical: disk utilization >= 90%

These are reference values rather than universal production thresholds.
Actual thresholds should consider workload growth rate, filesystem size,
business criticality, and operational response time.

Missing telemetry should also be considered an operational signal because
it may indicate an agent, instance, network, IAM, or enrollment problem.

CloudWatch alarms can route notifications through Amazon SNS or an
enterprise incident-management integration.

See [CloudWatch Monitoring](./cloudwatch/README.md).

## Scalability

Ansible is used for configuration and enrollment rather than continuous
polling.

Continuous telemetry collection is distributed to CloudWatch Agents running
on the EC2 fleet.

Dynamic inventory removes static host lists, while the same cross-account
role and tagging pattern can be repeated as new AWS accounts are onboarded.

See [Scalability](./docs/scalability.md).

## Security

The design avoids requiring:

- Public IP addresses solely for administration
- Inbound SSH solely for Ansible
- Shared SSH private keys
- Long-lived AWS credentials in the repository

IAM roles, temporary STS credentials, SSM, least-privilege permissions, and
AWS-native audit capabilities form the primary security controls.

See [Security](./docs/security.md).

## Repository Structure

```text
.
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/
│   │   ├── accounts.example.yml
│   │   └── aws_ec2.yml
│   ├── playbooks/
│   │   ├── deploy-cloudwatch-agent.yml
│   │   └── verify-disk-monitoring.yml
│   └── roles/
│       └── cloudwatch_agent/
├── architecture/
│   ├── architecture.md
│
├── cloudwatch/
│   └── README.md
├── docs/
│   ├── access-management.md
│   ├── discovery-and-enrollment.md
│   ├── scalability.md
│   └── security.md
└── terraform/
    ├── main.tf
    ├── outputs.tf
    └── variables.tf
```

## Prerequisites

Controller-side prerequisites include:

- Python 3
- Ansible Core
- `amazon.aws` Ansible collection
- boto3 / botocore
- AWS credentials or an IAM role capable of assuming workload roles

Managed EC2 instances require:

- SSM Agent
- Appropriate IAM instance profile
- Connectivity to required AWS service endpoints

The reference implementation was syntax/validation tested with:

- Ansible Core 2.21.4
- `amazon.aws` collection 11.4.0
- Python 3.12.3
- boto3 1.43.100
- botocore 1.43.100
- Terraform 1.13.3
- AWS provider 6.66.0

## Example Usage

Install the required Ansible collection:

```bash
ansible-galaxy collection install amazon.aws
```

Review the sample inventory:

```bash
cat ansible/inventory/aws_ec2.yml
```

Run the deployment from the `ansible` directory after configuring an
authorized AWS account context:

```bash
cd ansible
ansible-playbook playbooks/deploy-cloudwatch-agent.yml
```

Verify the monitoring agent:

```bash
ansible-playbook playbooks/verify-disk-monitoring.yml
```

Validate the Terraform reference configuration:

```bash
cd terraform
terraform init -backend=false
terraform validate
```

## Implementation Scope

This repository is a minimal reference implementation.

Implemented artifacts include:

- EC2 dynamic inventory configuration
- Tag-based monitoring enrollment
- SSM-based Ansible connection configuration
- CloudWatch Agent Ansible role
- Disk metric configuration
- Monitoring verification playbook
- Cross-account IAM reference configuration
- EC2 instance IAM role/profile reference
- Architecture and operational documentation

The target architecture also shows centralized CloudWatch cross-account
observability, dashboards, alarm automation, and SNS integration. These are
production architecture components and are not fully provisioned by the
minimal Terraform implementation in this repository.

The sample `accounts.example.yml` describes the multi-account onboarding
model; it does not automatically iterate through accounts by itself.

## Production Considerations

Before production rollout, the design should be adapted to the enterprise's
standards for AWS Organizations, IAM, networking, centralized observability,
incident management, encryption, audit logging, tag governance, alarm
lifecycle management, and configuration drift.

The Linux-focused minimal Ansible implementation can also be extended with
Windows-specific CloudWatch Agent installation and validation tasks where
Windows EC2 workloads are in scope.