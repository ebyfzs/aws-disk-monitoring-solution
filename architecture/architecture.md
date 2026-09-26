# High-Level Architecture

The solution separates the management plane from the monitoring plane.

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

## Management Plane

The central Ansible controller discovers running EC2 instances dynamically
using AWS APIs and the `DiskMonitoring=enabled` tag.

For each workload account, the controller assumes a dedicated
`DiskMonitoringAutomationRole` using AWS STS.

AWS Systems Manager is used for instance management rather than requiring
public IP addresses, inbound SSH access, or shared SSH keys.

## Monitoring Plane

Ansible installs and configures the Amazon CloudWatch Agent on enrolled
instances.

The agent continuously publishes guest filesystem metrics such as
`disk_used_percent` and `disk_free` to the `Lucidity/DiskMonitoring`
namespace.

Monitoring is independent of the Ansible controller after enrollment.
If the controller is temporarily unavailable, already-enrolled instances
continue publishing telemetry.

## Multi-Account Observability

Workload metrics remain associated with their source AWS accounts.

A centralized CloudWatch observability model provides consolidated
visibility across workload accounts while preserving account boundaries.

CloudWatch dashboards provide visualization, while threshold alarms can
route operational notifications through Amazon SNS.

## Scalable Enrollment

New instances do not need to be manually added to a static inventory.

Enrollment follows this flow:

1. EC2 instance becomes an SSM managed node.
2. Required instance IAM profile is attached.
3. `DiskMonitoring=enabled` tag is applied.
4. Dynamic inventory discovers the instance.
5. Ansible deploys the CloudWatch Agent configuration.

The same account onboarding pattern can be repeated as additional AWS
accounts are introduced.

## Implementation Scope

This repository provides a minimal reference implementation for dynamic EC2
discovery, SSM-based Ansible connectivity, CloudWatch Agent deployment,
disk-monitoring verification, and supporting IAM configuration.

Centralized cross-account CloudWatch observability, production dashboards,
alarm automation, and notification integrations are represented in the
target architecture but are not fully provisioned by the minimal Terraform
reference implementation.
