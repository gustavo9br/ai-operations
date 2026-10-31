// Mocks mínimos de OpenAI (chat completions) e Telegram (sendMessage) para testar o
// workflow de ponta a ponta sem custo e sem credenciais. NÃO é parte da solução em
// produção: serve só para verificar o encanamento do n8n (nós, ramos, banco, e-mail).
//
// Rotas:
//   POST /v1/chat/completions        → "LLM" por regras de palavra-chave
//   POST /bot<token>/<metodo>        → Telegram
//   GET  /telegram/messages          → mensagens recebidas (para os testes lerem o link de aprovação)
//   GET  /requests                   → últimas requisições de LLM (para inspecionar prompts)
import http from "node:http";

const telegram = [];
const llmRequests = [];

const json = (res, status, body) => {
  const data = JSON.stringify(body);
  res.writeHead(status, { "content-type": "application/json", "content-length": Buffer.byteLength(data) });
  res.end(data);
};

const readBody = (req) =>
  new Promise((resolve) => {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => {
      try { resolve(JSON.parse(Buffer.concat(chunks).toString() || "{}")); } catch { resolve({}); }
    });
  });

const textOf = (content) =>
  typeof content === "string" ? content : Array.isArray(content) ? content.map((p) => p.text ?? "").join("\n") : "";

function triar(texto) {
  const t = texto.toLowerCase();
  const valorMatch = texto.match(/R\$\s*([\d.]+(?:,\d{1,2})?)/);
  const valor = valorMatch ? Number(valorMatch[1].replace(/\./g, "").replace(",", ".")) : null;
  let categoria = "outros", prioridade = "P3", sentimento = "neutro", confianca = 0.9, segura = false;

  if (/reembols|estorn|devolu/.test(t)) { categoria = "reembolso"; prioridade = "P2"; sentimento = "negativo"; }
  else if (/cancel/.test(t)) { categoria = "cancelamento"; prioridade = "P2"; sentimento = "negativo"; }
  else if (/fora do ar|indispon|parou de funcionar|erro 500|sistema caiu|n[ãa]o abre/.test(t)) {
    categoria = "incidente_tecnico"; prioridade = /todos|produ[çc][ãa]o|fora do ar/.test(t) ? "P1" : "P2"; sentimento = "critico";
  }
  else if (/fatura|boleto|cobran[çc]a|cobrado/.test(t)) { categoria = "cobranca"; prioridade = "P3"; sentimento = "negativo"; }
  else if (/senha|api|exportar|relat[óo]rio|429|2fa/.test(t)) { categoria = "duvida_tecnica"; prioridade = "P4"; segura = true; }
  else if (/plano|proposta|desconto|or[çc]amento/.test(t)) { categoria = "comercial"; prioridade = "P3"; }
  else if (/parab[ée]ns|obrigad|elogio|sugest[ãa]o/.test(t)) { categoria = "elogio_sugestao"; prioridade = "P4"; sentimento = "positivo"; segura = true; }
  else { confianca = 0.4; }
  if (/talvez|n[ãa]o sei|\?\?\?/.test(t)) confianca = 0.5;

  return {
    categoria, prioridade, sentimento,
    resumo: `Cliente relata: ${texto.replace(/\s+/g, " ").slice(0, 120)}`,
    valor_envolvido_brl: valor ?? 0,
    confianca,
    justificativa: `Classificação (mock) por palavras-chave: ${categoria}.`,
    risco_juridico_ou_reputacional: /procon|advogad|processo|jur[ií]dic|reclame aqui|vazamento/.test(t),
    resposta_automatica_segura: segura,
  };
}

