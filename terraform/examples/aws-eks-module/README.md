# AWS EKS Stack Consumption Guide

Use this example when you want to consume Greptile’s EKS-based stack (`terraform/stacks/aws-eks`) from a **customer-owned Terraform root module**.

Workflow:
1. Keep your own `terraform` block, backend settings, and AWS provider (we recommend an S3 backend with keys following `tf/org/<team>/<stack>.tfstate`).
2. Set the module `source`:
   - Pin to a tag/commit such as `?ref=v0.1.0` for production.
   - During local development inside the Akupara repo, you can temporarily swap `source` to a relative path (e.g. `../../stacks/aws-eks`).
3. Populate the networking inputs (VPC + subnets), image registry/tag, and required secrets in `terraform.tfvars`.
4. Apply Terraform, then run the `kubeconfig_command` output to configure kubectl.
5. Verify the rollout (`kubectl get pods`, `kubectl get svc`, etc.) and capture the service endpoints.

Notes:
- This stack installs Kubernetes resources via the Terraform **kubernetes** and **helm** providers (no separate `helm install` step).
- Secrets are written to **SSM Parameter Store** under `/${name_prefix}/config/*` and `/${name_prefix}/secrets/*`, and also stored in **Terraform state**. Treat your state backend as sensitive.
- The Helm chart has additional feature toggles (webhook, GitHub/GitLab workers, Jackson, etc.). Today, most of those toggles are not exposed as Terraform variables; if you need them, vendor/fork the module and edit its `helm/values.yaml` (and in some cases `helm-values.yaml.tpl`).
