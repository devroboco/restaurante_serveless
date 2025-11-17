async function handler(event) {
  try {
    console.log(event);
  } catch (error) {
    console.error("Erro:", error.message);
    return respostaErro(500, "Erro interno ao processar pedido", error.message);
  }
}

export { handler };
