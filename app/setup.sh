#!/bin/bash
set -e

COMPOSE_FILE="./docker-compose.yml"
HTTPS_CONF="./nginx/conf.d/https.conf"
DOMAIN_NAME="victorojeje.xyz"
EMAIL="vicojeje25@gmail.com"

DB_SECRET=$(aws secretsmanager get-secret-value \
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


# Bring up Nginx with HTTP-only config
docker compose -f $COMPOSE_FILE up -d --remoce-orphans
