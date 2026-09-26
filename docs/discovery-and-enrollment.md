# Discovery and Enrollment

## Dynamic Discovery

The solution avoids maintaining static EC2 IP address lists.

Ansible uses the `amazon.aws.aws_ec2` dynamic inventory plugin to discover
running EC2 instances from AWS APIs.

Instances explicitly opt in to monitoring using:

`DiskMonitoring=enabled`

The reference inventory therefore selects:

- Running EC2 instances
- Instances tagged `DiskMonitoring=enabled`

## Dynamic Grouping

Discovered instances are grouped using EC2 metadata such as:

- `Environment`
- `Application`

This allows Ansible operations to target logical groups without maintaining
static inventories.

## Secure Connectivity

The discovered EC2 instance ID is used as the Ansible host target.

The `amazon.aws.aws_ssm` connection plugin provides connectivity through
AWS Systems Manager rather than SSH.

The connection plugin uses a dedicated S3 transfer bucket for temporary
Ansible module/file transfer.

## Enrollment Flow

1. Launch or identify an EC2 instance.
2. Attach the required IAM instance profile.
3. Ensure SSM Agent is running and the instance is an SSM managed node.
4. Apply `DiskMonitoring=enabled`.
5. Dynamic inventory discovers the instance.
6. Ansible connects through Systems Manager.
7. Ansible installs and configures the CloudWatch Agent.
8. The agent continuously publishes filesystem metrics to CloudWatch.

## Multi-Account Discovery

The `amazon.aws.aws_ec2` inventory plugin supports `assume_role_arn`.

The central controller begins with an approved AWS identity that is allowed
to call `sts:AssumeRole`.

Each workload-account inventory source specifies its dedicated
`DiskMonitoringAutomationRole`.

Example:

```yaml
plugin: amazon.aws.aws_ec2

assume_role_arn: arn:aws:iam::111111111111:role/DiskMonitoringAutomationRole

regions:
  - eu-west-1

filters:
  instance-state-name: running
  tag:DiskMonitoring: enabled
```

Multiple `.aws_ec2.yml` inventory sources can be stored in an inventory
directory, with one source representing each workload account.

Example:

```text
inventory/multi-account/
├── production.aws_ec2.yml
└── development.aws_ec2.yml
```

The inventory can then be inspected with:

```bash
ansible-inventory \
  -i inventory/multi-account/ \
  --graph
```

and used for deployment with:

```bash
ansible-playbook \
  -i inventory/multi-account/ \
  playbooks/deploy-cloudwatch-agent.yml
```

The account IDs in this repository are placeholders and must be replaced
with the target organization's workload-account IDs.

## Adding Another Account

Onboarding another AWS account requires:

1. Deploy the `DiskMonitoringAutomationRole` in the workload account.
2. Trust the approved central automation identity.
3. Add an inventory source containing the workload role ARN.
4. Ensure target EC2 instances are SSM managed nodes.
5. Apply the monitoring enrollment tag.

No VM IP addresses or SSH keys need to be added to Ansible inventory.

## Regional Expansion

The reference configuration uses `eu-west-1`.

Additional regions can be added to the `regions` list without changing the
overall discovery model.