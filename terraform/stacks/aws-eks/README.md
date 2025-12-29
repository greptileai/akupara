# AWS EKS Stack for Greptile

Deploy Greptile on **Amazon EKS (Auto Mode)** with managed **RDS PostgreSQL**, managed **ElastiCache Redis**, and Kubernetes-native orchestration via a Terraform-managed Helm release.

This stack is intended for **Platform / SRE** teams who want managed Kubernetes with rolling updates and horizontal scaling.

This directory is a **Terraform module** (not a deployment repo). It is designed to be consumed from a customer-owned **root module** that owns:
- Terraform backend/state configuration
- Environment wiring (VPC/subnets, tags, etc.)
- Any additional infrastructure in the same deployment repo

Start from the copy/paste root module example: `terraform/examples/aws-eks-module/`.

## What this stack provisions

- **EKS Auto Mode** cluster (control plane + managed compute) and OIDC provider for IRSA
- **Subnet tagging** for Kubernetes Service/Ingress load balancer discovery
- **AWS Load Balancer Controller** (Helm, `kube-system`)
- **RDS PostgreSQL** (Greptile + Hatchet databases on the same instance)
- **ElastiCache Redis** (TLS-enabled by chart defaults)
- **KMS key** for SSM SecureString parameters
- **SSM Parameter Store**:
  - `/${name_prefix}/config/*` (String)
  - `/${name_prefix}/secrets/*` (SecureString)
- **IRSA roles** for External Secrets, Greptile workers (Bedrock access), and CloudWatch log shipping
- **Helm release** (the chart shipped under `helm/`) that installs:
  - External Secrets Operator (ESO)
  - Hatchet stack + token generation Job
  - Greptile services + DB migration Job + optional integrations

## Architecture

```mermaid
flowchart TB
  subgraph AWS["AWS Account / VPC"]
    subgraph Subnets["Subnets"]
      Priv["Private subnets (EKS, RDS, Redis)"]
      Pub["Public subnets (optional; for internet-facing LBs)"]
    end

    TF["Terraform (root module)"]
    EKS["EKS cluster (Auto Mode)"]
    RDS["RDS PostgreSQL"]
    Redis["ElastiCache Redis"]
    SSM["SSM Parameter Store\n/{name_prefix}/config/*\n/{name_prefix}/secrets/*"]
    KMS["KMS key (SSM SecureString)"]
    CWLG["CloudWatch Log Group\n/greptile/{name_prefix}/application"]

    TF -->|creates| EKS
    TF -->|creates| RDS
    TF -->|creates| Redis
    TF -->|writes params| SSM
    TF -->|creates| KMS
    TF -->|creates (optional)| CWLG

    subgraph K8S["Kubernetes namespace (k8s_namespace)"]
      LBC["AWS Load Balancer Controller"]
      ESO["External Secrets Operator"]
      ES["ExternalSecret/SecretStore"]
      K8SSecrets["Kubernetes Secrets\n(greptile-env, llm-env,\nhatchet-shared-config, hatchet-client-config)"]
      Greptile["Greptile services\n(web/api/auth/indexer/...)"]
      Hatchet["Hatchet stack (internal)\n+ token generation Job"]
      CWAgent["CloudWatch Agent DaemonSet (optional)"]
    end

    SSM -->|read| ES --> K8SSecrets --> Greptile
    SSM -->|read| ES --> K8SSecrets --> Hatchet
    LBC -->|provisions| ALB["Internal ALB (Hatchet Ingress)"]
    LBC -->|provisions| NLB["NLBs for Service type=LoadBalancer (web, webhook)"]
    CWAgent -->|ships logs| CWLG
  end
```

### Secret/config flow

1. Terraform creates/updates SSM parameters under `/${name_prefix}/config/*` and `/${name_prefix}/secrets/*`.
2. External Secrets Operator (via IRSA) reads SSM and creates Kubernetes Secrets.
3. Greptile/Hatchet pods import env vars from those Secrets.

Important: Terraform also stores these values in **Terraform state**. Treat your state backend (local or remote) as sensitive.

Tip: `ssm-env-keys.example.yaml` lists the on-prem env keys (from `docker/.env.example`) to help populate `ssm_config_keys`/`ssm_secrets_keys` when SSM parameters are managed outside Terraform.

### Network boundaries

- EKS control plane and compute run in `private_subnet_ids` (EKS API endpoint is private; public access is optional via `endpoint_public_access`).
- RDS and Redis are deployed in `private_subnet_ids` and restrict inbound access to the **EKS cluster security group** by default.

## Prerequisites

### Tooling

