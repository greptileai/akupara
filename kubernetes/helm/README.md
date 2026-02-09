# Greptile On-Prem Setup

This is the [Greptile](https://greptile.com) on-prem setup guide.

This guide assumes a working knowledge of Kubernetes and have [helm](https://helm.sh/docs/intro/install/) and [kubectl](https://kubernetes.io/docs/tasks/tools/) installed.

### Prerequisites

You will need to configure and provision the following resources: 

1. A Secrets Provider/Mananger/Vault
	- Currently only supporting AWS Secrets Manager out of the box, however you can configure however you'd like it to.
2. A Postgres database
	- Recommend AWS RDS as it is managed by AWS + comes with pgvector.
3. A Redis instance
	- Recommend Redis OSS Elasticache for AWS
4. An LLM Provider
	- OpenAI, Azure OpenAI, Anthropic, and AWS Bedrock supported.

If coming from the Terraform setup guide, the vault, database, and cache should already be set up.

## AWS

### Step 1: Helm Chart Setup

- Download the greptile helm chart tarball: `greptile-[x.x.x].tgz`
- Extract it locally in a new directory
```sh
tar -xzvf greptile-[x.x.x].tgz
```
The directory looks something like:
```
.
├── Chart.yaml
├── charts/
├── storage/
├── secrets/
├── templates/
│   ├── api/
│   ├── auth
│   ├── db/
│   ├── indexer/
│   ├── integrations/
│   ├── jackson/
│   ├── query/
│   ├── vectordb/
│   └── web/
├── values.yaml
└── aws.yaml
```
Install the the following repositories from helm:
```sh
helm repo add hatchet-stack https://hatchet-dev.github.io/hatchet-charts
helm repo add external-secrets https://charts.external-secrets.io
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver
helm repo add stakater https://stakater.github.io/stakater-charts
```

Run the following to update the repository indexes and build the dependencies:
```sh
helm repo update
helm dependency update
helm dependency build
```

Create a `values-override.yaml` file from the template outlined in `values-override.yaml.example` file. 

If coming from the Terraform setup, populate the fields from the outputs obtained from the `terraform apply` command.

The registry URL will be provided from us.

### Step 2: Setting up the EKS Cluster (Manual)

**NOTE: This step is only necessary if you are not deploying the on-prem infrastructure with Terraform.**

Ensure you have the correct aws credentials set up in your terminal using `aws configure list`

Then run:
```sh
eksctl create cluster \
  --name <cluster_name> \
  --region <aws_region>
	[--profile <aws-profile>]
```

Once the cluster is created, through the management console add the following policy to the Node Groups IAM Role: `AmazonEBSCSIDriverPolicy`
(Found in EKS > Clusters > <cluster_name>  > Node Groups (Under compute) > <node_group_name> > Node IAM Role ARN)


### Step 3: Configuration and Secrets (Manual)

**NOTE: This step is only necessary if you are not deploying the on-prem infrastructure with Terraform.**

Refer to the `values.yaml` and `aws.yaml` file. Here we have defined the default configuration for greptile on AWS.
We recommend creating a `values-override.yaml` file to set and override values, an example outline is provided in the `values-override-example.yaml` file.
Make sure the ` .Values.global.region ` value is set to the correct region you will be deploying Greptile to.
If you have a custom domain you want to use for the Greptile web app and/or the api (recommend something like `greptile.company.com` and `api.greptile.company.com`), you can set it under ` .Values.web.config.url` and ` .Values.api.config.url ` respectively, you will have to set up the the proper records with your domain name service after retrieving the external facing url assigned by Kubernetes in the final step.

Refer to the `secrets/secrets.yaml` and `secrets/external-secrets.yaml` file, here we pull in sensitive values from
your secrets provider/vault. We currently only support AWS secrets manager.
Each file should have a guide on how to set up each type of secret.

##### Set Up Your GitHub App

If using GitHub as your code provider you will need to create a GitHub App to allow Greptile to access your repositories

1. Go to your GitHub organization settings > Developer Settings > GitHub Apps > New GitHub App
2. Set the following:
    - GitHub App name: `Greptile`
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
6. Store these values in your AWS Secrets Manager as a JSON object:
	```json
	{
		"clientId": "your_client_id",
		"clientSecret": "your_client_secret",
		"webhookSecret": "your_webhook_secret",
		"privateKey": "-----BEGIN RSA PRIVATE KEY-----\nYour private key content...\n-----END RSA PRIVATE KEY-----"
	}
	```
7. Update your `values-override.yaml` with the GitHub app details:
```yaml
github:
	oauth:
		enabled: true
	config:
		enterprise: false  # set to true if using GitHub Enterprise and populate the other fields accordingly
		appId: "your_app_id"
		appUrl: "https://github.com/apps/your-app-name"
		name: "your-app-name"
```
##### Setting Up RDS 

We recommend the following configuration

Engine: PostgreSQL
Engine Version: PostgreSQL 16.3-R3
Template: Production 
Availability and durability: Single DB instance (worked fine for our internal usage)
DB instance Identifer: [name of your database] (will need to set this in in `.Values.database.config.name`)
Credentials management: AWS Secrets Manager recommended.
Storage type: General Purpose SSD (gp3).
Allocated Storage: the default 200 GiB should be enough for most repositories, this should autoscale and also you can also allocate more later.
Networking: You will need to ensure that the database can connect to your EKS cluster.

Once created populate the `.Values.database.env.host` to the database host and
point the `database-secret` in the `./secrets/external-secrets.yaml` file to the created/generated vault with the database username and password set.

##### Setting Up Redis

The default configuration should work with Greptile.
If any changes are introduced make sure Greptile has networking access and if it is password protected make sure to set the `REDIS_PASSWORD` environment variable in the `app-secrets` of the Kubernetes cluster.

##### AWS Bedrock

We require getting access to an embedding model, a 'small' model and a 'SOTA' model. In AWS Bedrock we have seen the best results with:

- Claude 3.5 Sonnet v2
- Claude 3.5 Haiku
- Titan Embeddings G1 - Text Embeddings Model

You should get access to the via the Model Access page in the management console.
Once access is granted, Greptile uses the Cross-region inference profiles to make requests to AWS Bedrock.
To grant the EKS Node Group access to AWS Bedrock you will need to add the following inline policy to the Node Group's IAM Role (it should look something like `arn:aws:iam::<account_number>:role/eksctl-<cluster_name>-nodegroup-NodeInstanceRole-*`):
```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "InvokeDomainInferenceProfiles",
			"Effect": "Allow",
			"Action": [
				"bedrock:InvokeModel",
				"bedrock:InvokeModelWithResponseStream"
			],
			"Resource": "arn:aws:bedrock:*:*:*"
		}
	]
}
```

### Step 4: Set up Greptile

Now all of the base infrastructure and services should be set up, update the current context of kubectl with:

```sh
aws eks update-kubeconfig --name <cluster_name> --region <aws_region> [--profile <aws_profile>]
```

Verify that `kubectl` is pointing to the correct cluster by running:
```sh
kubectl config current-context
```

To use external secrets we also install the external-secrets repo as well

```sh
helm install external-secrets external-secrets/external-secrets \
    --namespace default \
    --set installCRDs=true
```
These changes may take a couple of seconds to get fully up and running.

For aws we need to set up storage classes that Greptile will use, run:
```sh
kubectl apply -f storage/pv-aws.yaml -f storage/pvc-aws.yaml -f storage/sc-aws.yaml
```

Now you deploy Greptile to your EKS cluster:
```sh
helm upgrade --install greptile . -f values.yaml -f aws.yaml -f values-override.yaml
```

Check out the pods with:
```sh
kubectl get pods
```
### Step 5: URL set up

For services that should be publicly accessible, (`api`, `jackson`, `web`, `github`, `gitlab`) you should retrieve them with:

```sh
kubectl get svc
```

If setting up a custom domain you should use these urls to set up required domain name records.

You should set the `url` field under ` .Values.api.config`, ` .Values.jackson.config`, and ` .Values.web.config` (outlined in `values-override.yaml.example`) respective service/custom domains.

Then run:
```sh
helm upgrade --install greptile . -f values.yaml -f aws.yaml -f values-override.yaml
kubectl rollout restart deployment/web deployment/api
```


You can then access the Greptile web app with the `web` custom or service url and port as:

```
http://[svc/web url]:[svc/web port]
```

### Step 6: Complete Integrations Setup

There are additional steps to connect Greptile to the different integrations provided.

##### GitHub

Complete the setting up GitHub by:

1. Get your `github` service URL:
```sh
kubectl get svc
```
2. Your webhook URL will be: `http://[github-service-url]:[port]/webhook`
3. Go back to your GitHub App settings and update the Webhook URL
4. Ensure the webhook is active

##### GitLab

Make sure to use the `gitlab` service URL when setting up the webhook:

1. Get your `gitlab` service URL:
```sh
kubectl get svc
```
2. Your webhook URL will be: `http://[gitlab-service-url]:[port]/webhook`
3. When adding the GitLab webhook url make sure it is set to the url obtained from above.

## GCP
Coming Soon...