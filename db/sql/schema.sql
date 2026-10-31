-- Esquema do banco "ops" da Central de Demandas Inteligente.
-- Executado uma única vez na criação do volume (veja db/init/10-ops.sh).

-- ---------------------------------------------------------------------------
-- Dados de referência (lidos pelo workflow, nunca alterados por ele)
-- ---------------------------------------------------------------------------
CREATE TABLE clientes (
    id            SERIAL PRIMARY KEY,
    email         TEXT UNIQUE NOT NULL,
    nome          TEXT NOT NULL,
    empresa       TEXT NOT NULL,
    plano         TEXT NOT NULL CHECK (plano IN ('starter', 'pro', 'enterprise')),
    status        TEXT NOT NULL DEFAULT 'ativo' CHECK (status IN ('ativo', 'inadimplente', 'cancelado')),
    mrr_brl       NUMERIC(10, 2) NOT NULL DEFAULT 0,
    gerente_conta TEXT,
    criado_em     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE base_conhecimento (
    id            SERIAL PRIMARY KEY,
    categoria     TEXT NOT NULL,
    titulo        TEXT NOT NULL,
    conteudo      TEXT NOT NULL,
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX base_conhecimento_fts
    ON base_conhecimento USING gin (to_tsvector('portuguese', titulo || ' ' || conteudo));

-- ---------------------------------------------------------------------------
-- Registro operacional: uma linha por demanda recebida
-- ---------------------------------------------------------------------------
CREATE TABLE demandas (
    id                  BIGSERIAL PRIMARY KEY,
    protocolo           TEXT UNIQUE NOT NULL,
    hash_conteudo       TEXT NOT NULL,            -- idempotência: mesmo conteúdo em 24h = duplicata
    canal               TEXT NOT NULL DEFAULT 'portal',
    nome                TEXT NOT NULL,
    email               TEXT NOT NULL,
    assunto             TEXT NOT NULL,
    mensagem            TEXT NOT NULL,
    mensagem_mascarada  TEXT NOT NULL,            -- o que realmente é enviado ao LLM (CPF/CNPJ/cartão mascarados)
    cliente_id          INTEGER REFERENCES clientes (id),

    -- saída da IA (agente Triador)
    categoria           TEXT,
    prioridade          TEXT CHECK (prioridade IN ('P1', 'P2', 'P3', 'P4')),
    sentimento          TEXT,
    resumo              TEXT,
    valor_envolvido_brl NUMERIC(12, 2),
    confianca_ia        NUMERIC(3, 2),
    justificativa_ia    TEXT,
    ia_falhou           BOOLEAN NOT NULL DEFAULT false,

    -- decisão das regras de negócio (determinística)
    modo                TEXT CHECK (modo IN ('aprovacao', 'auto', 'encaminhar')),
    exige_aprovacao     BOOLEAN NOT NULL DEFAULT false,
    motivos_regra       TEXT[] NOT NULL DEFAULT '{}',
    equipe_responsavel  TEXT,
    sla_limite          TIMESTAMPTZ,
    sla_alertado_em     TIMESTAMPTZ,
    sla_violado_em      TIMESTAMPTZ,

    -- supervisão humana
    decisao_humana      TEXT,
    aprovador           TEXT,
    obs_humana          TEXT,

    -- ciclo de vida
    status              TEXT NOT NULL DEFAULT 'recebida' CHECK (status IN (
                            'recebida', 'triada', 'aguardando_aprovacao', 'aprovada',
                            'rejeitada', 'escalada_timeout', 'em_atendimento',
                            'respondida_automaticamente', 'respondida', 'concluida')),
    resposta_final      TEXT,
    respondida_em       TIMESTAMPTZ,
    concluida_em        TIMESTAMPTZ,
    resolucao           TEXT,
    execution_id        TEXT,
    criado_em           TIMESTAMPTZ NOT NULL DEFAULT now(),
    atualizado_em       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX demandas_dedupe ON demandas (hash_conteudo, criado_em DESC);
CREATE INDEX demandas_status ON demandas (status);
CREATE INDEX demandas_email  ON demandas (email, criado_em DESC);
CREATE INDEX demandas_sla    ON demandas (sla_limite) WHERE concluida_em IS NULL;

-- ---------------------------------------------------------------------------
-- Trilha de auditoria (append-only): quem fez o quê, em qual etapa
-- ---------------------------------------------------------------------------
CREATE TABLE eventos_demanda (
    id           BIGSERIAL PRIMARY KEY,
    protocolo    TEXT NOT NULL,
    etapa        TEXT NOT NULL,
    ator         TEXT NOT NULL,                  -- sistema | ia | humano:<nome>
    detalhes     JSONB NOT NULL DEFAULT '{}',
    execution_id TEXT,
    criado_em    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX eventos_protocolo ON eventos_demanda (protocolo, criado_em);

-- ---------------------------------------------------------------------------
-- "Sistema interno" que recebe a ação crítica depois de aprovada por um humano
-- ---------------------------------------------------------------------------
CREATE TABLE acoes_financeiras (
    id            BIGSERIAL PRIMARY KEY,
    protocolo     TEXT NOT NULL,
    tipo          TEXT NOT NULL CHECK (tipo IN ('reembolso', 'cancelamento', 'credito')),
    cliente_email TEXT NOT NULL,
    valor_brl     NUMERIC(12, 2),
    aprovado_por  TEXT NOT NULL,
    status        TEXT NOT NULL DEFAULT 'pendente_processamento',
    criado_em     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Memória do agente Redator (nó Postgres Chat Memory do n8n), uma sessão por cliente
-- ---------------------------------------------------------------------------
CREATE TABLE n8n_chat_histories (
    id         SERIAL PRIMARY KEY,
    session_id VARCHAR(255) NOT NULL,
    message    JSONB NOT NULL
);
CREATE INDEX n8n_chat_histories_session ON n8n_chat_histories (session_id);
-- O nó de memória roda `CREATE TABLE IF NOT EXISTS` a cada uso, o que exige CREATE no schema.
-- Para não dar esse privilégio ao papel principal, a memória usa um papel próprio (ops_memoria),
-- que é dono só desta tabela e não enxerga demandas, clientes nem a trilha de auditoria.
ALTER TABLE n8n_chat_histories OWNER TO ops_memoria;

-- ---------------------------------------------------------------------------
-- Visões de observabilidade (usadas no README e no vídeo)
-- ---------------------------------------------------------------------------
CREATE VIEW v_kpis AS
SELECT
    count(*)                                                                    AS total_demandas,
    count(*) FILTER (WHERE modo = 'auto')                                       AS resolvidas_por_ia,
    count(*) FILTER (WHERE exige_aprovacao)                                     AS com_aprovacao_humana,
    count(*) FILTER (WHERE modo = 'encaminhar')                                 AS encaminhadas,
    count(*) FILTER (WHERE ia_falhou)                                           AS falhas_de_ia,
    count(*) FILTER (WHERE sla_violado_em IS NOT NULL)                          AS sla_violados,
    round(100.0 * count(*) FILTER (WHERE modo = 'auto') / NULLIF(count(*), 0), 1) AS pct_automatizado,
    round(avg(extract(epoch FROM (e.criado_em - d.criado_em)))::numeric, 1)     AS segundos_ate_triagem
FROM demandas d
LEFT JOIN LATERAL (
    SELECT criado_em FROM eventos_demanda
    WHERE protocolo = d.protocolo AND etapa = 'triagem_ia'
    ORDER BY criado_em LIMIT 1
) e ON true;

-- ---------------------------------------------------------------------------
-- Privilégio mínimo: o n8n conecta como ops_app, que não faz DDL nem DELETE e
-- não consegue reescrever a trilha de auditoria.
-- ---------------------------------------------------------------------------
GRANT CONNECT ON DATABASE ops TO ops_app;
GRANT USAGE ON SCHEMA public TO ops_app;
GRANT SELECT                 ON clientes, base_conhecimento TO ops_app;
GRANT SELECT, INSERT, UPDATE ON demandas TO ops_app;
GRANT SELECT, INSERT         ON eventos_demanda, acoes_financeiras TO ops_app;
GRANT SELECT                 ON v_kpis TO ops_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ops_app;

GRANT CONNECT ON DATABASE ops TO ops_memoria;
GRANT USAGE, CREATE ON SCHEMA public TO ops_memoria;