async function chatCompletions(req, res) {
  const body = await readBody(req);
  llmRequests.push(body);
  if (llmRequests.length > 50) llmRequests.shift();
  const messages = body.messages ?? [];
  const system = messages.filter((m) => m.role === "system" || m.role === "developer").map((m) => textOf(m.content)).join("\n");
  const all = messages.map((m) => textOf(m.content)).join("\n");
  const base = { id: "chatcmpl-mock", object: "chat.completion", created: Math.floor(Date.now() / 1000), model: body.model ?? "mock" };
  const usage = { prompt_tokens: 120, completion_tokens: 80, total_tokens: 200 };

  if (/FALHA_IA/.test(all)) return json(res, 500, { error: { message: "mock: falha simulada do provedor", type: "server_error" } });

  if (/agente TRIADOR/i.test(system)) {
    const user = messages.filter((m) => m.role === "user").map((m) => textOf(m.content)).join("\n");
    // só o texto do cliente (entre aspas triplas): as instruções de formato listam todas as categorias
    const alvo = user.split("\"\"\"")[1] ?? user;
    // O n8n pede a saída dentro de { "output": ... } e em um bloco ```json
    const conteudo = "```json\n" + JSON.stringify({ output: triar(alvo) }) + "\n```";
    return json(res, 200, { ...base, usage, choices: [{ index: 0, finish_reason: "stop", message: { role: "assistant", content: conteudo } }] });
  }

  // Agente REDATOR: primeiro chama a ferramenta de base de conhecimento, depois escreve a resposta.
  const jaUsouFerramenta = messages.some((m) => m.role === "tool");
  if (body.tools?.length && !jaUsouFerramenta) {
    const tool = body.tools[0].function;
    const props = Object.keys(tool.parameters?.properties ?? {});
    const args = {};
    const alvo = all.toLowerCase();
    const termo = /reembols|estorn/.test(alvo) ? "reembolso" : /cancel/.test(alvo) ? "cancelamento" : /senha|api|429/.test(alvo) ? "senha api" : "atendimento";
    for (const p of props) args[p] = termo;
    return json(res, 200, { ...base, usage, choices: [{ index: 0, finish_reason: "tool_calls", message: {
      role: "assistant", content: null,
      tool_calls: [{ id: "call_mock_1", type: "function", function: { name: tool.name, arguments: JSON.stringify(args) } }] } }] });
  }
  const promessa = /GUARDRAIL_TESTE/.test(all) ? "Garantimos o reembolso integral do valor em até 2 dias." : "Se precisar de algo mais, é só responder este e-mail.";
  const resposta = [
    "Olá!",
    "",
    "Obrigado por entrar em contato com a Vértice Cloud. Recebemos sua solicitação e, de acordo com a nossa política, já encaminhamos os próximos passos ao time responsável.",
    "",
    promessa,
    "",
    "Equipe de Atendimento Vértice Cloud",
  ].join("\n");
  return json(res, 200, { ...base, usage, choices: [{ index: 0, finish_reason: "stop", message: { role: "assistant", content: resposta } }] });
}

http.createServer(async (req, res) => {
  const url = new URL(req.url, "http://x");
  if (req.method === "POST" && url.pathname.endsWith("/chat/completions")) return chatCompletions(req, res);
  if (req.method === "GET" && url.pathname === "/models") return json(res, 200, { data: [{ id: "mock" }] });
  if (req.method === "GET" && url.pathname === "/telegram/messages") return json(res, 200, telegram);
  if (req.method === "DELETE" && url.pathname === "/telegram/messages") { telegram.length = 0; return json(res, 200, { ok: true }); }
  if (req.method === "GET" && url.pathname === "/requests") return json(res, 200, llmRequests);
  const m = url.pathname.match(/^\/bot[^/]+\/(\w+)$/);
  if (m) {
    const body = await readBody(req);
    if (m[1] === "sendMessage") {
      telegram.push({ chat_id: body.chat_id, text: body.text, parse_mode: body.parse_mode, at: new Date().toISOString() });
      return json(res, 200, { ok: true, result: { message_id: telegram.length, chat: { id: Number(body.chat_id) || 0 }, date: Math.floor(Date.now() / 1000), text: body.text } });
    }
    return json(res, 200, { ok: true, result: true });
  }
  json(res, 404, { error: "não encontrado", path: url.pathname });
}).listen(4010, () => console.log("mock-apis ouvindo em :4010"));
