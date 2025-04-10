# Setting up Greptile with Terraform and Docker Compose
## Deployment Steps

The deployment process involves two main phases:

1.
2.  **Infrastructure Provisioning (Terraform):** Use Terraform to create the necessary AWS resources.
3.  **EC2 Environment Configuration and Deployment:** SSH connect into the EC2 instance to create the .env file & run the sh scripts

## 1. AWS CLI
Install [latest AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) and [configure credentials profile](https://docs.aws.amazon.com/cli/v1/userguide/cli-configure-files.html)

## 2. Infrastructure Provisioning (Terraform)

### 2.1. Configure Terraform Variables

* Navigate to the `docker/terraform` directory:

    ```bash
    cd docker/terraform
    ```

* Create a `terraform.tfvars` file by copying the provided example:

    ```bash
    cp terraform.tfvars.example terraform.tfvars
    ```

* Edit the `terraform.tfvars` file to provide the necessary values.

    **Variable Details:**

    * `vpc_id` (string): The ID of the VPC where the Greptile infrastructure will be deployed. This can be an existing VPC or one you create specifically for Greptile. Ensure it has at least three available subnets.
    * `ec2_subnet_id` (string): The subnet ID within the specified `vpc_id` where the EC2 instance will be launched. While a private subnet can be used, a public subnet with appropriate ingress rules is recommended for initial setup and accessibility.
    * `private_subnets` (list(string)): A list of subnet IDs within the `vpc_id` where the RDS database and ElastiCache cluster will be deployed. These *must* be private subnets for security reasons.
    * `db_password` (string, sensitive): A strong password (at least 32 characters, alphanumeric only) for the RDS Postgres database. This password is used by the Greptile application to connect to the database.
    * `ami_id` (string): The AMI ID of the pre-built Greptile EC2 image. Access to this private AMI is required. Contact Greptile support to request access and obtain the correct AMI ID for your region.
    * `key_name` (string): The name of an existing EC2 key pair that will be used to access the EC2 instance via SSH.
        * **Important:**
            * Create an EC2 key pair in the same region as your EC2 if you don't have one.
            * Store the corresponding private key file (`.pem`) on your local machine in the `~/.ssh/` directory (e.g., `~/.ssh/greptile-key.pem`).
            * Set the correct permissions on the private key file:
                ```bash
                chmod 400 ~/.ssh/greptile-key.pem
                ```
    * `instance_type` (string, optional): The EC2 instance type to use. We recommend using the default `t3.2xlarge` for most use cases.
    * `aws_region` (string): The AWS region of the Greptile AMI
    * `aws_profile` (string): Your AWS credentials profile

### 2.2. Launch the Infrastructure

* Initialize Terraform:

    ```bash
    terraform init
    ```

* Plan the deployment:

    ```bash
    terraform plan
    ```

    Review the plan carefully to understand the resources that will be created or modified.

* Apply the configuration to launch the infrastructure:

    ```bash
    terraform apply
    ```

    This process typically takes about 10-15 minutes.

* **Important:** After the `terraform apply` command completes, carefully note the output values. You will need these (especially the EC2 instance's public IP address) in the next steps.

## 3. EC2 Configuration

### 3.1. Connect to the EC2 Instance

* Use SSH to connect to the EC2 instance. Replace `<key-name>` and `<ec2-public-ip>` with the appropriate values from your Terraform output and key pair file:

    ```bash
    ssh -i ~/.ssh/<key-name>.pem ec2-user@<ec2-public-ip>
    ```

### 3.2. Configure Application Files

* Navigate to the Docker Compose directory:

    ```bash
    cd /opt/akupara/docker/
    ```

    Edit the `Caddyfile` to point to the EC2 instance.
    ```bash
    http://<ec2-public-ip>:8080 {
        handle /api/* {
            reverse_proxy hatchet-api:8080
        }

        handle /* {
            reverse_proxy hatchet-frontend:80
        }
    }
    ```

**Note**: The `Caddyfile` is used to reverse proxy the hatchet frontend to the EC2 instance. You can use this to reverse proxy custom domain names to the EC2 instance as well. See `/docker/docs/CustomDomains.md` for more details. 

* **Create and Configure `.env` File:**

    * Create a `.env` file within the EC2 and configure based off `.env.example`:

        ```bash
        sudo cp .env.example .env
        sudo nano .env
        ```

    * Populate the `.env` file with the required environment variables.

        * **GitHub App Configuration:**
            * You'll need to create a GitHub App to enable GitHub integration.
            * Follow these steps on GitHub:
                1.  Go to your GitHub organization settings > Developer Settings > GitHub Apps > New GitHub App
                2.  Set the following:
                    * GitHub App name: `Greptile` (or a name of your choice)
                    * Homepage URL: `https://greptile.com` (or your actual homepage)
                    * Callback URL:
                        * For GitHub Enterprise Server: `http://<ec2-public-ip>:3000/api/auth/callback/github-enterprise`
                        * For GitHub.com: `http://<ec2-public-ip>:3000/api/auth/callback/github`
                        * Replace `<ec2-public-ip>` with the EC2 instance's public IP address.
                    * Setup URL: `http://<ec2-public-ip>:3000/auth/github` (Replace `<ec2-public-ip>`)
                    * Select "Redirect on update"
                    * Webhook URL: `http://<ec2-public-ip>:3010/webhook` (Replace `<ec2-public-ip>`)
                    * Webhook secret: Generate a strong, random string and store it securely.

                3.  Permissions: Set the following permissions for your GitHub App:
                    * Repository:
                        * Contents: Read-only
                        * Metadata: Read-only
                        * Issues: Read & Write
                        * Pull requests: Read & Write
                        * Webhooks: Read & Write
                    * Organization:
                        * Members: Read-only
                        * Events: Read-only
                    * Account Permissions:
                        * Email Addresses: Read-only
                4.  Subscribe to Events:
                    * Issues
                    * Issue Comment
                    * Pull Request
                    * Pull Request Review
                    * Pull Request Review Comment
                    * Pull Request Review Thread

                5.  **Important:** In the GitHub App settings, under "Optional Features," make sure to **Opt-Out** of "User-to-server token expiration."

                6.  After creating the GitHub App, use the provided values to fill in the corresponding fields in your `.env` file:
                    * `GITHUB_APP_ID`
                    * `GITHUB_APP_URL`
                    * `GITHUB_APP_NAME`
                    * `GITHUB_CLIENT_ID`
                    * `GITHUB_CLIENT_SECRET`
                    * `GITHUB_WEBHOOK_SECRET`
                    * Download the generated private key and save it securely. You'll need to add its content to the `.env` file as well.

        * **Terraform Output Variables:**
            * Use the values from your Terraform output to fill in these variables in the `.env` file:
                * `DB_HOST`
                * `REDIS_HOST`
        * **RDS Password:**
            * Set the `DB_PASSWORD` variable to the password you configured in your `terraform.tfvars` file.
        * **Other Variables:**
            * Fill in the remaining variables based on the `.env.example` file.
            * **SSO (Optional):** The `.env.example` file may contain variables related to BoxyHQ/SAML for Single Sign-On (SSO). If you do not need SSO, you can leave these at their default values. If you want to configure SSO, refer to the documentation in `/docker/docs/SSO.md`.

### 3.3. Start the Services

* Start the Hatchet services:

    ```bash
    sudo ./start_hatchet.sh
    ```

* Verify that the Hatchet service is running by accessing the Hatchet frontend in your browser:

    ```
    http://<ec2-public-ip>:8080
    ```

    * The default login credentials are:
        * Email: `admin@example.com`
        * Password: `Admin123!!`
    * **Note:** You might need to adjust the EC2 instance's security group ingress rules to allow HTTP (port 80) and HTTPS (port 443) traffic. By default, the Terraform configuration may only allow SSH (port 22).

* **Important:** After confirming that the Hatchet services are running, copy the contents of the `.env.hatchet` file to the `.env` file. This is crucial because the `HATCHET_CLIENT_TOKEN` can change when Hatchet services restart.

* Start the Greptile services:

    ```bash
    sudo ./start_greptile.sh
    ```

* Verify that all services are running:

    ```bash
    sudo docker-compose ps
    ```

    * You should see the following services in the output:

        ```
        greptile_api_service
        greptile_auth_service
        greptile_github_service
        greptile_indexer_chunker
        greptile_indexer_summarizer
        greptile_query_service
        greptile_web_service
        hatchet-api
        hatchet-engine
        hatchet-frontend
        postgres
        rabbitmq
        ```

* Access the Greptile frontend in your browser:

    ```
    http://<ec2-public-ip>:3000
    ```

