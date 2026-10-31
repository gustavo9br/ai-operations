// Gera o JSON de credenciais que o `n8n import:credentials` entende, com os mesmos IDs
// que os workflows referenciam. Os valores vêm de variáveis de ambiente (nada fica no repositório).
//
//   node scripts/seed-credentials.mjs --mock  > .credentials.dev.json   # OpenAI/Telegram falsos + Mailpit
//   node scripts/seed-credentials.mjs         > .credentials.dev.json   # serviços reais (veja as variáveis)
//
// Variáveis (modo real):
//   OPS_DB_HOST (db) OPS_DB_PORT (5432) OPS_DB_NAME (ops) OPS_DB_USER (ops_app) OPS_DB_PASSWORD
//   OPENAI_API_KEY
//   TELEGRAM_BOT_TOKEN
//   SMTP_HOST SMTP_PORT (587) SMTP_USER SMTP_PASSWORD SMTP_SECURE (false → STARTTLS; true → SSL/TLS, porta 465)
//   WEBHOOK_API_KEY  (chave exigida no cabeçalho X-API-Key do webhook de entrada)
const mock = process.argv.includes("--mock");
const env = process.env;

const need = (nome) => {
  const v = env[nome];
  if (!v) {
    console.error(`Defina ${nome} (ou use --mock para testar sem credenciais reais).`);
    process.exit(1);
  }
  return v;
};

const credenciais = [
  {
    id: "opsPostgres0001",
    name: "Ops Postgres",
    type: "postgres",
    data: {
      host: env.OPS_DB_HOST ?? "db",
      port: Number(env.OPS_DB_PORT ?? 5432),
      database: env.OPS_DB_NAME ?? "ops",
      user: env.OPS_DB_USER ?? "ops_app",
      password: env.OPS_DB_PASSWORD ?? (mock ? "ops_app_dev" : need("OPS_DB_PASSWORD")),
      ssl: "disable",
      maxConnections: 10,
      allowUnauthorizedCerts: false,
    },
  },
  {
    // Papel separado só para a memória do agente (ver db/sql/schema.sql).
    id: "opsPostgresMem01",
    name: "Ops Postgres (memória)",
    type: "postgres",
    data: {
      host: env.OPS_DB_HOST ?? "db",
      port: Number(env.OPS_DB_PORT ?? 5432),
      database: env.OPS_DB_NAME ?? "ops",
      user: env.OPS_MEMORIA_USER ?? "ops_memoria",
      password: env.OPS_MEMORIA_PASSWORD ?? (mock ? "ops_memoria_dev" : need("OPS_MEMORIA_PASSWORD")),
      ssl: "disable",
      maxConnections: 5,
      allowUnauthorizedCerts: false,
    },
  },
  {
    id: "opsOpenAi000001",
    name: "OpenAI (Ops)",
    type: "openAiApi",
    data: mock
      ? { apiKey: "sk-mock", url: "http://mock-apis:4010/v1", organizationId: "", header: false }
      : { apiKey: need("OPENAI_API_KEY"), url: "https://api.openai.com/v1", organizationId: "", header: false },
  },
  {
    id: "opsSmtp00000001",
    name: "SMTP (Ops)",
    type: "smtp",
    data: mock
      ? { host: "mailpit", port: 1025, user: "", password: "", secure: false, disableStarttls: true, hostName: "" }
      : {
          host: need("SMTP_HOST"),
          port: Number(env.SMTP_PORT ?? 587),
          user: need("SMTP_USER"),
          password: need("SMTP_PASSWORD"),
          secure: env.SMTP_SECURE === "true",
          disableStarttls: false,
          hostName: "",
        },
  },
  {
    id: "opsTelegram0001",
    name: "Telegram Bot (Ops)",
    type: "telegramApi",
    data: mock
      ? { accessToken: "123456:MOCK-TOKEN", baseUrl: "http://mock-apis:4010" }
      : { accessToken: need("TELEGRAM_BOT_TOKEN"), baseUrl: "https://api.telegram.org" },
  },
  {
    id: "opsWebhookKey01",
    name: "Webhook API Key (Ops)",
    type: "httpHeaderAuth",
    data: { name: "X-API-Key", value: env.WEBHOOK_API_KEY ?? (mock ? "dev-webhook-key" : need("WEBHOOK_API_KEY")) },
  },
];

process.stdout.write(JSON.stringify(credenciais, null, 2) + "\n");
