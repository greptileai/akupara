#!/bin/bash
# TODO: deprecate this script
# Get AWS credentials from default profile (or specified profile)
AWS_PROFILE=${AWS_PROFILE:-default}
ACCESS_KEY=$(aws configure get aws_access_key_id --profile $AWS_PROFILE)
SECRET_KEY=$(aws configure get aws_secret_access_key --profile $AWS_PROFILE)

# Create the secret
kubectl create secret generic awssm-secret \
  --from-literal=access-key="$ACCESS_KEY" \
  --from-literal=secret-access-key="$SECRET_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "AWS credentials secret 'awssm-secret' created/updated"