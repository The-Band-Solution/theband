# Sprint 033 — Registro de aceitação

**Feature**: [061 — a API pública com token de acesso](../../../specs/061-api-publica/spec.md)

**Avaliado em**: 2026-09-23, na `development` depois dos merges de #933, #934, #935 e #936,
com **evidência executada nesta avaliação** — 149 testes dos arquivos da 061, mais sete
medições escritas e rodadas de propósito para os critérios que nenhum teste nomeado cobria.

**Papel**: Product Owner. A versão da release foi decidida pelo agente no papel
`sro.product_owner_role`; **esta avaliação de critérios foi feita pelo agente que
implementou** — ver a exceção ao fim.

**Regra**: `sro.rule03` — a fase decorre dos critérios, com evidência executada. **Critério
sem evidência não vira aceito.**

## Resumo

| | Quantidade |
|---|---:|
| Critérios da spec | 15 |
| **Conformes** | **13** |
| **Não conformes** | **2** — SC-004 e SC-007 |
| Testes executados nos arquivos da 061 | 149, todos passando |
| Medições escritas para esta avaliação | 7 |

**As duas recusas têm naturezas diferentes.** A do SC-007 é **escopo**: a proveniência de
medida foi desenhada para o servidor MCP (feature 062) e não chegou à API. A do SC-004 é um
**defeito pequeno e localizado**: a informação existe e é descartada uma linha antes de
chegar ao log.

---

## Os quinze, um a um

| # | Critério | Veredito | Evidência |
|---|---|---|---|
| **SC-001** | 0 ocorrências do valor em claro em log, resposta, página e banco | **conforme** | `test/the_band_web/api/segredo_nao_vaza_test.exs` — quatro varreduras, e o alvo é o **segredo isolado**, não o valor inteiro: o id público está no banco por desenho, e varrer pelo valor completo passaria com o segredo guardado sozinho |
| **SC-002** | 0 identificadores do tenant B na resposta do tenant A | **conforme** | `isolamento_por_tenant_test.exs` — e a guarda do mecanismo: **toda consulta de domínio leva o tenant como parâmetro**, conferido por telemetria |
| **SC-003** | inexistente, revogado e expirado: respostas byte a byte idênticas | **conforme** | medido nesta avaliação: os três corpos, com o `request_id` normalizado, são **idênticos** |
| **SC-004** | 100% das recusas com o motivo real recuperável no log interno, **as três razões distintas** | **NÃO CONFORME** | medido: o log traz **duas** categorias — `sem_cabecalho` e `credencial_recusada` — e as três causas colapsam na segunda |
| **SC-005** | depois da revogação, 0 chamadas atendidas | **conforme** | medido: antes `200`; cinco chamadas depois, `401` nas cinco |
| **SC-006** | 0 métodos além de `GET` e `HEAD` | **conforme** | `somente_leitura_test.exs` — percorre a **tabela de rotas**, não uma lista à mão; rota nova sem recusa reprova |
| **SC-007** | 100% dos objetos de medida com proveniência e limitações declaradas | **NÃO CONFORME** | medido: `/teams/:id/measures` devolve `window`, `work`, `time_to_first_review`, `skills` e `open_by_person` — **nenhuma** chave de proveniência ou de limitações da base |
| **SC-008** | 0 campos onde *não observado* e *zero medido* sejam indistinguíveis | **conforme** | `person_detail_test.exs` — `competencies: null` (não houve leitura) contra `[]` (houve, e nada demonstrado); e `median_hours: null` contra zero |
| **SC-009** | percorrer mais de três páginas devolve cada item exatamente uma vez | **conforme** | `person_controller_test.exs` — 80 pessoas, 8 páginas, 80 ids distintos |
| **SC-010** | 100% dos endpoints na descrição OpenAPI; endpoint sem descrição falha o CI | **conforme** | `team_controller_test.exs` compara a descrição com a **tabela de rotas**. Reprovou de verdade quando `/people/:id` entrou, e foi corrigido |
| **SC-011** | sob limite excedido por um token, outro recebe `200` | **conforme** | `registro_e_limite_test.exs` — a contagem é por token, e um não gasta o limite do outro |
| **SC-012** | 0 linhas de token removidas fisicamente, incluindo revogação | **conforme** | medido: uma linha antes, uma depois da revogação |
| **SC-013** | a tela de tokens traz estado e último uso, sem valor nem hash | **conforme** | medido sobre o HTML renderizado: estado presente, último uso presente, valor ausente, hash ausente |
| **SC-014** | recusa por escopo devolve `404` e não `403` | **conforme** | `team_detail_test.exs` e `person_detail_test.exs` — fora do alcance e inexistente devolvem a **mesma** resposta |
| **SC-015** | 0 endpoints em `/api/v1` fora da lista da FR-021 | **conforme** | medido: 8 rotas `GET`, nenhuma fora |

