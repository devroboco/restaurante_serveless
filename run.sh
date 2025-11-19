#!/usr/bin/env bash
set -e

echo "Subindo LocalStack..."
docker compose up -d

echo "Aguardando LocalStack iniciar..."

echo "Criando a lambda Criar Pedido"
docker exec localstack bash /scripts/deploy-lambda-criadora.sh

echo "Criando a API GATEWAY"
docker exec localstack bash /scripts/deploy-apigateway.sh

echo "Criando o Dynamo"
docker exec localstack bash /scripts/deploy-dynamo.sh

echo "Criando a Fila (SQS)"
docker exec localstack bash /scripts/deploy-sqs.sh

echo "Criando a lambda Processar Pedido"
docker exec localstack bash /scripts/deploy-lambda-processadora.sh

echo "Criando o Bucket S3"
docker exec localstack bash /scripts/deploy-s3.sh

echo "Criando o SNS"
docker exec localstack bash /scripts/deploy-sns.sh