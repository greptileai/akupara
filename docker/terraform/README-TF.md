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


The following variables should be filled using the values we got from the terraform output.

```bash
DB_HOST
REDIS_HOST
APP_URL
```

The `DB_PASSWORD` should be the password we set for the RDS database in the `terraform.tfvars` file.

The rest of the variables should be filled based on the `common.env.example` file. You will notice fields for BOXYHQ/SAML that do not need to be changed if you do not want to set up SSO. If you do want to set up SSO, refer to `docker/docs/SSO.md` for more information. 

### Step 4: Start the services

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
greptile_llmproxy_service
greptile_jobs_service
hatchet-api
hatchet-engine
hatchet-frontend
postgres
rabbitmq
```

You can now access the greptile frontend at `http://<ec2-public-ip>:3000`!

