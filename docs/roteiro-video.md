# Roteiro: vídeo pitch (até 4 minutos)

**Formato:** gravação de tela com a câmera num canto (Loom ou OBS). Publicar no YouTube como **não listado** (ou Loom/Drive) e testar o link numa aba anônima antes de enviar.

**Postura:** você está *propondo a automação para a Vértice Cloud*. Fale como quem apresenta a uma diretoria: problema, solução, prova de que funciona, ganho.

**O que o enunciado exige que apareça** (confira antes de enviar):
- [ ] Problema e processo original
- [ ] Arquitetura da solução
- [ ] Automação executando **do início ao fim**
- [ ] Onde a IA atua e quais decisões ela toma
- [ ] O momento da **supervisão humana**
- [ ] O ganho da automação

---

## Antes de gravar

- [ ] Ambiente com **IA real**: `OPENAI_API_KEY`, bot do Telegram e SMTP configurados (`scripts/dev-up.sh real` ou o deploy na VPS). Com o mock, a IA é por palavras-chave e a demonstração perde o sentido.
- [ ] Telegram aberto **no celular ou numa janela ao lado**, com o chat do bot visível (a notificação chegando é o melhor momento do vídeo).
- [ ] Caixa de e-mail do cliente aberta numa aba (a sua, cadastrada como cliente: veja o README, "Clientes de exemplo").
- [ ] n8n aberto no workflow **01** com o zoom ajustado para caber as 8 faixas (tecla `1` = ajustar à tela).
- [ ] Duas abas prontas: `/form/nova-demanda` e a aba **Executions** do n8n.
- [ ] Texto do caso 1 copiado (reembolso com CPF) e do caso 2 (dúvida simples).
- [ ] `select * from v_kpis;` num cliente SQL, ou o print dos números, para o final.
- [ ] Notificações do sistema silenciadas e zoom do navegador em 110%.
- [ ] **Ensaie uma vez completo** para saber quanto tempo a IA leva a responder e cortar a espera na edição se passar de 10 s.

**Texto dos casos** (cole nos formulários):

- **Caso 1, reembolso (vai para o humano):** "Fui cobrada duas vezes na fatura de outubro e preciso do reembolso de R$ 1.180,00 que foi debitado a mais. Meu CPF é 123.456.789-09."
- **Caso 2, dúvida simples (a IA resolve):** assunto "Como exportar relatório?", mensagem "Preciso exportar o relatório de vendas do mês em planilha. Onde fica essa opção?"

---

## 0:00–0:30 · O problema (câmera + tela do README ou slide simples)

> "Oi, eu sou o Gustavo. Imagine a Vértice Cloud, uma empresa de software que recebe mais de mil demandas de clientes por mês: cobrança, reembolso, cancelamento, sistema fora do ar.
> Hoje alguém lê cada mensagem, abre o cadastro, registra numa planilha, decide quem trata e em que prazo, escreve a resposta e, quando envolve dinheiro, pede aprovação, tudo manualmente. O resultado: o cliente espera horas por uma primeira resposta, cada pessoa decide de um jeito e ninguém consegue dizer o que aconteceu com cada pedido.
> Eu automatizei isso com **n8n** e **agentes de IA**, mas com uma regra: a IA ajuda, **quem decide o que é crítico é uma pessoa**."

## 0:30–1:15 · Arquitetura (tela: canvas do workflow 01)

- Passar o mouse pelas faixas coloridas, da esquerda para a direita.

> "Este é o fluxo, e ele segue a cadeia **entrada, processamento, dados, IA, decisão, ação, supervisão e registro**, uma faixa para cada etapa.
> A demanda entra por formulário ou por API. Antes de qualquer coisa eu **mascaro CPF, CNPJ e cartão**, porque o texto vai para um modelo de linguagem. Consulto o cliente no Postgres, mando o protocolo por e-mail e aí entram **dois agentes de IA**.
> O **Triador** lê a mensagem e devolve a categoria, a prioridade, o valor citado e, o mais importante, **o quanto ele confia no próprio resultado**. O **Redator** é um agente com ferramenta: ele consulta a base de conhecimento da empresa antes de escrever e tem memória do cliente.
> Entre os dois e depois deles, **regras fixas**, e não a IA, decidem o prazo, o responsável e *se uma resposta pode sair sem revisão*."

