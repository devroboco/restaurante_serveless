import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand } from "@aws-sdk/lib-dynamodb";
import { v4 as uuidv4 } from "uuid";
import { SQSClient, SendMessageCommand } from "@aws-sdk/client-sqs";

const client = new DynamoDBClient({
  region: "us-east-1",
  endpoint:
    process.env.LOCALSTACK_ENDPOINT || "http://host.docker.internal:4566",
  credentials: {
    accessKeyId: "test",
    secretAccessKey: "test",
  },
});

const sqsClient = new SQSClient({
  region: "us-east-1",
  endpoint:
    process.env.LOCALSTACK_ENDPOINT || "http://host.docker.internal:4566",
  credentials: {
    accessKeyId: "test",
    secretAccessKey: "test",
  },
});

const dynamoDB = DynamoDBDocumentClient.from(client);

const QUEUE_URL =
  process.env.QUEUE_URL ||
  "http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/FilaPedidos";

function validarPedido(pedido) {
  const erros = [];

  if (
    !pedido.cliente ||
    typeof pedido.cliente !== "string" ||
    pedido.cliente.trim() === ""
  ) {
    erros.push('Campo "cliente" é obrigatório e deve ser uma string não vazia');
  }

  if (
    !pedido.itens ||
    !Array.isArray(pedido.itens) ||
    pedido.itens.length === 0
  ) {
    erros.push('Campo "itens" é obrigatório e deve ser um array não vazio');
  } else {
    pedido.itens.forEach((item, index) => {
      if (typeof item !== "string" || item.trim() === "") {
        erros.push(
          `Item na posição ${index + 1} deve ser uma string não vazia`
        );
      }
    });
  }

  if (!pedido.mesa || typeof pedido.mesa !== "number" || pedido.mesa <= 0) {
    erros.push(
      'Campo "mesa" é obrigatório e deve ser um número maior que zero'
    );
  }

  return {
    valido: erros.length === 0,
    erros,
  };
}

async function salvarPedido(pedido) {
  const item = {
    id: uuidv4(),
    cliente: pedido.cliente.trim(),
    itens: pedido.itens.map((item) => item.trim()),
    mesa: pedido.mesa,
    status: "PENDENTE",
    criadoEm: new Date().toISOString(),
    atualizadoEm: new Date().toISOString(),
  };

  await dynamoDB.send(
    new PutCommand({
      TableName: "Pedidos",
      Item: item,
    })
  );

  return item;
}

async function enviarParaFila(pedido) {
  const mensagem = {
    id: pedido.id,
    cliente: pedido.cliente,
    itens: pedido.itens,
    mesa: pedido.mesa,
    status: pedido.status,
    criadoEm: pedido.criadoEm,
  };

  const command = new SendMessageCommand({
    QueueUrl: QUEUE_URL,
    MessageBody: JSON.stringify(mensagem),
    MessageAttributes: {
      id: {
        DataType: "String",
        StringValue: pedido.id,
      },
      mesa: {
        DataType: "Number",
        StringValue: pedido.mesa.toString(),
      },
    },
  });

  const resultado = await sqsClient.send(command);

  console.log("Mensagem enviada para SQS:", {
    MessageId: resultado.MessageId,
    id: pedido.id,
  });

  return resultado;
}

function respostaSucesso(pedido) {
  return {
    statusCode: 201,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      mensagem: "Pedido criado com sucesso",
      id: pedido.id,
      pedido: pedido,
    }),
  };
}

function respostaErro(statusCode, mensagem, detalhes = null) {
  return {
    statusCode,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      mensagem,
      ...(detalhes && { detalhes }),
    }),
  };
}

async function handler(event) {
  try {
    const pedido =
      typeof event.body === "string"
        ? JSON.parse(event.body)
        : event.body || event;

    const validacao = validarPedido(pedido);

    if (!validacao.valido) {
      return respostaErro(400, "Pedido inválido", validacao.erros);
    }

    const pedidoSalvo = await salvarPedido(pedido);

    try {
      await enviarParaFila(pedidoSalvo);
      console.log("Pedido enviado para a fila SQS");
    } catch (sqsError) {
      console.error("Erro ao enviar para SQS:", sqsError);
      return respostaErro(
        500,
        "Pedido salvo, mas falha ao enviar para processamento",
        sqsError.message
      );
    }

    return respostaSucesso(pedidoSalvo);
  } catch (error) {
    console.error("Erro:", error.message);
    return respostaErro(500, "Erro interno ao processar pedido", error.message);
  }
}

export { handler };
