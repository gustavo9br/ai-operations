// Envia os casos de tests/casos.json ao webhook de entrada e confere o resultado no banco.
//
//   node tests/enviar-casos.mjs                 # todos os casos
//   node tests/enviar-casos.mjs faq-senha comercial
//   node tests/enviar-casos.mjs --sem-mock      # pula casos que dependem do mock (falha-ia, guardrail)
//
// Variáveis: N8N_URL (http://localhost:5678)  WEBHOOK_API_KEY (dev-webhook-key)  ESPERA_SEG (25)
// Requer o ambiente de `scripts/dev-up.sh` (lê o banco via `docker compose exec db psql`).
import { readFile } from "node:fs/promises";
import { execFileSync } from "node:child_process";

const BASE = process.env.N8N_URL ?? "http://localhost:5678";
const KEY = process.env.WEBHOOK_API_KEY ?? "dev-webhook-key";
const ESPERA = Number(process.env.ESPERA_SEG ?? 25);

const args = process.argv.slice(2);
const semMock = args.includes("--sem-mock");
const ids = args.filter((a) => !a.startsWith("--"));
const todos = JSON.parse(await readFile(new URL("./casos.json", import.meta.url), "utf8"));
const casos = todos.filter((c) => (ids.length ? ids.includes(c.id) : true)).filter((c) => !(semMock && c.mock));

const psql = (sql) =>
  execFileSync("docker", ["compose", "-f", "docker-compose.dev.yml", "exec", "-T", "db", "psql", "-U", "postgres", "-d", "ops", "-At", "-c", sql], {
    encoding: "utf8",
  }).trim();

const antes = Number(psql("select count(*) from demandas"));
console.log(`Enviando ${casos.length} caso(s) para ${BASE}/webhook/demanda ...\n`);
for (const c of casos) {
  const r = await fetch(`${BASE}/webhook/demanda`, {
    method: "POST",
    headers: { "content-type": "application/json", "X-API-Key": KEY },
    body: JSON.stringify(c.payload),
  });
  console.log(`  ${r.ok ? "→" : "✗"} ${c.id.padEnd(26)} HTTP ${r.status}`);
  await new Promise((res) => setTimeout(res, 400));
}

console.log(`\nAguardando ${ESPERA}s o processamento (IA + banco + notificações)...\n`);
await new Promise((res) => setTimeout(res, ESPERA * 1000));

let falhas = 0;
for (const c of casos) {
  const linhas = JSON.parse(
    psql(
      `select coalesce(json_agg(t), '[]') from (select protocolo, categoria, prioridade, modo, status, ia_falhou, confianca_ia from demandas where assunto = '${c.payload.assunto.replace(/'/g, "''")}' order by id desc limit 1) t`
    )
  );
  const d = linhas[0];
  let ok;
  let detalhe;
  if (c.esperado.descartada) {
    ok = !d;
    detalhe = d ? `deveria ter sido descartada, mas virou ${d.protocolo}` : "descartada na validação, sem registro";
  } else if (!d) {
    ok = false;
    detalhe = "nenhum registro no banco";
  } else {
    const erradas = Object.entries(c.esperado).filter(([k, v]) => d[k] !== v);
    ok = erradas.length === 0;
    detalhe = `${d.protocolo} · ${d.categoria} ${d.prioridade} · conf ${d.confianca_ia} · modo=${d.modo} · status=${d.status}` +
      (ok ? "" : `  ⟵ esperado ${erradas.map(([k, v]) => `${k}=${v}`).join(", ")}`);
  }
  if (!ok) falhas++;
  console.log(`  ${ok ? "✓" : "✗"} ${c.id.padEnd(26)} ${detalhe}`);
}
const depois = Number(psql("select count(*) from demandas"));
console.log(`\n${falhas === 0 ? "Tudo certo" : `${falhas} caso(s) divergente(s)`} · ${depois - antes} demanda(s) novas no banco.`);
process.exit(falhas === 0 ? 0 : 1);
