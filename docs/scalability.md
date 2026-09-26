# Scalability

## Design Principle

The monitoring solution separates configuration management from continuous
telemetry collection.

Ansible is used to discover and configure instances.

The CloudWatch Agent running on each enrolled EC2 instance performs
continuous metric collection.

This means the Ansible controller does not need to execute `df` against
every server every minute.

## Scaling the EC2 Fleet

Dynamic inventory removes the need to maintain static IP address lists.

New instances become eligible for enrollment when they:

1. Are available through Systems Manager.
2. Have the required IAM instance profile.
3. Receive the `DiskMonitoring=enabled` tag.

This pattern works with dynamically changing EC2 fleets, including
instances created or replaced by Auto Scaling Groups.

## Scaling Across AWS Accounts

Each workload account uses the same onboarding pattern:

- Cross-account automation role
- EC2 instance role/profile
- Systems Manager connectivity
- Monitoring enrollment tags
- CloudWatch Agent configuration

The central automation identity uses temporary STS credentials rather than
maintaining separate long-lived credentials for every AWS account.

## Scaling Across Regions

The AWS EC2 dynamic inventory can query additional regions as the
environment grows.

The sample repository uses `eu-west-1` for clarity, but the architecture is
not limited to one region.

## Monitoring Scalability

Continuous filesystem telemetry is distributed across the monitored EC2
fleet through the CloudWatch Agent.

Metrics are published to CloudWatch rather than being stored or processed
by the Ansible controller.

This keeps the controller out of the continuous monitoring data path.

## Account and Instance Metadata

EC2 tags provide scalable metadata for:

- Monitoring enrollment
- Environment grouping
- Application grouping

Additional tags such as business unit, owner, service tier, or criticality
can be incorporated without redesigning the discovery model.

## Failure Isolation

An outage of the Ansible controller does not stop already-configured
CloudWatch Agents from publishing telemetry.

Similarly, a problem in one workload account does not require monitoring
configuration in every other workload account to stop.

## Production Extensions

At larger scale, the design can be extended with:

- Automated account onboarding
- AWS Organizations integration
- Centralized CloudWatch cross-account observability
- Automated alarm lifecycle management
- Standardized tag policies
- Configuration drift detection
- Integration with enterprise incident-management platforms