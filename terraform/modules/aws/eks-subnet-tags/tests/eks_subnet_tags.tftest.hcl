mock_provider "aws" {}

variables {
  cluster_name      = "test-cluster"
  public_subnet_ids = ["subnet-public-1", "subnet-public-2"]
  private_subnet_ids = [
    "subnet-private-1",
    "subnet-private-2",
  ]
}

run "creates_expected_tag_resources" {
  command = plan

  # (public + private) cluster tags + role tags per subnet:
  # (2 + 2) cluster tags + 2 public role tags + 2 private role tags = 8
  assert {
    condition     = length(aws_ec2_tag.cluster) == 4
    error_message = "Should create one cluster tag per subnet (expected 4 for 2 public + 2 private)."
  }

  assert {
    condition     = length(aws_ec2_tag.public_role) == 2
    error_message = "Should create one public role tag per public subnet (expected 2)."
  }

  assert {
    condition     = length(aws_ec2_tag.private_role) == 2
    error_message = "Should create one private role tag per private subnet (expected 2)."
  }

  assert {
    condition     = (length(aws_ec2_tag.cluster) + length(aws_ec2_tag.public_role) + length(aws_ec2_tag.private_role)) == 8
    error_message = "Should create one aws_ec2_tag per {subnet_id, tag_key} (expected 8 tags for 2 public + 2 private)."
  }
}

run "creates_required_tag_keys" {
  command = plan

  assert {
    condition = alltrue([
      for _, t in aws_ec2_tag.public_role :
      t.key == "kubernetes.io/role/elb" && t.value == "1"
    ])
    error_message = "Should tag public subnets with kubernetes.io/role/elb = 1."
  }

  assert {
    condition = alltrue([
      for _, t in aws_ec2_tag.private_role :
      t.key == "kubernetes.io/role/internal-elb" && t.value == "1"
    ])
    error_message = "Should tag private subnets with kubernetes.io/role/internal-elb = 1."
  }

  assert {
    condition = alltrue([
      for _, t in aws_ec2_tag.cluster :
      t.key == "kubernetes.io/cluster/test-cluster" && t.value == "shared"
    ])
    error_message = "Should tag all subnets with kubernetes.io/cluster/<cluster_name> = shared."
  }
}

run "fails_when_subnet_ids_overlap" {
  command = plan

  variables {
    cluster_name       = "test-cluster"
    public_subnet_ids  = ["subnet-1"]
    private_subnet_ids = ["subnet-1"]
  }

  expect_failures = [var.public_subnet_ids]
}
