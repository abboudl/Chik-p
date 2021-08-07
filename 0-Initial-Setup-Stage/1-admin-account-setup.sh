#!/usr/bin/env bash

# Read configuration from global config file
source config.sh

# Check to see if env variables set
variables=(GCP_SERVICE_ACCOUNT GCP_SERVICE_ACCOUNT_KEY GCP_PROJECT_ID) 

for var in $variables; do
  if echo ${!var} | grep 'INSERT' &> /dev/null; then
    echo "Please set the $var variable in the .env file"
    exit 1
  fi
done

# Activate GCP service account
gcloud auth activate-service-account "$GCP_SERVICE_ACCOUNT" \
  --key-file "$GCP_SERVICE_ACCOUNT_KEY" \
  --project "$GCP_PROJECT_ID"

# Configure Docker to use Google Container Registry
gcloud auth configure-docker gcr.io
