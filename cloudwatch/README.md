# CloudWatch Disk Monitoring

## Metric Collection

The Amazon CloudWatch Agent runs on enrolled EC2 instances and publishes
guest operating-system filesystem metrics to the custom namespace:

`Lucidity/DiskMonitoring`

The primary metric used for capacity monitoring is:

`disk_used_percent`

The configuration also collects:

`disk_free`

Metrics are collected every 60 seconds by default.

## Why a Guest Agent Is Required

Standard EC2 and EBS metrics describe infrastructure and storage-device
behavior, but they do not provide the percentage of space consumed inside
each guest operating-system filesystem.

The CloudWatch Agent provides this guest-level visibility.

## Filesystem-Level Monitoring

Disk utilization is evaluated per filesystem/mount point rather than
aggregating all filesystems on an instance into one value.

For example, an instance may have:

- `/` at 55%
- `/var` at 82%
- `/data` at 94%

A single instance-level average could hide the nearly-full `/data`
filesystem.

## Alerting Strategy

Example configurable thresholds:

- Warning: disk utilization >= 80%
- Critical: disk utilization >= 90%

Production thresholds should be selected according to workload behavior,
filesystem growth rate, operational response time, and business criticality.

CloudWatch alarms can publish notifications to Amazon SNS for integration
with email or an organization's incident-management platform.

## Missing Metrics

Missing telemetry must also be treated as an operational signal.

A missing metric can indicate:

- CloudWatch Agent failure
- EC2 instance failure
- Network/connectivity problems
- IAM permission problems
- An instance that has not been enrolled correctly

Production monitoring should therefore include agent/telemetry health in
addition to disk-capacity thresholds.

## Centralized Observability

In a multi-account AWS environment, CloudWatch cross-account observability
or an equivalent centralized monitoring pattern can provide operations
teams with a consolidated view while workload metrics remain associated
with their source accounts.

The exact centralization model should follow the enterprise's AWS
Organizations and observability standards.
