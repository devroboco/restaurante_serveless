async function handler(event, context) {
  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    },
    body: JSON.stringify({
      mensagem: 'Pedido criado com sucesso!',
      pedido: 1,
      body: event.body
    })
  };
}

module.exports = { handler }; 