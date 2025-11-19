import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import PDFDocument from "pdfkit";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { SNSClient, PublishCommand } from "@aws-sdk/client-sns";

const s3Client = new S3Client({
  region: "us-east-1",
  endpoint: process.env.LOCALSTACK_ENDPOINT || "http://host.docker.internal:4566",
  forcePathStyle: true,
  credentials: {
    accessKeyId: "test",
    secretAccessKey: "test",
  },
});

const BUCKET_NAME = "pedidos-bucket";

const dynamoDBClient = new DynamoDBClient({
  region: "us-east-1",
  endpoint:
    process.env.LOCALSTACK_ENDPOINT || "http://host.docker.internal:4566",
  credentials: {
    accessKeyId: "test",
    secretAccessKey: "test",
  },
});

const dynamoDB = DynamoDBDocumentClient.from(dynamoDBClient);

const snsClient = new SNSClient({
  region: "us-east-1",
  endpoint: process.env.LOCALSTACK_ENDPOINT || "http://host.docker.internal:4566",
  credentials: {
    accessKeyId: "test",
    secretAccessKey: "test",
  },
});

const TOPIC_ARN = "arn:aws:sns:us-east-1:000000000000:PedidosConcluidos";

async function criarPDF(pedidoData) {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument();
    const chunks = [];

    doc.on("data", (chunk) => chunks.push(chunk));
    doc.on("end", () => resolve(Buffer.concat(chunks)));
    doc.on("error", reject);

    doc
      .fontSize(20)
      .text("Pedido - Confirmação", { align: "center" })
      .moveDown();

    doc.fontSize(12);
    doc.text(`Pedido ID: ${pedidoData.id || "N/A"}`);
    doc.text(
      `Data: ${new Date(pedidoData.criadoEm).toLocaleString("pt-BR", {
        timeZone: "America/Sao_Paulo",
      })}`
    );
    doc.text(`Cliente: ${pedidoData.cliente || "N/A"}`);
    doc.text(`Mesa: ${pedidoData.mesa || "N/A"}`);
    doc.text(`Status: ${pedidoData.status || "N/A"}`);
    doc.moveDown();

    if (pedidoData.itens && pedidoData.itens.length > 0) {
      doc.fontSize(14).text("Itens:", { underline: true }).moveDown(0.5);

      doc.fontSize(11);
      pedidoData.itens.forEach((item, index) => {
        doc.text(`${index + 1}. ${item}`);
      });
      doc.moveDown();
    }

    doc.end();
  });
}

async function salvarPDFNoS3(pdfBuffer, fileName) {
  const command = new PutObjectCommand({
    Bucket: BUCKET_NAME,
    Key: fileName,
    Body: pdfBuffer,
    ContentType: "application/pdf",
  });

  return await s3Client.send(command);
}

async function atualizarStatusPedido(pedido, novoStatus) {
  try {
    pedido.status = "PROCESSADO";

    await dynamoDB.send(
      new UpdateCommand({
        TableName: "Pedidos",
        Key: { id: pedido.id },
        UpdateExpression: "SET #status = :status, atualizadoEm = :atualizadoEm",
        ExpressionAttributeNames: {
          "#status": "status",
        },
        ExpressionAttributeValues: {
          ":status": novoStatus,
          ":atualizadoEm": new Date().toISOString(),
        },
      })
    );

    console.log(
      `Status do pedido ${pedido.id} atualizado para "${novoStatus}"`
    );
    return {
      mensagem: `Status do pedido ${pedido.id} atualizado com sucesso!`,
    };
  } catch (error) {
    console.error("Erro ao atualizar status no DynamoDB: ", error);
    throw new Error("Erro ao atualizar o status do pedido");
  }
}

async function enviarNotificacaoSNS(pedidoData) {
  const command = new PublishCommand({
    TopicArn: TOPIC_ARN,
    Message: `Novo pedido concluído: ${pedidoData.id || "N/A"}`,
    Subject: "Pedido Pronto!",
  });

  return await snsClient.send(command);
}

async function handler(event) {
  try {
    for (const record of event.Records) {
      const pedidoData = JSON.parse(record.body);
      console.log("Processando pedido:", pedidoData);

      await atualizarStatusPedido(pedidoData, "PROCESSADO");

      const pdfBuffer = await criarPDF(pedidoData);
      console.log(`PDF gerado com ${pdfBuffer.length} bytes`);

      const fileName = `pedidos/${pedidoData.id || Date.now()}.pdf`;

      const result = await salvarPDFNoS3(pdfBuffer, fileName);
      console.log(`PDF salvo no S3: ${fileName}`, result);

      const snsResult = await enviarNotificacaoSNS(pedidoData);
      console.log("Notificação SNS enviada:", snsResult.MessageId);

      console.log("Pedido processado com sucesso!");
    }

    return {
      statusCode: 200,
      body: JSON.stringify({ message: "Pedidos processados com sucesso" }),
    };
  } catch (error) {
    console.error("Erro ao processar pedido:", error);
    throw error;
  }
}

export { handler };
