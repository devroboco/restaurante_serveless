#!/usr/bin/env bash
set -e

echo "Subindo LocalStack..."
docker compose up -d

echo "Aguardando LocalStack iniciar..."

echo "Criando a lambda Criar Pedido"
docker exec localstack bash /scripts/deploy-lambda.sh