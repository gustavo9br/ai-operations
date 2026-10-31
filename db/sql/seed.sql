-- Dados fictícios da empresa de exemplo "Vértice Cloud" (SaaS B2B de gestão).
-- Nenhum dado aqui é real.

INSERT INTO clientes (email, nome, empresa, plano, status, mrr_brl, gerente_conta) VALUES
 ('carla@padariasol.example',     'Carla Mendes',    'Padaria Sol',            'starter',    'ativo',         199.00, NULL),
 ('rodrigo@cafeduarte.example',   'Rodrigo Duarte',  'Café Duarte',            'starter',    'inadimplente',  199.00, NULL),
 ('marina@clinicavida.example',   'Marina Souza',    'Clínica Vida',           'pro',        'ativo',         590.00, 'Paulo Reis'),
 ('felipe@logisticaorion.example','Felipe Andrade',  'Logística Órion',        'pro',        'ativo',         590.00, 'Paulo Reis'),
 ('helena@atlasengenharia.example','Helena Ribeiro', 'Atlas Engenharia',       'enterprise', 'ativo',        2400.00, 'Juliana Costa'),
 ('bruno@varejonorte.example',    'Bruno Teixeira',  'Rede Varejo Norte',      'enterprise', 'ativo',        3200.00, 'Juliana Costa'),
 ('sofia@estudiolume.example',    'Sofia Lima',      'Estúdio Lume',           'starter',    'cancelado',        0.00, NULL);

INSERT INTO base_conhecimento (categoria, titulo, conteudo) VALUES
 ('reembolso', 'Política de reembolso',
  'Reembolso integral em até 7 dias corridos após a contratação ou renovação, ou quando há cobrança indevida comprovada. Fora desse prazo não há reembolso, apenas crédito proporcional em casos de falha comprovada do serviço. Reembolsos acima de R$ 500 exigem aprovação do Financeiro. O estorno leva de 5 a 10 dias úteis no cartão e até 3 dias úteis via Pix. A equipe nunca deve prometer reembolso antes da aprovação.'),
 ('cancelamento', 'Cancelamento de plano',
  'Planos mensais podem ser cancelados a qualquer momento, sem multa, e o acesso segue até o fim do ciclo pago. Planos anuais exigem aviso de 30 dias e não têm reembolso proporcional após os 7 dias iniciais. Todo pedido de cancelamento deve ser encaminhado ao time de Customer Success para uma tentativa de retenção antes da confirmação.'),
 ('cobranca', 'Segunda via de fatura e boleto',
  'A segunda via está em Portal > Financeiro > Faturas. Faturas vencem sempre no dia 10. Após 5 dias de atraso o acesso é limitado ao modo leitura; após 30 dias a conta é suspensa. Negociação de débitos é feita exclusivamente pelo Financeiro.'),
 ('cobranca', 'Cobrança duplicada ou indevida',
  'Se o cliente relatar cobrança em duplicidade, solicite o número da fatura e o comprovante. A conferência é feita pelo Financeiro em até 2 dias úteis. Confirmada a duplicidade, o valor é estornado integralmente.'),
 ('duvida_tecnica', 'Redefinição de senha e 2FA',
  'Para redefinir a senha, use "Esqueci minha senha" na tela de login; o link expira em 30 minutos. A redefinição do segundo fator (2FA) exige validação de identidade com o administrador da conta e é feita pelo Suporte N2.'),
 ('duvida_tecnica', 'Limites e erros da API',
  'A API aceita até 100 requisições por minuto por chave. O erro 429 indica que o limite foi excedido: aguarde o cabeçalho Retry-After. Erros 5xx persistentes devem ser tratados como incidente. A documentação fica em docs.vertice.example/api.'),
 ('duvida_tecnica', 'Exportação de relatórios',
  'Relatórios podem ser exportados em CSV ou XLSX em Relatórios > Exportar. Exportações com mais de 100 mil linhas são enviadas por e-mail em até 15 minutos.'),
 ('incidente_tecnico', 'Incidentes e página de status',
  'Indisponibilidades são publicadas em status.vertice.example. Incidentes P1 (sistema fora do ar ou perda de dados) têm primeira resposta em até 1 hora e acionam o plantão de engenharia. Nunca estime prazo de correção antes da análise do plantão.'),
 ('comercial', 'Troca de plano',
  'A troca de plano tem efeito imediato e cobra o valor proporcional (pro rata) na próxima fatura. Descontos comerciais só podem ser concedidos pelo time de Vendas. Propostas para o plano Enterprise passam por um executivo de contas.'),
 ('privacidade', 'Direitos do titular (LGPD)',
  'Pedidos de acesso, correção ou exclusão de dados pessoais são tratados pelo Encarregado (DPO) em até 15 dias. O atendimento não deve executar exclusões diretamente; encaminhe ao DPO em privacidade@vertice.example.'),
 ('geral', 'Horário e canais de atendimento',
  'Atendimento de segunda a sexta, das 8h às 18h (horário de Brasília), pelo portal e por e-mail. Clientes Enterprise contam com plantão 24x7 para incidentes P1.');
