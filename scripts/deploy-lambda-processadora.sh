#!/bin/bash

set -e

FUNCTION_NAME="processarPedidos"
LAMBDA_DIR="/lambdas/ProcessarPedido"
ZIP_FILE="/tmp/processar-pedido.zip"
QUEUE_NAME="FilaPedidos"

echo "Deploy Lambda Processadora de Pedidos"
echo ""

cd "$LAMBDA_DIR"
zip -r "$ZIP_FILE" . > /dev/null 2>&1

QUEUE_ARN=$(awslocal sqs get-queue-attributes \
    --queue-url "http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/$QUEUE_NAME" \
    --attribute-names QueueArn \
    --region us-east-1 \
    --query 'Attributes.QueueArn' \
    --output text 2>/dev/null)

if [ -z "$QUEUE_ARN" ]; then
    echo "Erro: Fila $QUEUE_NAME não encontrada"
    exit 1
fi

if awslocal lambda get-function --function-name "$FUNCTION_NAME" > /dev/null 2>&1; then
    awslocal lambda update-function-code \
        --function-name "$FUNCTION_NAME" \
        --zip-file "fileb://$ZIP_FILE" > /dev/null
    echo "Lambda atualizada"
else
    awslocal lambda create-function \
        --function-name "$FUNCTION_NAME" \
        --runtime nodejs20.x \
        --role arn:aws:iam::000000000000:role/lambda-role \
        --handler index.handler \
        --zip-file "fileb://$ZIP_FILE" \
        --environment "Variables={LOCALSTACK_ENDPOINT=http://localstack:4566,AWS_ENDPOINT_URL=http://localstack:4566}" > /dev/null
    echo "Lambda criada"
fi

sleep 3
echo "Atualizando variáveis de ambiente..."
awslocal lambda update-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --environment "Variables={LOCALSTACK_ENDPOINT=http://localstack:4566,AWS_ENDPOINT_URL=http://localstack:4566}" > /dev/null
echo "Variáveis de ambiente atualizadas!"

EXISTING_MAPPINGS=$(awslocal lambda list-event-source-mappings \
    --function-name "$FUNCTION_NAME" \
    --region us-east-1 \
    --query 'EventSourceMappings[*].UUID' \
    --output text 2>/dev/null)

if [ -n "$EXISTING_MAPPINGS" ] && [ "$EXISTING_MAPPINGS" != "None" ]; then
    for UUID in $EXISTING_MAPPINGS; do
        awslocal lambda delete-event-source-mapping \
            --uuid "$UUID" \
            --region us-east-1 > /dev/null 2>&1 || true
    done
    sleep 2
fi

MAPPING_RESULT=$(awslocal lambda create-event-source-mapping \
    --function-name "$FUNCTION_NAME" \
    --event-source-arn "$QUEUE_ARN" \
    --region us-east-1 \
    --batch-size 1 \
    --maximum-batching-window-in-seconds 0 \
    --enabled \
    2>&1)

if [ $? -eq 0 ]; then
    echo "Event source mapping configurado"
else
    echo "Aviso: $MAPPING_RESULT"
fi

echo ""
echo "Deploy concluído!"