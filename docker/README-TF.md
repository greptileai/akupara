## Setting up Greptile Infrastructure with Terraform

### Step 1: Fill up a `terraform.tfvars` file based on the `terraform.tfvars.example` file.

Create a key pair in AWS 
- Store the private key in your local machine at `~/.ssh/<key-name>.pem`,
- Give it the permissions: `chmod 400 ~/.ssh/<key-name>.pem`
- Use the name of the key pair in the `terraform.tfvars` file.

### Step 2: Run the following commands to launch the infrastructure.
```bash
terraform init
terraform plan
terraform apply
```

### Step 3: ssh into the EC2 instance and start the Greptile services.
```bash
ssh -i ~/.ssh/<key-name>.pem ec2-user@<ec2-public-ip>
```

Continue with the [Setting up Greptile using Docker Compose](../docker/README.md) section.
