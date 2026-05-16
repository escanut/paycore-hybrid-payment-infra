#!/bin/bash


COMPOSE_FILE="./docker-compose.yml"
HTTPS_CONF="./nginx/conf.d/https.conf"
DOMAIN_NAME="victorojeje.xyz"
EMAIL="vicojeje25@gmail.com"





# Bring up Nginx with HTTP-only config
docker compose -f $COMPOSE_FILE up -d
