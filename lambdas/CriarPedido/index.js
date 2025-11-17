import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand } from "@aws-sdk/lib-dynamodb";
import { v4 as uuidv4 } from "uuid";

const client = new DynamoDBClient({
  region: "us-east-1",
  endpoint: process.env.LOCALSTACK_ENDPOINT || "http://host.docker.internal:4566",
  credentials: {
    accessKeyId: "test",
    secretAccessKey: "test",
  },
});

const dynamoDB = DynamoDBDocumentClient.from(client);

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

function respostaSucesso(pedido) {
  return {
    statusCode: 201,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      mensagem: "Pedido criado com sucesso",
      pedidoId: pedido.id,
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

    return respostaSucesso(pedidoSalvo);
  } catch (error) {
    console.error("Erro:", error.message);
    return respostaErro(500, "Erro interno ao processar pedido", error.message);
  }
}

export { handler };