## 1:15–2:45 · Demonstração do início ao fim: caso 1 (tela: formulário → e-mail → Telegram → decisão)

1. **Formulário** (`/form/nova-demanda`): colar o caso do reembolso → *Enviar demanda*.

> "Sou uma cliente pedindo reembolso de R$ 1.180, e digitei meu CPF na mensagem."

2. **E-mail:** mostrar o protocolo chegando.

> "O protocolo chega na hora."

3. **Telegram:** a mensagem de aprovação chega.

> "Por ser reembolso e passar de R$ 500, a regra exige uma pessoa. O workflow **pausou** e me avisou no Telegram: resumo, plano, prioridade, prazo e **por que a decisão é minha**."

4. **Formulário de decisão:** abrir o link, apontar o `[CPF]` mascarado, o resumo e o rascunho.

> "Aqui está o que a IA entendeu e o rascunho de resposta, que eu posso editar. O CPF nem chegou ao modelo: está mascarado. Eu ajusto uma frase, confirmo o valor e **aprovo**."

5. **Resultado:** e-mail do cliente + n8n (aba Executions) mostrando o caminho verde, o nó "Executar ação aprovada e registrar" e a tabela `acoes_financeiras`.

> "Só agora a ação acontece: o reembolso entra na fila do financeiro, o cliente recebe a resposta, e tudo fica registrado: quem aprovou, quando e se editou o texto da IA. Se eu não respondesse em quatro horas, o sistema escalaria ao gestor e **não executaria nada**."

## 2:45–3:15 · Onde a IA resolve sozinha (tela: formulário → e-mail)

- Enviar o caso 2 (dúvida simples) e mostrar a resposta chegando sem ninguém aprovar.

> "Já uma dúvida simples, como exportar um relatório, a IA responde sozinha. Mas só se a classificação for da categoria permitida, a confiança for alta e um guardrail validar que o texto **não promete nada que a empresa não prometeu**. Se qualquer condição falha, vira encaminhamento para a equipe, com o rascunho como sugestão."

## 3:15–3:40 · Confiabilidade e acompanhamento (tela: trilha de auditoria / Executions com erro)

> "E se a IA cair? O n8n tenta o modelo reserva; se falhar de novo, a demanda vai para triagem humana, e o fluxo nunca para. Falhas de banco ou e-mail disparam um alerta no Telegram. Um segundo workflow acompanha o prazo de cada demanda e avisa antes de estourar. E tudo, cada decisão da IA, das regras e das pessoas, fica numa **trilha de auditoria** que dá para consultar com SQL."

- Mostrar rapidamente `select etapa, ator from eventos_demanda where protocolo = '...'`.

## 3:40–4:00 · O ganho (câmera + números)

> "O ganho: no cenário da Vértice, com cerca de 1.200 demandas por mês e 6 minutos de esforço em cada uma, são 120 horas mensais. Com a automação, estimo cerca de 30: uma redução de uns **75%**, com protocolo e primeira resposta em segundos. E o mais importante: a IA assume o repetitivo, e as pessoas ficam com as decisões que realmente precisam delas. Obrigado!"

<!-- Se rodou com demandas reais, troque a estimativa pelo número medido: select * from v_kpis; (percentual resolvido por IA, com aprovação humana, segundos até a triagem). Deixe claro na fala que 75% é uma estimativa do cenário. -->

---

## Dicas de edição

- Corte as esperas (IA pensando, e-mail chegando) acelerando 2x ou emendando.
- Deixe o **Telegram e o canvas** com mais tempo de tela do que o código: o avaliador precisa *ver* a pausa humana acontecendo.
- Legenda curta nos momentos-chave: "IA classifica", "Regra decide", "Humano aprova", "Ação executada".
- Se passar de 4 minutos, corte primeiro a seção de confiabilidade (3:15–3:40) para uma frase.
