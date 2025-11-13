async function handler(event, context) {
  return {
    statusCode: 200,
    controler: 1,
    body: JSON.stringify({ results: "Mudei o texto" }),
  };
}

module.exports = { handler }; 