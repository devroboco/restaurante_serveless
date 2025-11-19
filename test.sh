#!/usr/bin/env bash

# Modo debug (descomente para ativar)
# set -x

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funções auxiliares
print_header() {
    echo -e "\n${BLUE}=====================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=====================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

# Verificar dependências
command -v jq >/dev/null 2>&1 || { print_error "jq não está instalado. Instale com: sudo apt-get install jq"; exit 1; }
command -v curl >/dev/null 2>&1 || { print_error "curl não está instalado. Instale com: sudo apt-get install curl"; exit 1; }

# Verificar se LocalStack está rodando
print_header "Verificando LocalStack"
if ! docker ps | grep -q localstack; then
    print_error "LocalStack não está rodando!"
    echo "Execute: bash run.sh"
    exit 1
fi
print_success "LocalStack está rodando"

# Obter API Gateway URL
print_header "Obtendo URL do API Gateway"
API_ID=$(docker exec localstack awslocal apigateway get-rest-apis --query 'items[0].id' --output text 2>/dev/null)

if [ -z "$API_ID" ] || [ "$API_ID" == "None" ]; then
    print_error "API Gateway não encontrado!"
    exit 1
fi

API_URL="http://localhost:4566/restapis/$API_ID/prod/_user_request_/pedidos"
print_success "URL do API Gateway: $API_URL"

# Preparar dados do pedido de teste
print_header "Preparando dados do pedido de teste"
CLIENTE="Teste Automatizado $(date +%s)"
MESA=$((RANDOM % 20 + 1))
print_info "Cliente: $CLIENTE"
print_info "Mesa: $MESA"

# Criar pedido via API
print_header "Criando pedido via API Gateway"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d "{
    \"cliente\": \"$CLIENTE\",
    \"itens\": [\"Pizza Margherita\", \"Refrigerante\", \"Sobremesa\"],
    \"mesa\": $MESA
  }")

# Separar corpo da resposta e código HTTP
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

# Mostrar resposta formatada
echo "$HTTP_BODY" | jq . 2>/dev/null || echo "$HTTP_BODY"

# Verificar código HTTP
if [ "$HTTP_CODE" != "201" ] && [ "$HTTP_CODE" != "200" ]; then
    print_error "Falha ao criar pedido! HTTP Status: $HTTP_CODE"
    echo "Resposta completa: $HTTP_BODY"
    exit 1
fi

# Extrair ID do pedido
PEDIDO_ID=$(echo "$HTTP_BODY" | jq -r '.id // empty' 2>/dev/null)

if [ -z "$PEDIDO_ID" ] || [ "$PEDIDO_ID" = "null" ]; then
    print_error "Falha ao criar pedido!"
    echo "Resposta: $HTTP_BODY"

    # Tentar extrair mensagem de erro
    ERROR_MSG=$(echo "$HTTP_BODY" | jq -r '.mensagem // .message // empty' 2>/dev/null)
    if [ ! -z "$ERROR_MSG" ]; then
        echo "Erro: $ERROR_MSG"
    fi

    exit 1
fi

print_success "Pedido criado com ID: $PEDIDO_ID"

# Aguardar processamento
print_header "Aguardando processamento do pedido"
print_info "Aguardando 5 segundos para o processamento assíncrono..."
sleep 5

# Verificar se pedido foi salvo no DynamoDB
print_header "Verificando pedido no DynamoDB"
DYNAMO_ITEM=$(docker exec localstack awslocal dynamodb get-item \
  --table-name Pedidos \
  --key "{\"id\": {\"S\": \"$PEDIDO_ID\"}}" \
  --output json 2>/dev/null)

if [ -z "$DYNAMO_ITEM" ] || [ "$DYNAMO_ITEM" == "{}" ]; then
    print_error "Pedido não encontrado no DynamoDB!"
    exit 1
fi

DYNAMO_STATUS=$(echo "$DYNAMO_ITEM" | jq -r '.Item.status.S // empty')
DYNAMO_CLIENTE=$(echo "$DYNAMO_ITEM" | jq -r '.Item.cliente.S // empty')

