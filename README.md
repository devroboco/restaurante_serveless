# Sistema de Pedidos Serverless

Sistema completo de gerenciamento de pedidos usando AWS Serverless (LocalStack) com Lambda, API Gateway, DynamoDB, SQS, S3 e SNS.

### Pré-requisitos
- Docker e Docker Compose
- jq (para testes)
### Subir o ambiente

```bash
./run.sh
```

Este comando irá:
- Iniciar o LocalStack
- Criar as Lambdas (CriarPedido e ProcessarPedido)
- Configurar o API Gateway
- Criar tabela DynamoDB
- Configurar fila SQS
- Criar bucket S3
- Configurar tópico SNS

### Executar testes automatizados

```bash
./test.sh
```

O script de testes irá:
- Criar um pedido via API
- Validar salvamento no DynamoDB
- Verificar processamento assíncrono
- Confirmar geração de PDF no S3
- Validar configuração do SNS e SQS
- Mostrar resumo completo dos testes

## Arquitetura

<img width="1194" height="370" alt="Untitled-2025-11-16-0042 excalidraw" src="https://github.com/user-attachments/assets/5beca5ad-3852-42b3-9602-8d462adda0e2" />


## Comandos Úteis

### Criar um pedido manualmente

```bash
# Obter URL do API Gateway
API_ID=$(docker exec localstack awslocal apigateway get-rest-apis --query 'items[0].id' --output text)
API_URL="http://localhost:4566/restapis/$API_ID/prod/_user_request_/pedidos"

# Fazer requisição
curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "cliente": "João Silva",
    "itens": ["Pizza Margherita", "Refrigerante"],
    "mesa": 5
  }'
```

### Listar pedidos no DynamoDB

```bash
docker exec localstack awslocal dynamodb scan --table-name Pedidos
```

### Listar PDFs no S3

```bash
docker exec localstack awslocal s3 ls s3://pedidos-bucket/pedidos/
```

### Copiar PDF do S3 para máquina local

```bash
# Substitua PEDIDO_ID pelo ID do pedido
docker exec localstack awslocal s3 cp s3://pedidos-bucket/pedidos/PEDIDO_ID.pdf ./pedido.pdf
```

### Verificar mensagens na fila SQS

```bash
docker exec localstack awslocal sqs receive-message \
  --queue-url http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/FilaPedidos
```

### Verificar logs das Lambdas

```bash
# Lambda CriarPedido
docker exec localstack awslocal logs tail /aws/lambda/criarPedidos --follow

# Lambda ProcessarPedido
docker exec localstack awslocal logs tail /aws/lambda/processarPedidos --follow
```

### Limpar ambiente

```bash
docker compose down
```

## Estrutura do Projeto

```
.
├── docker-compose.yml          # Configuração do LocalStack
├── run.sh                      # Script de deploy completo
├── test.sh                     # Script de testes automatizados
├── lambdas/
│   ├── CriarPedido/           # Lambda para criar pedidos
│   │   ├── index.js
│   │   └── package.json
│   └── ProcessarPedido/       # Lambda para processar pedidos
│       ├── index.js
│       └── package.json
└── scripts/
    ├── deploy-lambda.sh        # Deploy Lambda CriarPedido
    ├── deploy-lambda-processadora.sh
    ├── deploy-apigateway.sh
    ├── deploy-dynamo.sh
    ├── deploy-sqs.sh
    ├── deploy-s3.sh
    └── deploy-sns.sh
```

## Serviços AWS Utilizados

- **Lambda**: Execução serverless das funções
- **API Gateway**: Endpoint REST para criação de pedidos
- **DynamoDB**: Armazenamento dos pedidos
- **SQS**: Fila para processamento assíncrono
- **S3**: Armazenamento dos PDFs gerados
- **SNS**: Notificações de pedidos concluídos

## Fluxo de Funcionamento

1. Cliente faz POST para API Gateway com dados do pedido
2. Lambda CriarPedido valida e salva no DynamoDB
3. Pedido é enviado para fila SQS
4. Lambda ProcessarPedido consome mensagem da fila
5. PDF é gerado e salvo no S3
6. Status do pedido é atualizado no DynamoDB
7. Notificação é enviada via SNS
