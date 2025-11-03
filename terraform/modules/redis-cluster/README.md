# Redis Cluster Module

Creates a private ElastiCache Redis replication group, subnet group, and security group suitable for the Greptile on-prem stack.

Key features:
- Takes existing private subnet IDs and allowed security group IDs for ingress.
- Configurable node type, engine version, encryption flags, and description.
- Exposes the primary endpoint for Helm value injection.
