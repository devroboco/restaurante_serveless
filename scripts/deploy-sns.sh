#!/bin/bash

set -e

TOPIC_NAME="PedidosConcluidos"
REGION="us-east-1"

echo "Deploy SNS Topic"
echo ""

TOPIC_ARN=$(awslocal sns list-topics \
    --region "$REGION" \
    --query "Topics[?contains(TopicArn, '$TOPIC_NAME')].TopicArn" \
    --output text 2>/dev/null)

if [ -z "$TOPIC_ARN" ]; then
    TOPIC_ARN=$(awslocal sns create-topic \
        --name "$TOPIC_NAME" \
        --region "$REGION" \
        --query 'TopicArn' \
        --output text)
    echo "Tópico SNS criado: $TOPIC_ARN"
else
    echo "Tópico SNS já existe: $TOPIC_ARN"
fi

echo ""
echo "Deploy concluído!"
echo "Topic ARN: $TOPIC_ARN"