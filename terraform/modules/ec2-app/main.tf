locals {
  default_ingress_rules = [
    {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "App HTTP"
      from_port   = 3000
      to_port     = 3000
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "GitHub Webhooks"
      from_port   = 3010
      to_port     = 3010
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "Hatchet UI"
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "Hatchet Service"
      from_port   = 7077
      to_port     = 7077
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  ingress_rules = coalesce(var.ingress_rules, local.default_ingress_rules)
}

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-ec2-sg"
  description = "Security group for Greptile EC2 deployment"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = local.ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    Name = "${var.name_prefix}-ec2-sg"
  }, var.tags)
}

resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.this.id]
  key_name                    = var.key_name
  iam_instance_profile        = var.iam_instance_profile
  associate_public_ip_address = var.associate_public_ip

  tags = merge({
    Name = "${var.name_prefix}-ec2"
  }, var.tags)
}
