## Setting up Greptile using Docker Compose

The greptile app requires running an EC2 instance , a RDS postgres instance and a Redis elasticache instance. We have a terraform script that spins this up in the `docker/terraform` directory. We suggest following [this](https://github.com/greptileai/akupara/blob/main/docker/terraform/README-TF.md) doc as a guide. 

Once you are done spinning up the infrastructure, you can create a Github App with the following permissions 

### Step 1: Fill up a `.env` file based on the `.env.example` file. 
In order to do this, you must first create a new Github App in your Github account. 

1. Go to your GitHub organization settings > Developer Settings > GitHub Apps > New GitHub App
2. Set the following:
    - GitHub App name: `Greptile` (or your preferred name)
    - Homepage URL: You can just write `https://greptile.com`
    - Callback URL: `http://<ip_address>:3000/api/auth/callback/github-enterprise` or `http://<ip_address>:3000/api/auth/callback/github` (depending on whether you are using cloud github or self-hosted)
    - Setup URL: `http://<ip_address>:3000/auth/github` And Select Redirect on Update.
    - Webhook URL: `http://<ip_address>:3010/webhook`
    - Webhook secret: Generate a secure random string
3. Permissions needed:
    - Repository:
      - Contents: Read-only
      - Metadata: Read-only
      - Issues: Read & Write
      - Metadata: Read only
      - Webhooks: Read & Write
      - Pull requests: Read & Write
    - Organization:
      - Events: Read only    
      - Members: Read-only
    - Account Permissions
      - Email Addresses: Read only
    - Subscribe to Events
      - Issues
      - Issue Comment
      - Pull Request
      - Pull Request Review
      - Pull Request Review Comment
      - Pull Request Review Thread
     
**Important Note:** Make sure to Opt-Out of the User-to-server token expiration. This can be found under Optional Features in the github app settings.

4. Create the app and use the values below to populate the relevant fields in the `.env` file:
  - App ID 
  - App URL 
  - App Name 
  - Client ID
  - Client secret
  - Webhook secret
  - Generate and download a private key.


### Step 2: Create an RDS database on AWS (Skip if using terraform)
Set the endpoint of the RDS database in the `.env` file.

### Step 3: Create an Elasticache Redis instance on AWS (Skip if using terraform)
Set the endpoint of the Elasticache Redis instance in the `.env` file.

### Step 4: Enable bedrock access in the AWS Account you plan to use
Request access to bedrock models

### Step 5: Start the docker services of Hatchet from inside the machine that will run Greptile
Fill in the `.env` file with the correct values. You can use `.env.example` as a template.

You can use the included script to start the docker services of Hatchet.
```sh
./start_hatchet.sh
```
Make sure to fill in the `.env` file with the correct value of `HATCHET_CLIENT_TOKEN` and `HATCHET_CLIENT_TLS_STRATEGY` from the hatchet services.

### Step 6: Start the docker services of Greptile
You can use the included script to start the docker services of Greptile.
```sh
./start_greptile.sh
```

### Step 7: Set up the webhook for the Github App
The webhook URL of the Github App must be set to point to the Github Service of the machine running greptile. 
For example, 
```sh
http://machine_ip:3010/webhook
```
