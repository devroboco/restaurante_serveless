#!/bin/bash

set -e

echo "Deploy Lambda"

FUNCTION_NAME="criarPedidos"
LAMBDA_DIR="/lambdas/criarPedido"
ZIP_FILE="/tmp/criar-pedido.zip"

echo "Criando ZIP..."
cd "$LAMBDA_DIR"
zip -r "$ZIP_FILE" . > /dev/null 2>&1
echo "ZIP criado: $ZIP_FILE"
echo ""

echo "Verificando se Lambda existe..."
if awslocal lambda get-function --function-name "$FUNCTION_NAME" > /dev/null 2>&1; then
    echo "Lambda já existe, atualizando código..."
    awslocal lambda update-function-code \
        --function-name "$FUNCTION_NAME" \
        --zip-file "fileb://$ZIP_FILE" > /dev/null
    echo "Lambda atualizada!"
else
    echo "Criando nova Lambda..."
    awslocal lambda create-function \
        --function-name "$FUNCTION_NAME" \
        --runtime nodejs20.x \
        --role arn:aws:iam::000000000000:role/lambda-role \
        --handler index.handler \
        --zip-file "fileb://$ZIP_FILE" > /dev/null
    echo "Lambda criada!"
fi