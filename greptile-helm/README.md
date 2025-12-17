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

4. In order to download Greptile's Docker images, you need to create a Kubernetes secret with the provided token (If you do not have a token, reach out to your representative at Greptile):
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
* Under `global.ai`, configure which LLM providers you want to use:
  * baseUrl: either use the public baseUrl or a custom one if self-hosted LLMs are used.
  * modelProvider is either:
    * `anthropic` for self hosted and cloud anthropic LLMs
    * `openai` for cloud OpenAI models
    * `azure` for Azure hosted OpenAI models
  * `globbal.ai.oauthGateway`: If you use an OAuth endpoint to generate your secret LLM key fill out the fields under this section.
* Under `web.config` 
  * Set `web.config.externalUrl` to the IP address or URL that you plan to deploy Greptile on.
  * [OPTIONAL] `web.config` values:
    * web.config.authSamlOnly has to be set to `true` for SAML auth. This will disable Greptile's internal auth and rely on jackson service for SAML auth.
    * web.config.globalGitlabBaseUrl: Set to baseURl of GitLab host if entire orgs uses the same GitLab repo.
    * web.config.skipCompanyOnboarding: set to `true` if Greptile onboarding process should be skipped for new users. (Most useful if just one company uses Greptile)
    * web.config.defaultCodeProvider: set to `gitlab` or `github` depending on your main internal code provider host.
* In the secrets section:
  * for `jwtSecret`, `authSecret` and `tokenEncryptionKey` any random alphanumeric string is fine. `jwtSecret` and `authSecret` have to be identical.
  * `hatchetClientToken` Use the API key generated further above.
  * For the LLM keys, fill only those out that you are planning to use.
  * If you are using GitHub as a Code Provider, provide the `githubWebhookSecret` and the `githubPrivateKey` of your GitHub App. If not, leave it at a dummy value.
  * [OPTIONAL] If you are using a global GitLab instance across your organization, enter the group key here.
  * [OPTIONAL] If you are using an Oauth endpoint for LLM token generation, enter the `oauthGatewayClientSecret` here
  * [OPTIONAL] If you are using jackson for SAML auth, fill out the secrets `jacksonApiKeys` and `nextauthAdminCredentials`
* [OPTIONAL] `tolerations` and `nodeSelector` can be commented out in values.yaml
* [OPTIONAL] Depending on your node resources, you might want to allocate more or less resources:

  | Service Name              | CPU Request | CPU Limit | Memory Request | Memory Limit | Disk    |
  |---------------------------|-------------|-----------|----------------|--------------|---------|
  | API                       | 100m        | 2000m     | 2Gi            | 4Gi          |  -      |
  | Auth                      | 50m         | 250m      | 256Mi          | 512Mi        |  -      |
  | Chunker                   | 4000m       | 8000m     | 6Gi            | 12Gi         |  -      |
  | LLM Proxy                 | 2000m       | 4000m     | 4Gi            | 8Gi          |  -      |
  | Summarizer                | 1000m       | 2000m     | 2Gi            | 4Gi          |  -      |
  | Reviews                   | 1000m       | 2000m     | 2Gi            | 4Gi          |  -      |
  | Webhook                   | 500m        | 1000m     | 1Gi            | 2Gi          |  -      |
  | Web                       | 500m        | 1000m     | 512Mi          | 1Gi          |  -      |
  | Jobs                      | 50m         | 250m      | 256Mi          | 512Mi        |  -      |
  | Postgres                  | 4000m       | 4000m     | 8Gi            | 8Gi          |  64Gi   |
  | Hatchet                   | 4000m       | 4000m     | 8Gi            | 8Gi          |  -      |
            

6. Also take a look at `templates/configmap-common-env.yaml`. This file contains environment variables that are shared across Greptile's services. In most cases, none of these env vars should be modified and hardcoded env vars should keep their value to support Greptile as an on premise solution.


7. Deploy the greptile service by running
```
helm dependency update
helm install greptile . -f values.yaml
```
**TIP** If you encounter issues with any of the services, you can always change the value of `enabled` field to false to not deploy the respective service.

8. Monitor the deployment, all the Greptile pods should be running and active. In your Hatchet Admin portal you should see 4 workers that are registered. The chunker, summarizer and the reviews service (2x).

9. Try to access the Greptile web page by exposing the port of the web service.