- Terraform >= 1.5.0
- AWS CLI (with credentials/profile configured)
- kubectl (for verification and debugging)
- Helm CLI (optional; Terraform uses the Helm provider, but `helm` is useful for debugging)

### AWS account / IAM permissions

At minimum, the credentials used for `terraform apply` must be able to create/manage:

- EKS (cluster, add-ons, OIDC provider)
- IAM (roles, policy attachments, OIDC trust)
- EC2 (subnet tagging, security groups)
- RDS (instance, subnet groups, parameter groups, snapshots)
- ElastiCache (replication group, subnet groups)
- SSM Parameter Store (String + SecureString)
- KMS (key + alias)
- CloudWatch Logs (log group), if `cloudwatch_logs_enabled = true`

This stack attaches **`AmazonBedrockFullAccess`** to the indexer IRSA role. Review and restrict if your environment requires least privilege.

### Networking (VPC + subnets)

- A VPC with **at least 2 private subnets** in different AZs (`private_subnet_ids`)
- Optional (recommended for public access): **at least 2 public subnets** (`public_subnet_ids`) for internet-facing load balancers
- Outbound egress from private subnets (typically via NAT Gateway) so nodes can pull images and reach AWS APIs
- VPC DNS support/hostnames enabled (standard for EKS)

Subnet tags:
- This stack tags subnets with `kubernetes.io/cluster/<cluster_name>=shared` plus:
  - Public subnets: `kubernetes.io/role/elb=1`
  - Private subnets: `kubernetes.io/role/internal-elb=1`

If your VPC/subnets are managed in a separate Terraform state, ensure that state does not remove these `kubernetes.io/*` tags during occasional VPC re-applies (e.g., via `ignore_changes` on tags).

### Container images / registry

The Helm chart constructs image names as:

`<ecr_registry>/<service>:<greptile_tag>`

You must ensure your registry contains the required repos/images (commonly: `web`, `api`, `auth`, `chunker`, `summarizer`, `db-migration-job`, `llmproxy`, `jobs`, `reviews`; plus optional `webhook`).

## Consume from a root module

This stack is designed to be imported by a customer-owned Terraform **root module**.

Recommended approach:
1. Copy `terraform/examples/aws-eks-module/` into your deployment repo.
2. Update the module `source` to either:
   - a vendored/local copy of this module, or
   - a pinned Git `?ref=` (tag/commit) you’ve validated.
3. Create `terraform.tfvars` (start from `terraform/examples/aws-eks-module/terraform.tfvars.example`).
4. Run Terraform from your root module directory.

Example flow:

```bash
export NAMESPACE="default" # or your k8s_namespace

terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"

terraform output -raw kubeconfig_command
# Run the printed command to configure kubectl.

kubectl get pods -n "$NAMESPACE"
kubectl get svc -n "$NAMESPACE"
kubectl get ingress -n "$NAMESPACE"
kubectl get secretstore,externalsecret -n "$NAMESPACE"
```

Notes:
- `terraform apply` also installs Kubernetes resources via the Terraform **kubernetes** and **helm** providers.
- If `endpoint_public_access = false`, run Terraform from a network that can reach the cluster’s **private** API endpoint (e.g., within the VPC or via VPN/Direct Connect).

## Helm chart configuration (optional components)

Terraform injects required runtime values via `helm-values.yaml.tpl`. Feature toggles and most defaults live in `helm/values.yaml`.

If you need to enable optional components:
- If you consume this stack via a Git `source = "github.com/...//terraform/stacks/aws-eks?ref=..."`, vendor/fork the module so you can edit the chart defaults.
- Edit `helm/values.yaml` (and in some cases `helm-values.yaml.tpl`) and then re-run `terraform apply`.

Common toggles:

- Webhook receiver: `webhook.enabled: true`
- LLM API keys via SSM/ExternalSecrets: `llmproxy.enabled: true`
- Jackson (SSO helper): `jackson.enabled: true`

Note: setting optional Terraform variables like `github_client_secret` or `openai_api_key` will create SSM parameters, but the corresponding Kubernetes resources are only created when the chart component is enabled.

## Networking

### External endpoints

- **Greptile Web UI**: Kubernetes Service `web` (defaults to `type: LoadBalancer`, port `3000`)
- **Greptile Webhook receiver** (optional): Service `webhook` (defaults to `type: LoadBalancer`, port `3007` when enabled)
- **Hatchet UI/API** (ops-only): internal ALB via Ingresses `hatchet-frontend` and `hatchet-api` when `hatchet_ingress_enabled = true`

To secure Hatchet access (recommended), set `hatchet_ingress_annotations` to enable TLS and/or auth at the ALB layer (for example Cognito/OIDC).

