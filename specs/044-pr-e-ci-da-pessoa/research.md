# Research: os três papéis e a verificação, na página da pessoa

**Feature**: 044 · **Date**: 2026-08-27

Três perguntas precisaram de resposta antes do desenho. As três foram respondidas por
**medição no banco de desenvolvimento**, e nenhuma sobrou como `NEEDS CLARIFICATION`.

---

## R1 — A revisão é coletada?

**Decision**: sim, e por inteiro. Nada a coletar, nada a recoletar.

**Rationale**: medido em 2026-08-27.

    collected_artifact_evaluations ..... 4.233 registros
      APPROVED ......................... 3.379
      COMMENTED ........................   508
      CHANGES_REQUESTED ................   294
      DISMISSED ........................    52
      PENDING ..........................     0

    com pessoa identificada ............ 4.127 (97,5%)
    autor Bot ..........................    85

`priv/connectors/github/queries/change_requests.graphql` já pede `reviews(first:
$review_size)` com `state`, `submittedAt`, `bodyText` e `author.__typename`.
`TheBand.Quality.by_reviewer/2` já agrega por revisor.

`PENDING` não aparece porque a API do GitHub só devolve rascunho para quem o escreveu — e
a coleta usa credencial de aplicação, não da pessoa.

**Alternatives considered**:

- *Coletar as revisões numa consulta própria*: recusada. Elas já vêm junto da solicitação,
  e custam zero requisição a mais — foi a decisão registrada no próprio arquivo `.graphql`.
- *Recoletar para preencher*: recusada **depois de aprovada**. A aprovação foi pedida sob
  a premissa errada de que faltava dado. Repaginar 5.635 solicitações em 160 repositórios
  não traria nada, e a spec registra a recusa em FR-014.

**A lição, e ela custou duas versões da spec**: a primeira declarou a revisão como lacuna
sem dado; a segunda planejou coletar o que já era coletado. As duas por não procurar antes
de propor. O caminho de busca que teria evitado as duas:

    ontologia → o conceito existe?        qapo.evaluation_participation, issue #440
    mapeamento → está declarado?          github.pull_request_review.to.qapo..., v2
    fachada de domínio → há leitura?      TheBand.Quality.by_reviewer/2
    banco → tem linha?                    4.233

---

## R2 — Os nove números cabem no teto de consultas?

**Decision**: sim, em **duas** consultas agregadas. O teto sobe de 23 para 25.

**Rationale**: medido, com os dois agregados escritos e executados contra o banco real,
para `vinicius-je`:

    consulta 1 — solicitações e vereditos ....... 25ms
      abriu 793 · integrou 844 · revisou 627
      endossou 634 · objetou 57 · absteve 30

    consulta 2 — verificação dos commits ........ 42ms
      passou 985 · quebrou 79 · outras 6

`filter (where ...)` do Postgres é o que permite seis contagens numa passagem. É o mesmo
recurso que a #369 usou para a cobertura do elo, e que `flow_throughput` usa para separar
tarefa bem-sucedida de malsucedida.

**Alternatives considered**:

- *Nove consultas, uma por número*: recusada. Levaria a página a 32 por render, e o
  teste-guarda reprova em 24.
- *Derivar dos assigns já carregados*: **impossível**, e verificado. Nenhuma consulta da
  página toca `collected_change_requests` nem `collected_artifact_evaluations`. Foi a
  primeira saída tentada, porque é o que o teste-guarda manda tentar antes de subir o teto.
- *Uma consulta só para os nove*: recusada. A verificação exige três junções que a
  solicitação não usa, e juntá-las produziria produto cartesiano — a contagem de
  solicitações seria multiplicada pelo número de execuções de CI.

---

## R3 — Onde a tradução do estado para conceito da rede acontece?

**Decision**: **na leitura**, a partir do `value_map` do mapeamento. Nenhuma coluna nova.

**Rationale**: o `value_map` é dado da base de conhecimento, carregado no boot. Ele pode
mudar — um forjador novo, um estado novo —, e materializar a tradução criaria uma segunda
cópia que diverge da primeira sem ninguém ver.

É a mesma decisão que a #514 tomou para o papel do campo de iteração e a #368 para a
origem do prazo: **resolve na leitura, nunca materializa**. A #514 mediu o que isso
poupou — 27 iterações de trimestre que teriam exigido migração.

O valor cru continua em `collected_artifact_evaluations.state`, e é o que permite conferir
a tradução depois.

**Alternatives considered**:

- *Coluna `verdict` preenchida na ingestão*: recusada. Mudar o mapa exigiria migração de
  4.233 linhas, e a janela entre gravado e declarado é exatamente o defeito.
- *Traduzir na tela, por `case`*: recusada. Espalharia o mapa por cada uso, e o segundo
  uso divergiria do primeiro. Um módulo `TheBand.Quality.Verdict` é o lugar único.

---

## O que NÃO precisou de pesquisa

- **A ligação commit → verificação**: `sha` = `head_sha`, e já medida em 8.358 de 15.671.
- **A separação bot/pessoa**: `author_type` já é gravado, e o mapeamento já exigia.
- **A regra de visibilidade**: a #369 resolveu, e esta feature vive dentro dela.
