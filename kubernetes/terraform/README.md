# Greptile On-Prem Infrastructure Setup with Terraform

This is the [Greptile](https://greptile.com) on-prem setup guide for the infrastructure required for the Greptile kubernetes cluster using Terraform as the IaC tool of choice.

This guide assumes working knowledge of Terraform.

### Prerequisites

You will need the following:

1. An AWS and `aws-cli` with profiles set up. (GCP coming soon)

2. Access to Greptile ECR images


### Terraform Template

This repository contains a terraform deployment template for setting up the required infrastructure for running Greptile.
We recommend starting Greptile from this template and managing any of the changes to infrastructure within this file.

### Setup


Go to the directory of the cloud provider that will be used to deploy Greptile 
```sh
cd aws 
# cd gcp # the provider you are using
```

Create and populate a `terraform.tfvars` file according to the `terraform.tfvars.example` file. We recommend you change the `backend.tf` file depending where you store your remote `tfstate`.

Once complete run the command:

```sh
terraform init # run with -backend-config="[key]=[value]" to set up the remote target depending on remote used.
```

to install dependencies in preparation of deploying the infrastructure.

##### GitHub (Optional)

If using GitHub as your code provider you will need to create a GitHub App to allow Greptile to access your repositories

1. Go to your GitHub organization settings > Developer Settings > GitHub Apps > New GitHub App
2. Set the following:
    - GitHub App name: `Greptile` (or your preferred name)
    - Homepage URL: You can just write `https://greptile.com`
    - Webhook URL: Leave blank for now (we'll set this in after the application is deployed).
    - Webhook secret: Generate a secure random string
3. Permissions needed:
    - Repository:
      - Contents: Read-only
      - Metadata: Read-only
      - Pull requests: Read & Write
    - Organization:
      - Members: Read-only
4. Create the app and note down:
  - App ID (for later)
  - App URL (for later)
  - App Name (for later)
  - Client ID
  - Client secret
  - Webhook secret
  - Generate and download a private key.
5. Use the values above to populate the relevant fields in `terraform.tfvars` (or wherever the secret will be stored).

### Deployment

After you have supplied the variables you will be using, you can plan your stack with 

```sh
terraform plan
```

And after deploy with:

```sh
terraform apply
``` 

When prompted and ready to deploy, type in `yes`

This should take around 20-30 minutes

Once completed make note of the output variables from the `terraform apply` command, these will be used as values in the helm chart deployment of the cluster.

### Tear Down

To tear down the infrastructure you can simply use

```sh
terraform destroy
```