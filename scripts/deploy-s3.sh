#!/bin/bash

set -e

BUCKET_NAME="pedidos-bucket"

echo "Deploy S3 Bucket"
echo ""

if ! awslocal s3 ls "s3://$BUCKET_NAME" 2>/dev/null; then
    awslocal s3 mb "s3://$BUCKET_NAME" --region us-east-1
    echo "Bucket criado"
else
    echo "Bucket já existe"
fi

echo ""
echo "Deploy concluído!"