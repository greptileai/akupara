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

  # Optionally associate a public IP (only works if subnet is in a public subnet)
  associate_public_ip_address = true

  tags = {
    Name = "${var.name_prefix}-ec2"
  }
}