Get the Web endpoint DNS:

```bash
kubectl get svc web -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}{"\n"}'
```

Get the Hatchet ALB DNS (internal):

```bash
kubectl get ingress hatchet-frontend -n "$NAMESPACE"
kubectl get ingress hatchet-api -n "$NAMESPACE"
```

### Keep internal only

Do not expose these externally:
- RDS PostgreSQL (5432)
- Redis (6379)
- Hatchet RabbitMQ (5672, 15672, etc.)
- Internal-only services (api/auth/indexer/llmproxy/jobs/reviews)

## Post-deploy

- Validate that `greptile-env` and `hatchet-shared-config` Secrets are present:
  ```bash
  kubectl get secret greptile-env -n "$NAMESPACE"
  kubectl get secret hatchet-shared-config -n "$NAMESPACE"
  kubectl get secret hatchet-client-config -n "$NAMESPACE"
  ```
- If you access the Hatchet UI/API, rotate the default Hatchet admin credentials in the chart values (`hatchet.sharedConfig.defaultAdminEmail` / `hatchet.sharedConfig.defaultAdminPassword`). This requires vendoring/forking if you consume the stack via a Git `source`.
- If you enable the webhook receiver, update your GitHub App / GitLab webhook URL to:
  - `http(s)://<webhook-lb-dns>:3007/webhook`

## Migrating from `aws-ec2` (high-level)

- Deploy `aws-eks` in parallel with a new `name_prefix` and verify it’s healthy.
- Translate your EC2 `.env` secrets into `terraform.tfvars` (the stack writes them into SSM under `/${name_prefix}/...`).
- Migrate data to the new managed RDS/Redis (snapshot/restore or other migration strategy appropriate to your environment).
- Cut traffic over (DNS / load balancer) and then destroy the old `aws-ec2` environment.

## Blue/green deployments

`name_prefix` controls:
- resource naming (cluster name is `${name_prefix}-eks`)
- the SSM prefix (`/${name_prefix}/...`)

This enables parallel environments (e.g., `prod-blue` and `prod-green`) in the same AWS account/VPC:

```bash
terraform apply -var-file="terraform.tfvars" -var='name_prefix=prod-blue'
terraform apply -var-file="terraform.tfvars" -var='name_prefix=prod-green'
```

Cut traffic over at your DNS/load balancer layer, then destroy the old environment.

## Upgrades

- Update `greptile_tag` and run `terraform apply`.
- For Kubernetes version upgrades, update `kubernetes_version` and ensure add-on pins support that version (see `terraform/modules/aws/eks-cluster/main.tf`).

## Destroy

```bash
terraform destroy -var-file="terraform.tfvars"
```

RDS snapshot behavior is controlled by:
- `db_skip_final_snapshot`
- `db_final_snapshot_identifier`
- `db_delete_automated_backups`

## Troubleshooting

### Load balancers not provisioning

- Confirm subnet tags exist (and weren’t removed by another Terraform state):
  - `kubernetes.io/role/elb=1` on public subnets
  - `kubernetes.io/role/internal-elb=1` on private subnets
  - `kubernetes.io/cluster/<cluster_name>=shared` on all tagged subnets
- Check controller status:
  ```bash
  kubectl get pods -n kube-system | grep aws-load-balancer-controller || true
  kubectl logs -n kube-system deploy/aws-load-balancer-controller
  ```

### External Secrets not syncing

```bash
kubectl get secretstore,externalsecret -n "$NAMESPACE"
kubectl describe externalsecret greptile-env -n "$NAMESPACE"
kubectl describe secretstore greptile-ssm -n "$NAMESPACE"
```

If IRSA is misconfigured, verify the ServiceAccount annotation:

```bash
kubectl get sa external-secrets-sa -n "$NAMESPACE" -o yaml
```

### Pods stuck in `Init:` (DB readiness)

Most Greptile Deployments include an init container named `wait-for-db`:

```bash
kubectl logs deploy/web -c wait-for-db -n "$NAMESPACE"
kubectl logs deploy/api -c wait-for-db -n "$NAMESPACE"
```

Confirm RDS endpoint and security group rules:

```bash
terraform output -raw rds_endpoint
```

### Hatchet token generation issues

The stack creates `hatchet-client-config` via a Helm hook Job named `greptile-hatchet-token`:

```bash
kubectl get jobs -n "$NAMESPACE"
kubectl logs job/greptile-hatchet-token -n "$NAMESPACE"
kubectl get secret hatchet-client-config -n "$NAMESPACE"
```

## Variables reference

See `variables.tf` for the full source of truth. Highlights below.

### Required

