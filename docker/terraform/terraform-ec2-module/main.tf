########################################
# EC2 + SG with custom AMI
########################################

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-sg"
  description = "Security group for EC2 with custom AMI"
  vpc_id      = var.vpc_id

  # Allows SSH from anywhere (0.0.0.0/0). For production, tighten this!
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP on port 3000 - for the web application"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Open to the "world" (your vpc)
  }

  ingress {
    description = "HTTP on port 3010 - for github webhooks"
    from_port   = 3010
    to_port     = 3010
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Open to the "world" (your vpc)
  }

  ingress {
    description = "HTTP on port 8080 - for hatchet front end"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Open to the "world" (your vpc)
  }

  ingress {
    description = "HTTP on port 7077 - for hatchet"
    from_port   = 7077
    to_port     = 7077
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Open to the "world" (your vpc)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "this" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.this.id]
  key_name               = var.key_name

  iam_instance_profile = var.iam_instance_profile

  # Optionally associate a public IP (only works if subnet is in a public subnet)
  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    delete_on_termination = var.root_volume_delete_on_termination
    encrypted             = var.root_volume_encrypted
  }

  tags = {
    Name = "${var.name_prefix}-ec2"
  }
}