print_success "Pedido encontrado no DynamoDB"
print_info "Status: $DYNAMO_STATUS"
print_info "Cliente: $DYNAMO_CLIENTE"

if [ "$DYNAMO_STATUS" != "PROCESSADO" ]; then
    print_error "Status esperado: PROCESSADO, Status atual: $DYNAMO_STATUS"
    print_info "O pedido pode ainda estar sendo processado. Aguardando mais 5 segundos..."
    sleep 5

    # Verificar novamente
    DYNAMO_ITEM=$(docker exec localstack awslocal dynamodb get-item \
      --table-name Pedidos \
      --key "{\"id\": {\"S\": \"$PEDIDO_ID\"}}" \
      --output json 2>/dev/null)

    DYNAMO_STATUS=$(echo "$DYNAMO_ITEM" | jq -r '.Item.status.S // empty')

    if [ "$DYNAMO_STATUS" != "PROCESSADO" ]; then
        print_error "Status ainda não foi atualizado para PROCESSADO"
    else
        print_success "Status atualizado para PROCESSADO"
    fi
fi

# Verificar se o PDF foi gerado no S3
print_header "Verificando PDF no S3"
PDF_KEY="pedidos/${PEDIDO_ID}.pdf"
S3_CHECK=$(docker exec localstack awslocal s3 ls "s3://pedidos-bucket/$PDF_KEY" 2>/dev/null || echo "")

if [ -z "$S3_CHECK" ]; then
    print_error "PDF não encontrado no S3!"
    print_info "Esperado: s3://pedidos-bucket/$PDF_KEY"

    # Listar todos os arquivos para debug
    print_info "Arquivos no bucket:"
    docker exec localstack awslocal s3 ls s3://pedidos-bucket/pedidos/ 2>/dev/null || print_error "Erro ao listar bucket"
else
    print_success "PDF encontrado no S3: $PDF_KEY"
    print_info "Detalhes: $S3_CHECK"

    # Baixar PDF para verificar (opcional)
    print_info "Baixando PDF para verificação..."
    docker exec localstack awslocal s3 cp "s3://pedidos-bucket/$PDF_KEY" "/tmp/test-pedido.pdf" 2>/dev/null

    if docker exec localstack test -f "/tmp/test-pedido.pdf"; then
        PDF_SIZE=$(docker exec localstack stat -f%z "/tmp/test-pedido.pdf" 2>/dev/null || docker exec localstack stat -c%s "/tmp/test-pedido.pdf" 2>/dev/null)
        print_success "PDF baixado com sucesso (${PDF_SIZE} bytes)"
        docker exec localstack rm "/tmp/test-pedido.pdf" 2>/dev/null
    fi
fi

# Verificar mensagens do SNS (verificar se o tópico existe e tem assinantes)
print_header "Verificando SNS"
TOPIC_ARN="arn:aws:sns:us-east-1:000000000000:PedidosConcluidos"

TOPIC_EXISTS=$(docker exec localstack awslocal sns list-topics --query "Topics[?TopicArn=='$TOPIC_ARN'].TopicArn" --output text 2>/dev/null || echo "")

if [ -z "$TOPIC_EXISTS" ]; then
    print_error "Tópico SNS não encontrado!"
else
    print_success "Tópico SNS configurado: $TOPIC_ARN"

    # Verificar assinantes
    SUBSCRIPTIONS=$(docker exec localstack awslocal sns list-subscriptions-by-topic --topic-arn "$TOPIC_ARN" --query 'Subscriptions | length(@)' --output text 2>/dev/null)

    if [ "$SUBSCRIPTIONS" == "0" ]; then
        print_info "Nenhum assinante configurado no tópico SNS"
        print_info "Para testar notificações, adicione um assinante (email, SMS, etc.)"
    else
        print_success "Tópico possui $SUBSCRIPTIONS assinante(s)"
    fi
fi

# Verificar SQS
print_header "Verificando SQS"
QUEUE_URL="http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/FilaPedidos"

