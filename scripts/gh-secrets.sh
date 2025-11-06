#!/bin/bash

# Path to your .env file
ENV_FILE=".env"
REPO="diesl-org/diesl-infra"  # Replace with your repo

# Read and parse the .env file
jq -r 'to_entries | .[] | "\(.key)=\(.value)"' $ENV_FILE | while IFS='=' read -r key value; do
  echo "Setting secret: $key"
  gh secret set "$key" --repo "$REPO" --body "$value"
done

