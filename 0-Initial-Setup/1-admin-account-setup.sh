#!/usr/bin/env bash

GCP_SERVICE_ACCOUNT=<INSERT_SERVICE_ACCOUNT>
GCP_SERVICE_ACCOUNT_KEY=<INSERT_SERIVE_ACCOUNT_KEY_PATH>
GCP_PROJECT_ID=<INSERT_GCP_PROJECT_ID>

# Activate GCP service account
gcloud auth activate-service-account "$GCP_SERVICE_ACCOUNT" \
  --key-file "$GCP_SERVICE_ACCOUNT_KEY" \
  --project "$GCP_PROJECT_ID"

# Configure Docker to use Google Container Registry
gcloud auth configure-docker gcr.io


