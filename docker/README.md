# Setting up Greptile using Docker Compose

## Prerequisites

Before you begin, ensure you have the following:

* **AWS Account:** You will need an active AWS account with appropriate permissions to create resources (EC2, RDS, ElastiCache, IAM, Security Groups).
* **AWS CLI:** The AWS Command Line Interface (CLI) is recommended for certain tasks.
* **Terraform:** Terraform (version 1.11.3 or later) You can download it from [https://www.terraform.io/downloads.html](https://www.terraform.io/downloads.html).
* **A GitHub App:** You will need to configure the URLs using the ip address of the EC2 which can be found in the Terraform output.

The greptile app requires running an EC2 instance, a RDS postgres instance, and a Redis elasticache instance. We have a terraform script that spins this up in the `docker/terraform` directory. We suggest following [this](https://github.com/greptileai/akupara/blob/main/docker/terraform/README-TF.md) doc as a guide.

Networking items to verify once the EC2 is set up

- The following ports are open to inbound traffic
    - `3000` - this is to allow access to the greptile front-end
    - `3010` - this is to allow github webhooks to hit our github service
    - `8080` - this is for hatchet front end (useful for debugging the repository indexing process)
    - `7077` - required for hatchet communication
    - `80` and `443` - required for HTTP and HTTPS traffic
    - `5225` - Optional but required for BoxyHQ if using SAML/SSO sign in
 
- The EC2 machine has the following IAM role: `AmazonBedrockFullAccess`. This can be added under `EC2 > Instances > Security > IAM role`. This is needed for the application to make calls to the LLM
