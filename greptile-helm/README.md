## Deploying Greptile with Helm Charts

### Prerequisites
  - Kubernetes cluster
  - kubectl
  - helm
  - An API token to download Greptile Docker images

### Overview
This directory contains a helm chart to deploy Greptile on premise in a Kubernetes cluster. Greptile is composed of the following Microservices where each service is deployed in its own Pod:
* Web: hosts the Greptile app website/
* API: hosts the API endpoints for Greptile
* Auth: authenticates users
* Chunker: Chunks newly added repository
* Summarizer: summarizes indexed repository
* Reviews: Generates the PR reviews.
* Webhook: webhook endpoint for Github/Gitlab
* Jobs: Cron job for daily analytics gathering

Besides these internal Greptile services, Greptile has the following third-party dependencies to work:
* Postgres
* Hatchet
* [Optional] Redis
* [Optional] Jackson (for SSO authentication)

By following this README you should be able to setup a first working instance of Greptile on your Kubernetes cluster.

### Setup
The steps below where tested on a single node locally hosted Kubernetes cluster.

1. Ensure that `kubectl` is pointing at the Kubernetes cluster

```bash
kubectl config current-context
```

2. Start by installing the first dependency - Hatchet by following these steps:

```
helm repo add hatchet https://hatchet-dev.github.io/hatchet-charts
helm install hatchet-stack hatchet/hatchet-stack -f hatchet-values.yaml
```
**NOTE** The hatchet-values.yaml contains a basic setup to get you started. Feel free to adjust it to your environment.

3. Ensure to expose the caddy service that was brought as part of the hatchet-stack. This will enable access to the hatchet admin portal. Log in with the default credentials from the `hatchet-values.yaml` and generate an API token. To do so navigate to the Settings tab in the Hatchet frontend and click on the API Tokens tab. Click the Generate API Token button to create a new token. Store this token somewhere safe.

```
# The command below might have to be edited based on your environment
kubectl port-forward svc/caddy 8080:8080
```

4. In order to download Greptile's Docker images, your need to create a Kubernetes secret with the provided token (If you do not have a token, reach out to your representative at Greptile):
```
kubectl create secret docker-registry regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=greptileai \
  --docker-password=<token> \
  --docker-email=<your_email>@<your_domain>.com
```
**NOTE**: Ensure you use these exact names and only replace the values in <>.

5. Open the `values.yaml` and familiarize yourself with it. This file consists of:
* the Greptile services listed above
* The Postgres and Redis dependency
* Two migration jobs under the `migrations` section - named `db` and `vectordb`. These will only have to be run once to setup and create the schemas inside the postgres database and can be disabled in later runs by setting `enabled` to false.
* A secrets section at the bottom of the file.

6. Before you can continue with the deployment, you will have to update the following values in `values.yaml`
* web.config.externalUrl to the IP address or URL that you plan to deploy it on.
* In the secrets section:
  * for `jwtSecret`, `authSecret` and `tokenEncryptionKey` any random alphanumeric string is fine. `jwtSecret` and `authSecret` have to be identical.
  * `hatchetClientToken` Use the API key generated further above
  * For the LLM keys, fill only those out that you are planning to use.
  * If you are using GitHub as a Code Provider, provide the `githubWebhookSecret` and the `githubPrivateKey` of your GitHub App. If not, leave it at a dummy value.
* [Optional] `tolerations` and `nodeSelector`
* [Optional] Depending on your node resources, you might want to allocate more or less resources. As a reference this is what a Greptile hosted on production system should use:

| Service Name              | CPU Request | CPU Limit | Memory Request | Memory Limit | Replicas | Disk    |
  |---------------------------|-------------|-----------|----------------|--------------|----------|---------|
  | API                       | 100m        | 2000m     | 2Gi            | 4Gi          | 20       | -       |
  | Auth                      | 63m         | 250m      | 256Mi          | 512Mi        | 1        | -       |
  | Chunker                   | 4000m       | 8000m     | 24Gi           | 48Gi         | 10       | -       |
  | Summarizer                | 1000m       | 2000m     | 2Gi            | 4Gi          | 50       | -       |
  | Reviews                   | 500m        | 1000m     | 1Gi            | 2Gi          | 36       | -       |
  | Webhook                   | 500m        | 1000m     | 1Gi            | 2Gi          | 5        | -       |
  | Web                       | 500m        | 1000m     | 512Mi          | 1Gi          | 3        | -       |
  | Jobs                      | 63m         | 250m      | 256Mi          | 512Mi        | 1        | -       |
  | Postgres                  | 4000m       | 4000m     | 8Gi            | 8Gi          | 1        | 64Gi    |
  | Hatchet                   | 4000m       | 4000m     | 8Gi            | 8Gi          | 1        | -       |
  | Redis                     | 1000m        | 2000m     | 2Gi            | 2Gi          | 1        | -       |
            

6. Also take a look at `templates/configmap-common-env.yaml`. This file contains more environment variables. Most of them don't have to be or should not be changed except for the variables listed under `LLM Configuration`. Adjust them according to the models you would like to use.


7. Deploy the greptile service by running
```
helm dependency update
helm install greptile . -f values.yaml
```
**TIP** If you encounter issues with any of the services, you can always change the value of `enabled` field to false to not deploy the respective service.

8. Monitor the deployment, all the Greptile pods should be running and active. In your Hatchet Admin portal you should see 4 workers that are registered. The chunker, summarizer and the reviews service (2x).

9. Try to access the Greptile web page by exposing the port of the web service.
