# Plano de implementação: a definição de pronto declarada pela organização

**Feature**: [066](spec.md) · **Branch**: `066-pronto-declarado-impl` · **Criado**: 2026-09-15
**Protótipo aprovado**: [`prototipo/board-declarations.html`](prototipo/board-declarations.html)
— cartão **B**, *What each column means*. A régua do QA é a seção 3 do
[`prototipo/PROMPT.md`](prototipo/PROMPT.md).

## O escopo desta fatia

**US1** (declarar o que cada coluna significa) e **US2** (as duas afirmações lado a lado no
detalhe e na listagem). É a fatia vertical mínima: sem a US1 não há declaração; sem a US2 a
declaração não aparece em lugar nenhum — infraestrutura sem consumidor, que a casa recusa.

**Fora desta fatia, e por quê**: os períodos de estágio (FR-024/025) precisam dos eventos de
mudança, que são leitura nova e grande; a escolha da definição que alimenta as medidas
(FR-016/017/019) toca burn, throughput e previsão de uma vez; o desacordo por pessoa (parte da
FR-013) e o *em andamento* no painel (FR-020) são consumidores a mais da mesma leitura, e cabem
na fatia seguinte sem mudar nada do que esta entrega.

## Contexto técnico

| | |
|---|---|
| Linguagem | Elixir 1.20 · Phoenix LiveView |
| Persistência | PostgreSQL via Ecto, multitenant por `tenant_id` |
| O que já existe | `project_field_definitions` com `options`; `item_field_values.raw_value` com `{"name","optionId"}`; `observed_projects`; a tela `board_live/index.ex` com dois cartões de declaração |
| O molde | `spo_activity_start_criteria` (042) e `spo_activity_deadline_criteria` (#368): declaração por quadro, autor e instante, revogar marca, índice parcial sobre os vigentes, resolução na leitura |
| Base de conhecimento | regra nova `github.project_item_status` (FR-021) e o vocabulário reconhecido de pronto (FR-004) |

**Nada a esclarecer**: a spec fechou as quatro decisões da pessoa mantenedora em 2026-09-14, e o
protótipo fechou o desenho.

## Onde o código vive, e por quê

**`lib/the_band/ontology/seon/spo/phase_declaration.ex`**, tabela
`spo_item_phase_declarations` — junto do critério de início e do de prazo, e pela mesma razão:
é **objeto social** (a mesma coluna significa coisas diferentes em organizações diferentes, e
nenhuma está errada), aponta para o quadro observado, e a plataforma registra a escolha em vez
de fazê-la.

**A leitura vive em `Projects`**, porque o que ela lê é o valor de campo de um item de quadro —
`Projects.phase_of_items/2` devolve, por item, o estágio atual e a fase declarada. O consumidor
é a tela.

## Decisões de desenho (princípio VIII)

| decisão | que problema resolve, **hoje** | o que piora |
|---|---|---|
| **Tabela nova** em vez de coluna em `item_field_values` | a declaração é da **organização sobre o vocabulário**, não do item: uma linha por opção, não por item. Coluna no item obrigaria a reescrever 1 077 linhas a cada declaração, e a apagar a anterior | mais uma junção na leitura da tela |
| **Identificador da opção** como identidade, com o nome guardado | opções são renomeáveis na origem; o mapeamento por tenant já usa id de campo pela mesma razão | duas colunas onde pareceria caber uma; a tela tem de mostrar as duas quando divergem |
| **Resolução na leitura**, nada gravado no item | é a regra da 042 (`criterion_determines_start`), e é o que faz revogar e redeclarar serem baratos | a leitura da listagem ganha uma junção agregada — medida pelo teste de custo |
| **Destino como texto do conceito** (`sro.intended_scrum_development_task`, …) e não enum no banco | conceito vive no YAML (princípio I); enum no banco congelaria a rede | valor inválido só é pego pelo changeset, não pelo banco — por isso o changeset valida contra a base |
| **A recusa é um destino** (`nao_diz_fase`) e não a ausência da linha | FR-022: recusa registrada some da lista de propostas; ausência de linha volta a propor | um valor a mais no changeset |

**Nenhum padrão novo**: é o mesmo desenho de declaração por quadro que a casa já usa duas vezes.

## Fases

**Fase 0 — a base de conhecimento**: a regra `github.project_item_status` com os destinos
admitidos, o vocabulário reconhecido de pronto, e o `does_not_materialize`. Princípio IV: nada
na tela sem declaração versionada.

**Fase 1 — a declaração**: migração, schema, comandos (declarar · revogar) e consultas
(vigentes por quadro; propostas a partir do vocabulário; contagem por opção).

**Fase 2 — a tela do quadro (US1)**: o cartão B no `board_live/index.ex`, exatamente o
protótipo.

**Fase 3 — as duas afirmações (US2)**: a leitura por item, o detalhe e a listagem.

**Fase 4 — o desacordo do quadro** (a parte da FR-013 que é do quadro) e os gates.

## Constitution Check

| princípio | como esta fatia o cumpre |
|---|---|
| **I** — domínio pelas ontologias | o destino é o id do conceito; a regra declara quais são admitidos |
| **II** — fonte externa não é domínio | o valor de `Status` continua cru; a fase é derivada na leitura |
| **III** — proveniência | autor e instante em toda declaração; revogar marca |
| **IV** — semântica em YAML versionado | fase 0 antes de qualquer código |
| **VIII** — desenho que o problema justifica | tabela acima |
| **X** — uma tela, uma coisa | cartão próprio com cabeçalho, ao lado dos dois que já existem |
| **XI** — estado conferido, sinal nunca silenciado | ausência escrita em cada caso; a recusa é estado |

**Reavaliado depois do desenho**: sem violação. A tabela nova é a terceira do mesmo molde, e o
`AGENTS.md` §7.7 já justifica o padrão.
