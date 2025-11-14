#!/bin/bash

# Criar tabela Pedidos no DynamoDB Local
awslocal dynamodb create-table \
    --table-name Pedidos \
    --attribute-definitions \
        AttributeName=id,AttributeType=S \
    --key-schema \
        AttributeName=id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1 > /dev/null 2>&1

echo "Tabela Pedidos criada com sucesso!" 

# Verificar se a tabela foi criada
awslocal dynamodb describe-table --table-name Pedidos --region us-east-1 > /dev/null 2>&1