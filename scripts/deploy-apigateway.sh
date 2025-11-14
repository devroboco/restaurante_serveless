API_ID=$(awslocal apigateway create-rest-api --name "API" --query 'id' --output text)
ROOT_ID=$(awslocal apigateway get-resources --rest-api-id $API_ID --query 'items[0].id' --output text)

RESOURCE_ID=$(awslocal apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ROOT_ID \
  --path-part pedidos \
  --query 'id' --output text)

awslocal lambda add-permission \
  --function-name criarPedidos \
  --statement-id apigateway-invoke \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:us-east-1:000000000000:$API_ID/*/*" > /dev/null 2>&1

awslocal apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $RESOURCE_ID \
  --http-method POST \
  --authorization-type NONE > /dev/null 2>&1

awslocal apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $RESOURCE_ID \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:000000000000:function:criarPedidos/invocations" > /dev/null 2>&1

awslocal apigateway create-deployment --rest-api-id $API_ID --stage-name prod > /dev/null 2>&1

echo "URL: http://localhost:4566/restapis/$API_ID/prod/_user_request_/pedidos"