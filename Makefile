.PHONY: fmt-tf fmt-tf-check test-tf test-tf-modules test-tf-stacks

# Terraform formatting
TF_MODULES := $(wildcard terraform/modules/*/*)
TF_STACKS := $(wildcard terraform/stacks/*)

# Format all Terraform files
fmt-tf:
	terraform fmt -recursive terraform/

# Check Terraform formatting (CI-friendly, fails if unformatted)
fmt-tf-check:
	terraform fmt -recursive -check terraform/

# Run all Terraform tests (modules + stacks)
test-tf: test-tf-modules test-tf-stacks

# Test all modules
test-tf-modules:
	@for dir in $(TF_MODULES); do \
		echo "=== Testing $$dir ==="; \
		terraform -chdir=$$dir init -backend=false -input=false && \
		terraform -chdir=$$dir test || exit 1; \
	done

# Test all stacks
test-tf-stacks:
	@for dir in $(TF_STACKS); do \
		echo "=== Testing $$dir ==="; \
		terraform -chdir=$$dir init -backend=false -input=false && \
		terraform -chdir=$$dir test || exit 1; \
	done

# Test a specific module: make test-tf-module PROVIDER=aws MODULE=vpc
test-tf-module:
	terraform -chdir=terraform/modules/$(PROVIDER)/$(MODULE) init -backend=false -input=false
	terraform -chdir=terraform/modules/$(PROVIDER)/$(MODULE) test

# Test a specific stack: make test-tf-stack STACK=aws-ec2
test-tf-stack:
	terraform -chdir=terraform/stacks/$(STACK) init -backend=false -input=false
	terraform -chdir=terraform/stacks/$(STACK) test
