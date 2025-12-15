# EKS Cluster Module

Provisions an AWS EKS cluster using **EKS Auto Mode**. The module is intentionally minimal and is meant to be composed with other infrastructure modules (VPC, RDS, Redis) and a separate IRSA role factory module.

## Scope

This module creates:

- EKS control plane with Auto Mode enabled (`compute_config`, `storage_config`, and load balancing)
- IAM roles + required managed policy attachments for Auto Mode (cluster + node roles)
- Core add-ons: `vpc-cni`, `kube-proxy`, `coredns` (pinned versions)
- OIDC provider for IRSA

This module does **not** create node groups, KMS encryption config, control-plane log settings, or custom security groups.

## Add-on version pinning

Add-ons are pinned to explicit `addon_version` strings to keep deployments reproducible. These pins must be reviewed when changing `kubernetes_version` (in particular, `kube-proxy` is selected from `local.kube_proxy_addon_versions` and must match the control plane minor version).
