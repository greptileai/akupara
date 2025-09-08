## Setting up Greptile with Terraform and Docker Compose

### Step 1: Fill up a `terraform.tfvars` file based on the `terraform.tfvars.example` file.

`vpc_id`: This should be the VPC ID that all the greptile infrastructure will be deployed to. It can be a new VPC or an existing one. It must have at least 3 subnets which will be used below.

`ec2_subnet_id`: This should be the subnet ID (on the provided VPC) that the EC2 instance will be deployed to. It can be a private subnet but we recommend using a public subnet (with appropriate ingress rules).

`private_subnets`: This should be the subnet IDs that the greptile database and cache will be deployed to. These should be private subnets.

`db_password`: This should be a 32 character (no special characters) long password for the RDS database.

`ami_id`: This should be the AMI ID of the Greptile image. This is a private `AMI` and your AWS account ID must be whitelisted to access it. Contact Greptile support for this. 

`key_name`: This should be the name of the key pair that will be used to ssh into the EC2 instance.

- Create a key pair in AWS 
- Store the private key in your local machine at `~/.ssh/<key-name>.pem`,
- Give it the permissions: `chmod 400 ~/.ssh/<key-name>.pem`

`instance_type`: This should be the instance type that will be used for the EC2 instance. We recommend using a `t3.2xlarge` for most use cases.


### Step 2: Run the following commands to launch the infrastructure.
```bash
terraform init
terraform plan
terraform apply
```
The infrastructure usually takes about 10 minutes to deploy.
Make sure to note down the outputs of the terraform apply command. These will be used to configure the environment variables in the EC2.


### Step 3: Configuring the EC2.
First SSH into the EC2 instance. The public IP of the EC2 instance will be displayed in the terraform output from the previous step. 
```bash
ssh -i ~/.ssh/<key-name>.pem ec2-user@<ec2-public-ip>
```

Go to the akupara directory 
```bash
cd /opt/akupara/docker/
```


**Note**: The `Caddyfile` is used to reverse proxy the hatchet frontend to the EC2 instance. You can use this to reverse proxy custom domain names to the EC2 instance as well. See `/docker/docs/CustomDomains.md` for more details. 

Create a `common.env` file based on the template provided by `common.env.example` file. For this step - you will need to register a new **Github App**.

### Step 4: Register a GitHub App.
1. Go to your GitHub organization settings > Developer Settings > GitHub Apps > New GitHub App. If you have problems finding it, refer to the [official guide](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app#registering-a-github-app)
2. Set the following values:
    - GitHub App name: `Greptile` (or your preferred name)
    - Homepage URL: You can just write `https://greptile.com`
    - Callback URL: `http://<ip_address>:3000/api/auth/callback/github-enterprise` (for self-hosted) or `http://<ip_address>:3000/api/auth/callback/github` (for cloud github)
    - Setup URL: `http://<ip_address>:3000/auth/github`
      - Make sure to select "Redirect on update".
    - Webhook URL: `http://<ip_address>:3010/webhook`
    - Webhook secret: Generate a secure random string
      - On unix environments, you can use `openssl rand -hex 32` to generate the secure random string.
3. Under "Permissions", ensure the following are enabled:
    - Repository permissions:
      - Contents: `Read-only`
      - Metadata: `Read-only`
      - Issues: `Read & Write`
      - Checks: `Read & Write`
      - Pull requests: `Read & Write`
      - Commit statuses: `Read & Write`
    - Organization permissions:  
      - Members: `Read-only`
    - Account permissions
      - Email Addresses: `Read-only` (Only required if using this GitHub App to sign in to Greptile (sign in with GitHub))
4. Under "Where can this GitHub App be installed?" make sure to select `Any account`
5. Click "Create GitHub App"
6. After having created the GitHub App, click on "General" in the left menu bar.
    - Create a Client Secret by clicking on "Generate a new client secret"
      - Ensure to make a copy of this client secret and store it for later
    - Scroll down to "Private keys" and click on "Generate a private key".
      - This will download a file containing a private key required further below.
7. Click on "Permissions & events" in the left menu bar.
    - Select the following events:
      - Issues
      - Issue Comment
      - Pull Request
      - Pull Request Review
      - Pull Request Review Comment
      - Pull Request Review Thread
8. Click on "Optional features" in the left menu bar.
    - Ensure to `Opt-out` of "User-to-server token expiration"
9. Gather the following values below to populate the relevant fields in the `common.env` file:
    - App ID
    - App URL 
    - App Name 
    - Client ID
    - Client secret (generated above)
    - Webhook secret (generated above)
    - Private key (generated above)

The following variables should be filled using the values we got from the terraform output.

```bash
DB_HOST
REDIS_HOST
APP_URL
```

The `DB_PASSWORD` should be the password we set for the RDS database in the `terraform.tfvars` file.

The rest of the variables should be filled based on the `common.env.example` file. You will notice fields for BOXYHQ/SAML that do not need to be changed if you do not want to set up SSO. If you do want to set up SSO, refer to `docker/docs/SSO.md` for more information. 

### Step 5: Start the services

First start the hatchet services
```bash
./start-hatchet.sh
```

Verify that the hatchet service is running by logging into the hatchet frontend which is available at `http://<ec2-public-ip>:8080`. The default login credentials are 
```
Email: admin@example.com
Password: Admin123!!
```

**Note**: you may need to modify the ingress rules of the security group of the EC2 instance to allow HTTP and HTTPS traffic. Our terraform defaults to only allow SSH traffic. 

Once the hatchet services are running, login to Hatchet using the default credentials from above and go to Settings > General > API Tokens to create an API token. Make sure to add this API token to the common.env file.

Then start the greptile services
```bash
./start-greptile.sh
```

Verify that all the services are running with 
```
docker-compose ps
```

You should see the following services running:
```
greptile_api_service
greptile_auth_service
greptile_indexer_chunker
greptile_indexer_summarizer
greptile_web_service
greptile_reviews_service
greptile_webhook_service
greptile_jobs_service
hatchet-api
hatchet-engine
hatchet-frontend
postgres
rabbitmq
```

You can now access the greptile frontend at `http://<ec2-public-ip>:3000`!

