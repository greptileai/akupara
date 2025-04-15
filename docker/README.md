## Setting up Greptile using Docker Compose

The greptile app requires running an EC2 instance , a RDS postgres instance and a Redis elasticache instance. We have a terraform script that spins this up in the `docker/terraform` directory. We suggest following [this](https://github.com/greptileai/akupara/blob/main/docker/terraform/README-TF.md) doc as a guide. 

Networking items to verify once the EC2 is set up

- The following ports are open to inbound traffic
    - `3000` - this is to allow access to the greptile front-end
    - `3010` - this is to allow github webhooks to hit our github service
    - `8080` - this is for hatchet front end (useful for debugging the repository indexing process)
    - `7077` - required for hatchet communication
    - `80` and `443` - required for HTTP and HTTPS traffic
    - `5225` - Optional but required for BoxyHQ if using SAML/SSO sign in
 
- The EC2 machine has the following IAM role: `AmazonBedrockFullAccess`. This can be added under `EC2 > Instances > Security > IAM role`. This is needed for the application to make calls to the LLM

## Troubleshooting Checklist
Here are some things that can cause failed PR reviews
- One or more required services isn't running. `docker ps` should be used to verify that the following 7 services are running
   - `greptile_api_service`
   - `greptile_auth_service`
   - `greptile_indexer_chunker`
   - `greptile_indexer_summarizer`
   - `greptile_query_service`
   - `greptile_web_service`
   - `greptile_github_service`
   - Note: if a service is down you can spin it back up using `docker-compose up -d --force-recreate <service_name>`
- The Github token that is in the DB is expired/invalid. You can see the github token on file by entering the postgres db and running `select * from "Integration";`. This token can be updated in-place if invalid.
- Amazon Bedrock quota is too low, causing llm errors in the `greptile_query_service` logs. Here is what you can use to check quotas. We recommend at least 100 requests per minute and 800,000 tokens per minute.

```
For Sonnet V2:
# Requests per minute
aws service-quotas get-service-quota --quota-code L-1D3E59A3 --service-code bedrock --region us-east-1

# Tokens per minute
aws service-quotas get-service-quota --quota-code L-FF8B4E28 --service-code bedrock --region us-east-1
```
