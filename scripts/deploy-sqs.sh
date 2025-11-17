#!/bin/bash

QUEUE_URL=$(awslocal sqs create-queue \
    --queue-name FilaPedidos \
    --region us-east-1 \
    --output text \
    --query 'QueueUrl' 2>/dev/null)

if [ -n "$QUEUE_URL" ]; then
    echo "Fila FilaPedidos criada com sucesso!"
    echo "Queue URL: $QUEUE_URL"
else
    echo "Erro ao criar a fila FilaPedidos"
    exit 1
fi

awslocal sqs get-queue-attributes \
    --queue-url $QUEUE_URL \
    --attribute-names All \
    --region us-east-1 > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "Fila verificada e funcionando corretamente!"
else
    echo "Erro ao verificar a fila"
    exit 1
fi