#!/bin/bash
set -e

COMPOSE_FILE="./docker-compose.yml"
HTTPS_CONF="./nginx/conf.d/https.conf"
DOMAIN_NAME="victorojeje.xyz"
EMAIL="vicojeje25@gmail.com"

DB_SECRET=$( aws secretsmanager get-secret-value \
    --secret-id paycore/internal/db \
    --region us-east-1 \
    --query SecretString \
    --output text)

APP_SECRET=$(aws secretsmanager get-secret-value \
    --secret-id paycore/internal/config \
    --region us-east-1 \
    --query SecretString \
    --output text)


    


export DB_PASSWORD=$(echo $DB_SECRET | jq -r .db_password)
export DB_USERNAME=$(echo $DB_SECRET | jq -r .db_username)
export CLOUDFLARE_TOKEN=$(echo $APP_SECRET | jq -r .cloudflare_token)
export SECRET_KEY=$(echo $APP_SECRET | jq -r .secret_key)
export CALLBACK_API_KEY=$(echo $APP_SECRET | jq -r .callback_api_key)
export AWS_REGION=us-east-1
export SQS_QUEUE_URL=$(aws sqs get-queue-url --queue-name paycore-transactions --region us-east-1 --query QueueUrl --output text)
export AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)


# Bring up Nginx with HTTP-only config
docker compose -f $COMPOSE_FILE up --build -d --remove-orphans