QUEUE_ATTRS=$(docker exec localstack awslocal sqs get-queue-attributes \
  --queue-url "$QUEUE_URL" \
  --attribute-names All \
  --output json 2>/dev/null || echo "{}")

if [ "$QUEUE_ATTRS" == "{}" ]; then
    print_error "Fila SQS não encontrada!"
else
    print_success "Fila SQS configurada"

    MSGS_AVAILABLE=$(echo "$QUEUE_ATTRS" | jq -r '.Attributes.ApproximateNumberOfMessages // "0"')
    MSGS_IN_FLIGHT=$(echo "$QUEUE_ATTRS" | jq -r '.Attributes.ApproximateNumberOfMessagesNotVisible // "0"')

    print_info "Mensagens disponíveis: $MSGS_AVAILABLE"
    print_info "Mensagens em processamento: $MSGS_IN_FLIGHT"

    if [ "$MSGS_AVAILABLE" != "0" ]; then
        print_error "Existem mensagens não processadas na fila!"
    fi
fi

# Verificar Lambdas
print_header "Verificando Lambdas"

# Lambda CriarPedidos
LAMBDA_CRIAR=$(docker exec localstack awslocal lambda get-function --function-name criarPedidos --query 'Configuration.FunctionName' --output text 2>/dev/null || echo "")

if [ -z "$LAMBDA_CRIAR" ]; then
    print_error "Lambda criarPedidos não encontrada!"
else
    print_success "Lambda criarPedidos configurada"
fi

# Lambda ProcessarPedidos
LAMBDA_PROCESSAR=$(docker exec localstack awslocal lambda get-function --function-name processarPedidos --query 'Configuration.FunctionName' --output text 2>/dev/null || echo "")

if [ -z "$LAMBDA_PROCESSAR" ]; then
    print_error "Lambda processarPedidos não encontrada!"
else
    print_success "Lambda processarPedidos configurada"

    # Verificar event source mapping
    MAPPINGS=$(docker exec localstack awslocal lambda list-event-source-mappings \
      --function-name processarPedidos \
      --query 'EventSourceMappings | length(@)' \
      --output text 2>/dev/null || echo "0")

    if [ "$MAPPINGS" == "0" ]; then
        print_error "Event source mapping não configurado para processarPedidos!"
    else
        print_success "Event source mapping configurado ($MAPPINGS mapeamento(s))"
    fi
fi

# Resumo final
print_header "Resumo dos Testes"

TOTAL_TESTS=8
PASSED_TESTS=0

# Contar sucessos
[ ! -z "$API_ID" ] && PASSED_TESTS=$((PASSED_TESTS + 1))
[ ! -z "$PEDIDO_ID" ] && PASSED_TESTS=$((PASSED_TESTS + 1))
[ ! -z "$DYNAMO_ITEM" ] && PASSED_TESTS=$((PASSED_TESTS + 1))
[ "$DYNAMO_STATUS" == "PROCESSADO" ] && PASSED_TESTS=$((PASSED_TESTS + 1))
[ ! -z "$S3_CHECK" ] && PASSED_TESTS=$((PASSED_TESTS + 1))
[ ! -z "$TOPIC_EXISTS" ] && PASSED_TESTS=$((PASSED_TESTS + 1))
[ "$QUEUE_ATTRS" != "{}" ] && PASSED_TESTS=$((PASSED_TESTS + 1))
[ ! -z "$LAMBDA_CRIAR" ] && [ ! -z "$LAMBDA_PROCESSAR" ] && PASSED_TESTS=$((PASSED_TESTS + 1))

if [ $PASSED_TESTS -eq $TOTAL_TESTS ]; then
    print_success "Todos os testes passaram! ($PASSED_TESTS/$TOTAL_TESTS)"
    echo -e "\n${GREEN}🎉 Sistema funcionando perfeitamente!${NC}\n"
    exit 0
else
    print_error "Alguns testes falharam ($PASSED_TESTS/$TOTAL_TESTS)"
    echo -e "\n${RED}⚠️  Verifique os erros acima${NC}\n"
    exit 1
fi
