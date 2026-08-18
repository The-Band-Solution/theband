# Feature 032 — A coleta das mudanças: solicitações, commits e o rastreio

**Criada**: 2026-08-18 · **Origem**: pedido da pessoa mantenedora ("rastreio da issue, com
commit e PR, quem fez") · **Depende de**: as relações declaradas em
`cmpo.change_traceability` e `sro.scope_traceability` (PR #427, mergeado)

## O propósito

A rede já sabe representar quem pediu, quem integrou e quem fez — as relações foram
declaradas. **Falta o dado.** Nenhuma tabela de PR ou commit existe, e por isso a pergunta
"quem fez esta issue acontecer?" não tem tela.

Esta feature coleta as duas entidades e entrega o rastreio nas telas onde ele é procurado:
da issue para quem a implementou, e da pessoa para o que ela mudou.

## O que o dado real exige do desenho

Medido em 2026-08-18, na organização do piloto: **121 repositórios**, e os quatro maiores
somam **822 PRs e 1.202 commits** — um deles tem 365 PRs sozinho. Extrapolando, a ordem de
grandeza é de **milhares de PRs e dezenas de milhares de commits**, contra os 5.032 issues e
2.013 comentários já coletados.

Três consequências, e elas são a espinha do plano:

1. **Coleta incremental obrigatória desde a primeira versão.** Percorrer tudo a cada
   sincronização não termina em tempo útil.
2. **O commit é o volume, e o PR é o valor.** O rastreio atravessa o PR; o commit
   isolado interessa por autoria. Coletar commits **através do PR** (não a história
   inteira do repositório) reduz o volume e mantém o rastro — a limitação é que commit
   fora de PR fica de fora, e ela vai declarada.
3. **Autoria é plural.** Todo commit deste repositório tem dois autores (`Co-Authored-By`),
   e a relação declarada tem cardinalidade `many` na origem exatamente por isso.

## User stories

**US1 (P1)** — Como quem lê uma issue, quero ver **quais solicitações de mudança a
atenderam**, com quem abriu e quem integrou, para saber se o trabalho existe e quem o fez.

**US2 (P1)** — Como quem lê a página de uma pessoa, quero ver **o que ela mudou**: as
solicitações que abriu, as que integrou e os commits que executou — inclusive os commits em
que ela é co-autora.

**US3 (P2)** — Como quem lê uma solicitação de mudança, quero ver **os commits que a
realizaram e as issues que ela atende**, fechando o rastro nos dois sentidos.

## Functional requirements

- **FR-001**: A coleta MUST trazer as solicitações de mudança (PRs) dos repositórios
  observados, incremental por `updatedAt` desde a última passada, com proveniência e
  `raw_payload` preservados.
- **FR-002**: Cada solicitação MUST registrar quem a submeteu e quem a integrou como
  vínculos distintos — materializando `cmpo.stakeholder_submitted_change_request` e
  `cmpo.stakeholder_performed_checkin`. A regra dos designados vale: login sempre,
  pessoa só quando coletada.
- **FR-003**: O vínculo com o item de escopo MUST vir de `closingIssuesReferences` — o
  que a origem **reconheceu**, nunca o que o texto do PR parece dizer. Menção sem closing
  keyword MUST NOT virar atendimento.
- **FR-004**: A coleta MUST trazer os commits **de cada solicitação**, com **todos** os
  autores (`authors`, plural), materializando `cmpo.stakeholder_performed_commit` e
  `cmpo.commit_accomplished_change_request`.
- **FR-005**: Solicitação e commit MUST seguir a marca da casa: sumiço é
  `no_longer_observed_at`, nunca DELETE.
- **FR-006**: O detalhe da issue MUST mostrar as solicitações que a atendem — número,
  título, estado, quem abriu, quem integrou, quando. Issue sem solicitação MUST distinguir
  **"nenhuma coletada ainda"** de **"nenhuma atende esta issue"**.
- **FR-007**: A página da pessoa MUST mostrar o que ela mudou, em três leituras distintas
  e nunca somadas: solicitações **abertas**, solicitações **integradas**, commits
  **executados** (com a marca de co-autoria quando houver).
- **FR-008**: O detalhe da solicitação MUST existir como tela própria (`/work/changes/:id`)
  com os commits que a realizaram e as issues que ela atende.
- **FR-009**: Toda tela MUST marcar como **derivado** o que é derivado: o vínculo
  commit→escopo por menção de texto (regra `github.commit_issue_mention`, confiança baixa)
  MUST aparecer distinto do vínculo estrutural.
- **FR-010**: A coleta MUST registrar cobertura na fase de sincronização: solicitações
  visitadas, commits coletados, marcados como não mais observados, truncados.

## Success criteria

- **SC-001**: A coleta termina no tenant real e os totais batem com a origem, conferidos
  por amostra contra a API — nunca pela suíte.
- **SC-002**: O rastreio completo aparece na tela para um caso real: uma issue mostra o PR
  que a atendeu, o PR mostra os commits, e cada commit mostra os autores — incluindo os
  co-autores.
- **SC-003**: Nenhuma consulta por linha. O detalhe da issue, o da solicitação e a página
  da pessoa somam número fixo de consultas, provado pelo contador único, e o teto de custo
  de cada tela sobe com o acréscimo **nomeado**.
- **SC-004**: Pessoa que aparece como co-autora de commits sem ter aberto nenhum PR é
  encontrável — a autoria plural não é achatada.

## Fora do escopo (declarado, não silenciado)

- **Commits fora de solicitação** (push direto na branch de destino): a coleta os alcança
  só se percorrer a história do repositório, o que multiplica o volume. Ficam de fora
  nesta versão, e a tela **diz isso** — a relação declarada tem `zero_or_one` no destino
  justamente para representá-los quando forem coletados.
- **Revisões de PR** (approvals, review threads): outra atividade
  (`cmpo.change_control`), com âncora em código.
- **Conflitos** (`cmpo.conflict`, `cmpo.resolve_conflict`): a API expõe `mergeable`, que é
  o estado de agora, não o histórico.
- **`cmpo.artifact_copy`** (a cópia versionada de cada arquivo): exigiria o diff por
  commit, e nada o consome.
- **CI** (workflow runs/jobs): mapeamento já escrito, feature separada (#401).
