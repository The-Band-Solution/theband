# Sprint Review 001 — Fundação e coleta EO

**Encerrado em**: 2026-08-09
**Backlog**: [sprint-backlog.md](sprint-backlog.md)

Separa o que foi entregue do que não foi. Nada aqui é marcado como pronto sem
evidência — saída de comando, número conferido contra a origem, ou tela
renderizada.

## Resultado por user story

| # | User story | Situação | Evidência |
|---|---|---|---|
| US1 | Conectar ferramenta com credencial protegida | **entregue** | tela `/ferramentas` funcionando; credencial validada contra o GitHub antes de gravar; segredo cifrado no banco |
| US2 | Conhecer pessoas e equipes | **entregue** | coleta real contra `The-Band-Solution`: 6 pessoas, 2 equipes, 7 vínculos observados |
| US3 | Rastrear de onde veio cada informação | **entregue** | telas `/pessoas`, `/equipes` e `/equipes/:id` exibindo origem, identificador externo e data de coleta |

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
| SC-006 | Retomada consulta no máximo uma página a mais | **parcial** | o mecanismo está implementado e o cursor é gravado depois da página; **não foi executado** um teste de interrupção real |
| SC-007 | Correção de mapeamento aplicada sem consultar a origem | **não verificado** | `raw_payloads` guarda payload, `mapping_id` e `mapping_version`; o fluxo de reprocessamento **não foi implementado** |
| SC-008 | Usuário de uma organização não vê dado de outra | **atendido** | dois tenants povoados; sessão da `outra-org` mostra 0 pessoas e 0 equipes |
| SC-009 | Organização com 100 pessoas e 20 equipes conclui sem intervenção | **não verificado** | a organização disponível tem 6 pessoas e 2 equipes; o rate limit não foi atingido |
| SC-010 | Vínculos pendentes de papel apresentados explicitamente | **atendido** | `7` no relatório da sincronização e no cabeçalho de `/equipes` |

## Quality gates

| Gate | Resultado |
|---|---|
| `mix format --check-formatted` | passou |
| `mix compile --warnings-as-errors` | passou |
| `mix credo --strict` | passou — `found no issues` |
| `mix dialyzer` | passou — `Total errors: 0` |
| `mix test` | passou — **38 testes** |
| `mix knowledge.validate` | passou — 84 artefatos |
| `mix knowledge.graph` | passou — 24 módulos, dependências íntegras |
| `scripts/validate_knowledge_base.py` | passou — base válida |

## O que **não** foi entregue

Declarado explicitamente. Nenhum destes está marcado como pronto em lugar nenhum.

| Item | Tarefas | Por quê |
|---|---|---|
| **Autenticação com senha** | — | A sessão é aberta por escolha de usuário, sem senha. O que está implementado é o **escopo por tenant**, que atravessa toda consulta e é testado com dois tenants. Autenticação é feature própria |
| **Reprocessamento de mapeamento corrigido (FR-017, SC-007)** | T060 | O payload bruto e o `mapping_id` são preservados, mas não existe o comando que relê e reaplica |
| **Teste de retomada após interrupção (SC-006)** | T058 | O mecanismo existe; o teste que o exercita, não |
| **Teste de rate limit (SC-009)** | T059 | A pausa preventiva está implementada e é agendamento Oban, não `Process.sleep`; falta o teste com janela simulada |
| **`mix knowledge.test`, `knowledge.docs`, `knowledge.information_model`** | — | Continuam como scripts Python, chamados pelo CI. Dívida declarada no plan.md |
| **Rotação da chave mestra (FR-005b)** | T017 | O `Cloak` suporta chave aposentada e o código a lê; a Mix task de recifragem não foi escrita |
| **Testes de interface (LiveView)** | T040, T068 | As telas foram verificadas por execução HTTP real, não por teste automatizado |
| **`Estimate` das issues** | — | Nenhuma estimativa foi feita com o time. Preencher com número inventado produziria métrica de fluxo apoiada em ficção |
| **Revisão independente do PR** | T073 | A constituição exige revisor diferente de quem implementou. **Esta condição não foi satisfeita** e não pode ser marcada como cumprida por quem escreveu o código |

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

As 77 issues permanecem **abertas**. Fechá-las exige a revisão independente que a
constituição impõe, e marcá-las como concluídas sem esse passo seria declarar
sucesso sem evidência — proibido pelo princípio VII.

A issue #2 foi fechada como `not planned`: duplicata órfã da US1, criada por uma
execução do script de materialização que falhou depois de a issue já existir.
