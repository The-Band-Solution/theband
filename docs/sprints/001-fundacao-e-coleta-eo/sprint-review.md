# Sprint Review 001 — Fundação e coleta EO

**Encerrado em**: 2026-08-09
**Backlog**: [sprint-backlog.md](sprint-backlog.md)

Separa o que foi entregue do que não foi. Nada aqui é marcado como pronto sem
evidência — saída de comando, número conferido contra a origem, ou tela
renderizada.

## Resultado por user story

A coluna `Aceito` é **derivada** do [registro de aceitação](aceitacao.md), nunca
preenchida direto. Review sem registro de aceitação é afirmação sem prova.

| # | User story | Entregável | Aceito | Onde |
|---|---|---|---|---|
| US1 | Conectar ferramenta com credencial protegida | D01 | **sim**, na reavaliação | [aceitacao.md](aceitacao.md) — não aceito na primeira avaliação por falha em AC4; corrigido por [#88](https://github.com/The-Band-Solution/theband/issues/88) |
| US2 | Conhecer pessoas e equipes | D02 | sim | [aceitacao.md](aceitacao.md) — com duas ressalvas registradas |
| US3 | Rastrear de onde veio cada informação | D03 | sim | [aceitacao.md](aceitacao.md) |

**Entregável do sprint**: composto de D01, D02 e D03 — depois da correção. Na
primeira avaliação era composto só de D02 e D03, e o registro guarda os dois
momentos: um sprint que precisou de correção para ficar completo é diferente de um
que nasceu completo.

**Tarefas executadas sem sucesso**: T033 e T038. Permanecem assim — foram
executadas e não produziram entregável aceito, e é isso que a medida
`rework.not_accepted_deliverable_ratio` calcula. #88 é tarefa nova, não
reabertura.

## Evidência da coleta real

Executada contra a organização `The-Band-Solution` pelo mesmo caminho que a tela
dispara — `Ingestion.start_sync/2` enfileira, o Oban executa.

```text
--- relatório da sincronização (FR-028) ---
  estado          completed
  coletados       16
  criados         9          (1 organização + 6 pessoas + 2 equipes)
  atualizados     0
  ignorados       0
  pendentes papel 7

--- checkpoints (FR-015, R5) ---
  github.organization           páginas=1 registros=1 cursor=nil
  github.team                   páginas=1 registros=2 cursor=nil
  github.team_member:the-band   páginas=1 registros=3 cursor=nil
  github.team_member:zeppelin   páginas=1 registros=4 cursor=nil
  github.user                   páginas=1 registros=6 cursor=nil

--- equipes e integrantes ---
  The Band (organizational_team) — 3 integrantes
      Adylla027       acesso=MEMBER      papel=pendente
      EduardoNFraiz   acesso=MEMBER      papel=pendente
      Paulo           acesso=MAINTAINER  papel=pendente
  Zeppelin (organizational_team) — 4 integrantes
      Felipe Becalli T.  acesso=MEMBER      papel=pendente
      Luma               acesso=MEMBER      papel=pendente
      Paulo              acesso=MAINTAINER  papel=pendente
      Sofia              acesso=MEMBER      papel=pendente
```

## Critérios de sucesso, um a um

| # | Critério | Situação | Evidência |
|---|---|---|---|
| SC-001 | Conectar e validar em menos de 2 minutos, sem documentação | **atendido** | formulário de uma tela, com validação imediata e mensagem do que faltou |
| SC-002 | 100% das pessoas e equipes da origem registradas | **atendido** | 6 pessoas e 2 equipes, conferidos contra a organização real |
| SC-003 | Segunda sincronização cria 0 e altera 0 | **atendido** | segunda execução: `criados 0`, `atualizados 0`, contagens inalteradas |
| SC-004 | 100% dos registros exibem origem, identificador e data | **atendido** | colunas presentes em `/pessoas` e `/equipes` para todas as linhas |
| SC-005 | Credencial não recuperável em forma utilizável | **atendido** | token ausente do HTML das 4 telas; banco devolve `AES.GCM.V1$…`; `inspect/1` redigido |
| SC-006 | Retomada consulta no máximo uma página a mais | **atendido** | teste de retomada: com checkpoint gravado, a execução seguinte pede a página **seguinte** (`after: cursor-1`), não a primeira |
| SC-007 | Correção de mapeamento aplicada sem consultar a origem | **atendido** | `SemanticIntegration.reprocess_mappings/2` sobre 32 payloads preservados: 0 criados, 0 atualizados, 32 sem mudança. O teste roda **sem expectativa no Mox da borda HTTP**, então qualquer chamada à origem o derruba |
| SC-008 | Usuário de uma organização não vê dado de outra | **atendido** | dois tenants povoados; sessão da `outra-org` mostra 0 pessoas e 0 equipes |
| SC-009 | Organização com 100 pessoas e 20 equipes conclui sem intervenção | **parcial** | o comportamento sob rate limit é testado com janela simulada: a coleta devolve `{:snooze, n}`, preserva o cursor e **não** falha. O volume de 100 pessoas não foi exercitado — a organização disponível tem 6 |
| SC-010 | Vínculos pendentes de papel apresentados explicitamente | **atendido** | `7` no relatório da sincronização e no cabeçalho de `/equipes` |

## Quality gates

| Gate | Resultado |
|---|---|
| `mix format --check-formatted` | passou |
| `mix compile --warnings-as-errors` | passou |
| `mix credo --strict` | passou — `found no issues` |
| `mix dialyzer` | passou — `Total errors: 0` |
| `mix test` | passou — **81 testes** |
| `mix knowledge.validate` | passou — 84 artefatos |
| `mix knowledge.graph` | passou — 24 módulos, dependências íntegras |
| `scripts/validate_knowledge_base.py` | passou — base válida |

## O que **não** foi entregue

Declarado explicitamente. Nenhum destes está marcado como pronto em lugar nenhum.

| Item | Tarefas | Por quê |
|---|---|---|
| **Autenticação com senha** | — | A sessão é aberta por escolha de usuário, sem senha. O que está implementado é o **escopo por tenant**, que atravessa toda consulta e é testado com dois tenants percorrendo a interface. Autenticação é feature própria, e não foi silenciosamente incorporada a esta |
| **Volume de SC-009** | — | O comportamento sob rate limit é testado; o volume de 100 pessoas e 20 equipes exigiria uma organização que não temos |
| **`mix knowledge.test`, `knowledge.docs`, `knowledge.information_model`** | — | Continuam como scripts Python, chamados pelo CI. Dívida declarada no plan.md |
| **`Estimate` das issues** | — | Nenhuma estimativa foi feita com o time. Preencher com número inventado produziria métrica de fluxo apoiada em ficção |
| **Revisão independente do PR** | T073 | A constituição exige revisor diferente de quem implementou. **Esta condição não foi satisfeita** e não pode ser marcada como cumprida por quem escreveu o código. O PR foi aberto no sprint 002, o que torna a revisão possível — não a substitui |
| **Ocorrência real de três verificações** | — | Automação classificada, pausa por limite de uso e ausência-não-é-remoção estão provadas por teste, não por ocorrência. A última exigiria remover alguém de uma equipe real na organização da pessoa mantenedora, e isso não deve ser feito para validar software |

## Correção após o `/speckit-analyze`

O `/speckit-analyze` rodado ao fim do sprint encontrou dois CRITICAL e dois HIGH.
Três foram corrigidos ainda neste sprint; o quarto é procedimento e permanece
aberto.

| Achado | O que era | Resolução |
|---|---|---|
| **G1** — FR-017 sem tarefa de implementação | só existia o teste (T060); `RawData.list_for_reprocessing/2` não tinha chamador | contrato [reprocessing.md](../../../specs/001-github-eo-ingestion/contracts/reprocessing.md) escrito **antes** do código, T060a–T060c acrescentadas, `TheBand.SemanticIntegration` + worker Oban + botão em `/sincronizacoes` implementados, 8 testes |
| **C1** — assinatura divergente | o contrato pedia lista de ids; o código recebe `DateTime` | contrato corrigido: a plataforma não recebe evento de remoção, ela percebe a ausência por comparação entre coletas — quem chama não teria como saber quais vínculos sumiram |
| **C2** — `opts` divergentes | contrato prometia `:order_by`, ausente no código; `:only_observed` existia sem estar no contrato | contrato corrigido com tabela por opção, e `:order_by` removido: ordenação parametrizável reintroduziria a divergência entre `list_*` e `count_*` que a regra existe para impedir |
| **G2** — revisão independente | não satisfeita | **continua aberta**; nenhum entregável pode ser aceito sem ela |

Uma terceira correção de contrato apareceu durante a implementação: o contrato de
reprocessamento prometia `{:error, {:unknown_mapping, id}}` **e** dizia que um
mapeamento quebrado não derruba o lote. Contradizia a si mesmo. Prevaleceu a
segunda regra — derrubar o lote por um registro tornaria a correção refém do pior
dado da base, o oposto do que FR-017 existe para permitir.

**Prática que passa a valer**: o contrato da API é escrito antes da primeira
função pública, e corrigido no mesmo commit quando a implementação mostra que ele
errou. Registrado em `AGENTS.md` §12 e na constituição, princípio VI, por emenda
1.1.0.

## Segunda rodada de correções

Depois do `/speckit-analyze`, os pendentes que sobraram foram fechados.

| Item | Resolução |
|---|---|
| Rotação da chave mestra (FR-005b) | contrato [credential-rotation.md](../../../specs/001-github-eo-ingestion/contracts/credential-rotation.md) escrito antes, e `mix the_band.rotate_key` implementada. Verificada de ponta a ponta: rótulo do valor cifrado mudou de `1ff8e241` para `1ddcd36a`, segredo intacto com a chave nova |
| Teste de retomada (SC-006) | com checkpoint gravado, a execução pede `after: cursor-1` — a página seguinte, não a primeira |
| Teste de rate limit (SC-009) | janela simulada apertada devolve `{:snooze, n}`, preserva cursor, não falha |
| Testes de interface | 9 testes de LiveView, incluindo os três que **não** são fazíveis por teste unitário: segredo ausente do HTML, isolamento percorrendo a interface, e cabeçalho concordando com a listagem |
| Base de conhecimento e o campo `email` | o mapeamento declarava um atributo que a consulta deixou de pedir. Agora está registrado como limitação, com a razão — o campo exigiria escopo `read:user`, mais amplo do que a coleta precisa |
| Redação de T005 e T019 | as tarefas prometiam mais do que foi entregue; corrigidas para descrever o que de fato cobrem |

### Um defeito sério encontrado ao testar a rotação

A rotação **não funcionava**, e teria falhado em silêncio. Os dois ciphers — o da
chave nova e o da antiga — usavam rótulos fixos, e o Cloak escolhe qual chave usar
pelo rótulo gravado no início do valor cifrado. Com rótulos que não identificavam
a chave, ele escolhia pela ordem da configuração e usava a errada.

O sintoma seria "não consigo decifrar esta credencial", sem dizer por quê, e só
no momento de usá-la — no meio de uma coleta.

A correção deriva o rótulo da **própria chave**, por oito caracteres do SHA-256:
cada valor cifrado passa a carregar qual chave o cifrou, as duas convivem sem
ambiguidade durante a rotação, e depois dela os registros novos já apontam para a
nova. Coberto por `test/the_band/vault_test.exs`.

Isso só apareceu porque a rotação foi **executada**, não apenas implementada.

## Defeitos encontrados durante o sprint

Todos corrigidos, e cada um virou lição.

| Defeito | Onde apareceu | Correção |
|---|---|---|
| Gerador sobrescreveu `AGENTS.md` | `mix phx.new` em diretório povoado | restaurado do git; virou [L01](../licoes-aprendidas.md) |
| Coleta executada em dobro | script chamando `perform/1` com o servidor no ar | script passou a usar o caminho real; [L02](../licoes-aprendidas.md) |
| Proveniência ausente derrubava a query | `find_by_application_reference/3` comparando com `nil` | validação antes da consulta; [L03](../licoes-aprendidas.md) |
| `INSUFFICIENT_SCOPES` por campo opcional | `email` nas queries GraphQL exige `read:user` | campo removido; [L04](../licoes-aprendidas.md) |
| Erro real trocado por erro de banco | `syncs.error_reason` em `varchar(255)` | coluna virou `text`; [L05](../licoes-aprendidas.md) |
| Arquivos escritos no diretório errado | `cd` persistindo entre comandos | caminhos absolutos; [L06](../licoes-aprendidas.md) |
| Struct devolvido sem `id` | `autogenerate: false` em chave `binary_id` | `autogenerate: true`; [L07](../licoes-aprendidas.md) |
| Validador rejeitava todos os mapeamentos | proveniência tem duas formas na base, e o código só conhecia uma | `provenance_problems/1` por tipo de artefato |
| Bug de YAML preexistente | `flow_wip_count.yaml` com `: ` sem aspas virava mapa | item entre aspas |

## Divergências entre artefatos, resolvidas

| # | Divergência | Resolução |
|---|---|---|
| D-1 | research.md R7 chamava a tabela de `eo_observed_team_links`; a regra da base declara `team_membership_evidence` | prevaleceu a base de conhecimento: `eo_team_membership_evidence` |
| D-2 | R7 acrescenta colunas que a regra não nomeia | as duas se somam; a evidência guarda chaves internas **e** identificadores externos |
| — | research.md R1 fixou PostgreSQL 16; o ambiente roda 17 | `compose.yaml` alinhado ao 17, com a razão escrita no próprio arquivo |
| — | spec usa P1/P2/P3; o projeto oferece P0/P1/P2 | ordem preservada, rótulo remapeado, registrado no backlog |

## Estado das issues

Atualizado em 2026-08-10, depois do [registro de aceitação](aceitacao.md).

| Situação | Issues |
|---|---|
| encerradas, com entregável aceito | #1 a #76 e #88 — 75 no total |
| fechada como `not planned` | #2 — duplicata órfã da US1, criada por uma execução do script de materialização que falhou depois de a issue já existir |
| encerrada com limitação declarada | #77 — evidência do quickstart; V3, V4 e V8 provados por teste e não por ocorrência real |
| concluída no sprint 002 | #78 — abertura do pull request, T073. [PR #89](https://github.com/The-Band-Solution/theband/pull/89). Ver a [herança](../002-escopo-por-organizacao/sprint-backlog.md) |

**O fechamento das issues não substitui a revisão independente.** São perguntas
diferentes: a issue fecha quando a tarefa foi executada e o entregável aceito; a
revisão pergunta se o código está correto, seguro e conforme, e o princípio VII
exige que quem responda não seja quem implementou. O pull request existe e a
revisão continua **pendente** — nada da 001 entra na `main` antes dela.