| Name | Description |
|---|---|
| `vpc_id` | VPC ID where all resources are created |
| `private_subnet_ids` | Private subnet IDs (min 2 AZs) |
| `ecr_registry` | Registry/prefix for image pulls (used as `<ecr_registry>/<service>:<tag>`) |
| `greptile_tag` | Greptile image tag |
| `db_password` | RDS master password (SecureString in SSM) |
| `redis_auth_token` | Redis auth token (SecureString in SSM) |
| `jwt_secret` | Greptile JWT secret (>= 32 chars) |
| `token_encryption_key` | Greptile token encryption key (>= 32 chars) |

### Optional

| Name | Default | Description |
|---|---:|---|
| `aws_region` | `us-east-1` | AWS region |
| `aws_profile` | `default` | AWS CLI profile |
| `name_prefix` | `greptile` | Naming prefix + blue/green isolation |
| `environment` | `production` | Environment label |
| `public_subnet_ids` | `[]` | Public subnets for internet-facing LBs |
| `kubernetes_version` | `1.31` | EKS control plane version |
| `endpoint_public_access` | `true` | Public EKS API endpoint |
| `k8s_namespace` | `default` | Namespace to deploy into |
| `db_username` | `postgres` | RDS master username |
| `db_name` | `greptile` | Initial DB name |
| `db_allocated_storage` | `400` | RDS storage (GiB) |
| `db_max_allocated_storage` | `1000` | RDS autoscaling max (GiB) |
| `db_instance_class` | `db.m5.large` | RDS instance class |
| `db_engine_version` | `16.10` | Postgres engine version |
| `db_storage_type` | `io1` | RDS storage type |
| `db_iops` | `3000` | RDS IOPS (for `io1`) |
| `db_backup_retention_period` | `14` | Backup retention days |
| `db_backup_window` | `03:00-04:00` | Backup window |
| `db_maintenance_window` | `Mon:04:00-Mon:05:00` | Maintenance window |
| `db_copy_tags_to_snapshot` | `true` | Copy tags to snapshots |
| `db_delete_automated_backups` | `false` | Delete automated backups on destroy |
| `db_skip_final_snapshot` | `false` | Skip final snapshot on destroy |
| `db_final_snapshot_identifier` | `null` | Final snapshot name override |
| `redis_node_type` | `cache.t3.micro` | ElastiCache node type |
| `redis_engine_version` | `6.2` | Redis engine version |
| `anthropic_api_key` | `null` | Optional; stored to SSM |
| `openai_api_key` | `null` | Optional; stored to SSM |
| `github_client_id` | `null` | Optional; stored to SSM config |
| `github_client_secret` | `null` | Optional; stored to SSM |
| `github_webhook_secret` | `null` | Optional; stored to SSM |
| `github_private_key` | `null` | Optional; stored to SSM |
| `ssm_secrets` | `{}` | Extra SSM SecureString params under `/${name_prefix}/secrets/*` |
| `ssm_secrets_keys` | `[]` | Extra SecureString keys to expose (managed outside Terraform) |
| `ssm_config` | `{}` | Extra SSM String params under `/${name_prefix}/config/*` |
| `ssm_config_keys` | `[]` | Extra String keys to expose (managed outside Terraform) |
| `cloudwatch_logs_enabled` | `true` | Create log group + ship logs |
| `cloudwatch_logs_retention_in_days` | `731` | Log retention |
| `cloudwatch_log_group_name` | `null` | Override log group name |
| `hatchet_ingress_enabled` | `true` | Internal ALB Ingress for Hatchet |
| `hatchet_ingress_host` | `""` | Optional host match for Hatchet Ingress |
| `hatchet_ingress_annotations` | `{}` | Extra ALB annotations (auth/TLS/etc) |
| `tags` | `{}` | Extra AWS tags |

## Outputs

See `outputs.tf` for the full source of truth.

| Output | Description |
|---|---|
| `cluster_name` | EKS cluster name |
| `cluster_endpoint` | EKS API endpoint |
| `rds_endpoint` | RDS endpoint |
| `redis_endpoint` | Redis primary endpoint |
| `ssm_prefix` | `/${name_prefix}` prefix for SSM parameters |
| `kms_key_arn` | KMS key ARN used for SecureString parameters |
| `external_secrets_role_arn` | IRSA role ARN for External Secrets |
| `indexer_role_arn` | IRSA role ARN for indexer (Bedrock) |
| `cloudwatch_role_arn` | IRSA role ARN for CloudWatch agent |
| `cloudwatch_log_group_name` | Log group name (or null if disabled) |
| `kubeconfig_command` | Convenience command for `aws eks update-kubeconfig` |
