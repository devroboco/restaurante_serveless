import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import PDFDocument from "pdfkit";

const s3Client = new S3Client({
  region: "us-east-1",
  endpoint: "http://host.docker.internal:4566",
  forcePathStyle: true,
  credentials: {
    accessKeyId: "test",
    secretAccessKey: "test",
  },
});

const BUCKET_NAME = "pedidos-bucket";

/**
 * Cria um PDF a partir dos dados do pedido
 * @param {Object} pedidoData - Dados do pedido
 * @returns {Promise<Buffer>} - Buffer do PDF gerado
 */
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

/**
 * Salva o PDF no S3
 * @param {Buffer} pdfBuffer - Buffer do PDF
 * @param {string} fileName - Nome do arquivo
 * @returns {Promise<Object>} - Resultado do upload
 */
async function salvarPDFNoS3(pdfBuffer, fileName) {
  const command = new PutObjectCommand({
    Bucket: BUCKET_NAME,
    Key: fileName,
    Body: pdfBuffer,
    ContentType: "application/pdf",
  });

  return await s3Client.send(command);
}

async function handler(event) {
  try {
    console.log("Evento recebido:", JSON.stringify(event, null, 2));

    for (const record of event.Records) {
      const pedidoData = JSON.parse(record.body);
      console.log("Processando pedido:", pedidoData);

      const pdfBuffer = await criarPDF(pedidoData);
      console.log(`PDF gerado com ${pdfBuffer.length} bytes`);

      const fileName = `pedidos/${pedidoData.id || Date.now()}.pdf`;

      const result = await salvarPDFNoS3(pdfBuffer, fileName);
      console.log(`PDF salvo no S3: ${fileName}`, result);

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