---

## SC-004 — a causa, e por que é pequena

`TheBand.Tenants.ApiTokens.autenticar/1` colapsa as causas num `else` único:

```elixir
with {:ok, id_publico, segredo} <- partes(valor),
     %Token{} = token <- por_id_publico(id_publico),
     true <- confere?(token, segredo),
     :ativo <- Token.estado(token, agora()) do
  {:ok, carimbar(token)}
else
  _ -> {:error, :recusado}
end
```

**A informação existe e é descartada.** `Token.estado/2` já calcula `:ativo`, `:revogado` ou
`:expirado`; o `_` do `else` a joga fora, e o plug registra `motivo=credencial_recusada` para
as três.

**A resposta ao cliente está certa e deve continuar igual** — é o SC-003, e distinguir as
três lá confirmaria a quem testa credencial roubada que ela existiu. O que falta é a
distinção **no log interno**, que é onde ela serve.

**Conserto**: devolver `{:error, :inexistente | :revogado | :expirado | :recusado}` e passar o
motivo ao `Logger.warning` que já existe. A resposta HTTP não muda.

## SC-007 — escopo, e não defeito

A proveniência de medida — valor, composição, janela, origem, id e versão da regra,
`limitations` e `misinterpretations` lidas da base de conhecimento — foi **desenhada para o
servidor MCP**, na feature [062](../../../specs/062-servidor-mcp/data-model.md), e o envelope
está especificado lá.

A API entrega o que **a tela** entrega: notas escritas no controlador, e a janela declarada em
`window`. São honestas, e não são o que o SC-007 pede.

**Isto não é conserto de uma linha.** Exige a função pública `KnowledgeBase.measurement/1`,
que não existe — é a tarefa T003 da 062 —, e depois o envelope em cada medida da API.

---

## A exceção, declarada

**Esta avaliação foi feita por quem implementou.** O papel Product Owner decidiu a versão da
release; a conferência critério a critério foi minha, e vale menos exatamente onde mais
importaria.

**E não houve revisão independente** do desenho da API nem da avaliação de segurança que
originou o #936. Quatro tentativas por agente falharam em 21 e 22 de setembro de 2026 — duas
travaram sem escrever nada, duas foram recusadas por indisponibilidade da ferramenta.

**Nenhum merge cumpre isso.** Classificação correta: *revisão não ocorreu*.

---

## O veredito

**A feature 061 é aceita com duas ressalvas escritas.**

Treze de quinze critérios conformes, com evidência executada. Os dois que faltam não impedem
a entrega e **não devem ser esquecidos**:

- **SC-004** vira item de backlog: defeito pequeno, conserto localizado, sem mudança na
  resposta ao cliente;
- **SC-007** vira dependência declarada da feature 062: a proveniência de medida nasce lá, e
  quando nascer a API pode passar a usá-la.

Aceitar com ressalva escrita é diferente de aceitar em silêncio. O que fica de fora fica
**nomeado**.
