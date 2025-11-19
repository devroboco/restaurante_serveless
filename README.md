## salvando comandos

## Comando para copiar o arquivo (PDF)

docker exec localstack awslocal s3 cp s3://pedidos-bucket/pedidos/35aa7cda-48bc-483b-9f17-9c47b991fdc2.pdf ./

(acessar via desktop, eu sei o caminho de cabeça)

## Comando para copiar o arquivo (PDF)

## Comando para listar os arquivos (PDF)

docker exec localstack awslocal s3 ls s3://pedidos-bucket --recursive