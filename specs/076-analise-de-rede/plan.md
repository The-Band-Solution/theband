# Implementation Plan: análise de rede

**Branch**: `feature/1309-plano` (plano) · **Spec**: [spec.md](spec.md) · **Data**: 2026-10-04 · **Épico**: [#1309](https://github.com/The-Band-Solution/theband/issues/1309)

**Pesquisa**: [research.md](research.md) · **Modelo**: [data-model.md](data-model.md) · **Contratos**: [contracts/](contracts/) · **Validação**: [quickstart.md](quickstart.md)

**Entradas que este plano referencia e não repete**: [revisao-semantica.md](revisao-semantica.md) e
[revisao-semantica-2.md](revisao-semantica-2.md) (aprova com emendas; A3 e A5 viram tarefas, A6 é
registro, A7 é decisão pendente); [seguranca.md](seguranca.md) (R1–R15, cenários A1–A22);
[proposta-base/](proposta-base/) (o conteúdo da base); [prototipo/](prototipo/) (aprovado em
2026-10-04, Q1–Q4). Fundação: a 073 em `lib/the_band/review_network/`, reaproveitada e não duplicada.

---

## Summary

Quem coordena abre **Network analysis** no menu e, para uma organização observada, escolhe a rede —
**revisão** (073) ou **designação** (autor da issue → responsável vigente) — e a janela, e lê a
análise inteira da referência: o grafo ponderado e o de comunidades, hubs pelas quatro
centralidades, distância, diâmetro, eficiência, mundo pequeno, o papel de cada pessoa e o perfil
individual, com cada defeito de cálculo da referência corrigido e com quem está fora do alcance
**agrupado e sem nome**.

O desenho:

1. o job da 073, ao gravar a leitura de revisão, encadeia um job novo, numa fila própria de
   concorrência 1, que calcula as **duas** redes nas **três** janelas e grava uma leitura vigente
   por `(organização, rede, janela)`, com impressão digital para não recalcular o que não mudou;
2. tudo é Elixir puro: Brandes, Wasserman–Faust, autovetor sobre A + I, guloso CNM com peso e
   desempate, σ contra 100 G(n, m) com gerador e semente declarados, Q_rand com os pesos reais
   sorteados, Latora–Marchiori e Fruchterman–Reingold com semente. **Sem dependência nova**;
3. **uma** função de domínio, `NetworkAnalysis.read/4`, aplica o alcance recalculado a cada chamada:
   nomes só de alcançados, agregados de ao menos 3 por comunidade, supressão complementar, hubs só
   entre alcançados, papéis de outros só com escopo concedido (DS1), nada além das medidas da rede
   para quem não alcança ninguém (DS5);
4. o SVG é renderizado no servidor, com posições do servidor; o navegador só faz zoom, arrasto e
   destaque por classe, sem receber dado.

## Technical Context

| | |
|---|---|
| **Linguagem** | Elixir ~> 1.17 (CI e imagem em 1.20.2 / OTP 29) |
| **Web** | Phoenix 1.8.11 · LiveView 1.2.9 (`mix.lock`) |
| **Persistência** | PostgreSQL 16 · Ecto SQL 3.14.0 · Postgrex 0.22.4; multitenant por `tenant_id`, `%Tenant{}` em toda consulta |
| **Jobs** | Oban 2.23.1; fila nova `:network_analysis`, concorrência 1 |
| **Base** | YAML via `yaml_elixir` 2.12.2, carregada no boot (`TheBand.Ontology.KnowledgeBase`) |
| **Aleatório** | `:rand` do OTP, `:exsss`, estado explícito (`seed_s/2`, `uniform_s/2`) — conferido no OTP 29 |
| **Hash** | `:crypto.hash(:sha256, …)` do OTP |
| **Dependência nova** | **nenhuma** ([R22](research.md#r22--nenhuma-dependência-nova-r14-da-segurança)); `mix.lock` e `assets/package.json` não mudam |
| **Testes** | ExUnit; dois tenants e duas organizações povoados; A1–A22; cinco redes de resposta conhecida (SC-002) |
| **O que verifica** | `mix gates`; o veredito é o código de saída |
| **Escala medida** | desenvolvimento, 2026-10-04: designação 54 pessoas, 155 arestas, 2 906 issues em 180 dias, consulta de 46,8 ms; revisão 40 pessoas, 233 arestas (073). **Produção não medida**: #1190, ampliada por T003 |
| **Desempenho** | cálculo em segundo plano, 120 s de teto por job (provisório, T021); leitura com número fixo de consultas; layout da visão parcial medido em T040 |

**NEEDS CLARIFICATION: nenhum bloqueante.** As decisões a confirmar estão no fim, e nenhuma bloqueia
o início.

## Constitution Check

*Antes da Fase 0 e de novo depois da Fase 1. Resultado nas duas: **passa**.*

| princípio | como o plano o cumpre |
|---|---|
| **I — domínio pelas ontologias** | nenhum conceito novo; a aresta de designação é regra derivada com `equivalence: partial`, justificativa e limitações (revisões 1 e 2), e **não** é colaboração nem delegação (A1); designação ≠ execução (a aresta não usa `spo.is_in_charge_of`) |
| **II — fonte externa não é domínio** | nenhuma coleta nova; a coleta passa a gravar o tipo da conta que o nó já traz (`__typename`), por `Mapper.account_type/1` (A3) |
| **III — proveniência e idempotência** | a leitura guarda versões da base, semente, gerador, sorteio, contagens por motivo; mesmo dado dá a mesma leitura (SC-003); impressão digital evita regravar; substituição atômica |
| **IV — semântica em YAML** | 24 artefatos da proposta mais as emendas do plano (teto, pesos do Q_rand, gerador, faixas de cor, rótulos) e as perguntas de competência; `Parameters` levanta se faltar chave |
| **V — multitenant** | seis filtros de tenant na consulta da designação (A1); FK composta nas duas tabelas novas; job confere tenant e organização antes de ler; dois tenants em todo teste de isolamento |
| **VI — contrato antes, fatia vertical** | [contracts/](contracts/) com o que não se expõe; cada US entrega tela e backend juntos; a tela segue o protótipo aprovado |
| **VII — gates e revisão** | nenhuma exceção de gate; o agente semântico revisa as emendas da base (T006) antes de entrarem |
| **VIII — desenho que o problema justifica** | registro abaixo (D1–D12) |
| **IX — ontologias autônomas** | nenhuma tabela de ontologia lida fora do dono; nenhum conceito novo |
| **X — responsabilidade única** | algoritmos (matemática), `Random` (sorteio), `Layout` (desenho), `View` (acesso), `Commands` (gravação), `Reader` (leitura), job (orquestração); cada página da área responde uma pergunta, como no protótipo |
| **XI — estado conferido** | o job confere tenant, atividade e organização; o invariante de contagem da designação faz classificação errada aparecer como diferença |
| **§14.0 — segurança primeiro** | avaliação `security` feita antes, por quem não desenhou; R10 (`Repo.insert!` da 073) e #1185 (DS4) entram na **Fase 2**, antes da feature; A1–A22 viram testes; guarda vista reprovando |

### Registro das decisões de desenho (princípio VIII)

Padrões já justificados no `AGENTS.md` §7.7 (fachada com `defdelegate`, comando/consulta, relator,
discriminador) e usados no problema deles não são rejustificados.

**D1. Subsistema `TheBand.NetworkAnalysis`, separado de `ReviewNetwork`** ([R1](research.md#r1--o-módulo-theband-networkanalysis-ao-lado-de-reviewnetwork))
- *Problema*: análise de duas redes com tabela, fila, alcance e parâmetros próprios; a página da 073 fica como está (Q4).
- *Existe agora?* Sim.
- *O que piora*: dois subsistemas falam de "rede"; quem procura a rede de revisão tem dois lugares (a página da 073 e a análise).

**D2. A rede de revisão da análise lida da leitura vigente da 073** ([R2](research.md#r2--de-onde-vêm-as-arestas-de-cada-rede))
- *Problema*: a análise e a página da 073 precisam mostrar a mesma rede (US1, cen. 2).
- *Existe agora?* Sim.
- *O que piora*: `ReviewNetwork` ganha `current_edges/2`; a análise depende da 073 estar calculada.

**D3. O job da 073 encadeia o da 076** ([R3](research.md#r3--o-gatilho-a-073-encadeia-a-076))
- *Problema*: as duas redes frescas na mesma passada, sem enfileiramento perdido pela unicidade.
- *Existe agora?* Sim: `:mudancas` depende de `:trabalho`.
- *O que piora*: acoplamento temporal entre dois jobs, escrito na linha; falha da etapa de mudanças atrasa a designação.

**D4. Fila própria com concorrência 1, teto de tempo e de tamanho, impressão digital** ([R4](research.md#r4--fila-unicidade-tempo-máximo-e-impressão-digital-fr-017-r7-da-segurança), [R5](research.md#r5--o-teto-de-tamanho-fr-017))
- *Problema*: 6 × 101 execuções do guloso por organização a cada sincronização, na fila que a coleta usa (R7).
- *Existe agora?* Sim, por construção do σ e do Q_rand.
- *O que piora*: uma fila a configurar, uma coluna `checked_at`, um teto que precisa de medida (#1190).

**D5. Algoritmos em Elixir puro, um módulo por família** ([R6](research.md#r6--os-algoritmos-em-elixir-puro))
- *Problema*: centralidades, comunidades com desempate e σ com gerador declarado, reproduzíveis.
- *Existe agora?* Sim.
- *O que piora*: cerca de seiscentas linhas nossas de algoritmo; a guarda é o SC-002 com cinco redes.

**D6. Gerador `:exsss` com estado explícito, semeado duas vezes (σ e layout)** ([R7](research.md#r7--o-gerador-pseudoaleatório-e-o-sorteio-declarados-a8-da-revisão-2))
- *Problema*: FR-052 e SC-003; a semente sozinha não reproduz (A8).
- *Existe agora?* Sim.
- *O que piora*: o estado passa de mão em mão em cada função de sorteio.

**D7. Q_rand com os pesos reais sorteados** ([R8](research.md#r8--q_rand-com-peso-a5-da-revisão-2))
- *Problema*: Q com peso contra Q_rand sem peso enviesa a favor de "há estrutura" (A5).
- *Existe agora?* Sim, na rede de designação, que concentra peso.
- *O que piora*: muda o método da base (revisão semântica de novo, T006); um embaralhamento a mais por grafo.

**D8. `View` puro, separado do cálculo; papel e percentil derivados na leitura** ([R10](research.md#r10--a-visão-recortada-fr-011-a-fr-016-r1r6-da-segurança), [R17](research.md#r17--o-cálculo-grava-a-leitura-deriva-fr-018))
- *Problema*: o recorte muda com a regra de acesso; o papel não pode ser atributo gravado (R4).
- *Existe agora?* Sim.
- *O que piora*: ordenação e layout da visão parcial a cada leitura (dezenas de nós; medido em T040).

**D9. Uma função de alcance com a opção `origem: :concedida`** ([R11](research.md#r11--o-alcance-uma-função-com-uma-opção-fr-013-r5-da-segurança-ds1-ds4))
- *Problema*: DS1 (b) separa quem tem escopo concedido de quem só tem vínculo derivado.
- *Existe agora?* Sim, desde a decisão de 2026-10-04.
- *O que piora*: `pessoas_alcancadas` ganha uma aridade; duas chamadas por leitura.

**D10. Tipo da conta gravado na coleta, com preenchimento do passado pelo payload bruto** ([R13](research.md#r13--o-tipo-da-conta-gravado-na-coleta-de-issues-a3-da-revisão-2))
- *Problema*: bot sem sufixo `[bot]` vira "sem pessoa ligada" (A3) — **medido**: 3 issues em desenvolvimento.
- *Existe agora?* Sim.
- *O que piora*: duas colunas e uma migração de dados com `execute/1`, com `down` explícito.

**D11. A conta da organização como relator em `Tenants.Access`, valendo para as duas redes** ([R14](research.md#r14--a-conta-da-organização-d3-a-r8-da-segurança-a7))
- *Problema*: a conta `LEDS` aparece como `User`; a marca é poder de esconder alguém (R8); com a marca em uma rede só, as redes deixam de ser comparáveis (A7).
- *Existe agora?* Sim (D3 decidida); a extensão à 073 é a **A7, a confirmar**.
- *O que piora*: uma tabela, quatro funções, eventos, uma tela de administração; com A7, a 073 muda (versão 2 da regra, uma coluna anulável).

**D12. SVG no servidor, hook só de transformação, destaque por classe** ([R16](research.md#r16--o-svg-o-zoom-e-o-destaque-fr-020-a-fr-026-r6-r13-da-segurança))
- *Problema*: FR-016, FR-022 a FR-024; nenhum dado de pessoa no navegador além do desenhado.
- *Existe agora?* Sim.
- *O que piora*: o markup cresce com as arestas (classes por ponta); centenas de arestas no máximo pelo teto.

## Project Structure

### Documentation (this feature)

```text
specs/076-analise-de-rede/
├── spec.md, seguranca.md, revisao-semantica.md, revisao-semantica-2.md   entradas
├── proposta-base/            o conteúdo da base (fonte)
├── prototipo/                aprovado em 2026-10-04
├── plan.md                   este arquivo
├── research.md               Fase 0
├── data-model.md             Fase 1
├── contracts/                Fase 1
│   ├── network-analysis.md   a fachada, e o que não expõe
│   ├── algoritmos.md         os módulos puros e a visão
│   ├── fronteiras.md         o que muda em WorkItems, ReviewNetwork, Tenants, Sources, web
│   ├── job.md                ComputeNetworkAnalysis
│   └── tela.md               rotas e restrições das telas
├── quickstart.md             Fase 1
└── tasks.md                  Fase 2
```

### Source Code

```text
lib/the_band/
├── network_analysis.ex                     fachada, só defdelegate
├── network_analysis/
│   ├── algorithms/projection.ex            projeção, componentes, graus
│   ├── algorithms/paths.ex                 BFS, proximidade, distâncias, eficiência
│   ├── algorithms/betweenness.ex           Brandes
│   ├── algorithms/eigenvector.ex           A + I por componente
│   ├── algorithms/clustering.ex            média local
│   ├── algorithms/communities.ex           CNM, modularidade, grau interno
│   ├── algorithms/random.ex                :exsss, G(n, m), Fisher–Yates
│   ├── algorithms/small_world.ex           bateria de aleatórios, σ, Q_rand
│   ├── algorithms/layout.ex                Fruchterman–Reingold
│   ├── algorithms/position.ex              percentil, papel
│   ├── assignment_classification.ex        par → aresta | motivo
│   ├── parameters.ex                       as regras da base; levanta se faltar chave
│   ├── commands.ex                         compute/3,4; discard_organization/2
│   ├── queries.ex                          a leitura vigente
│   ├── view.ex                             o recorte (FR-015)
│   ├── reader.ex                           read/4, profile/5, selection/1, options/0
│   ├── notices.ex                          PubSub só com ids
│   └── schemas/reading.ex                  privado
├── jobs/compute_network_analysis.ex        o worker
├── jobs/compute_review_network.ex          + encadeia a 076
├── review_network.ex, review_network/      + current_edges/2, discard_organization/2; insert sem !; (A7) classificação
├── work_items.ex, work_items/              + assignment_pairs/3; tipo da conta na gravação
├── ingestion/github_work_items.ex          grava o tipo da conta
├── tenants.ex, tenants/access.ex           + pessoas_alcancadas/3; contas da organização
├── tenants/access/organization_account_declaration.ex
└── sources.ex                              end_observation descarta as leituras

lib/the_band_web/
├── components/layouts.ex                   item Network analysis
├── router.ex                               rotas da área; :legacy
├── live/network_analysis_live/             index, graph, communities, hubs, distance, positions, profile, shared, graph_components (+ hook co-localizado)
├── live/review_network_live/show.ex        montada na área; :legacy
├── live/people_live/                       contas da organização (administração)
└── live/verification_live/people.ex        a frase da #1185 (DS4)

priv/repo/migrations/                        4 migrações (+1 com A7)
priv/knowledge_base/                         24 artefatos da proposta + emendas + perguntas de competência
config/config.exs                            network_analysis: 1

test/the_band/network_analysis/              algoritmos (SC-002), view (A3–A6, DS1, DS5), reader, commands, classification
test/the_band/jobs/compute_network_analysis_test.exs   A14–A16, A18, A19
test/the_band_web/live/network_analysis_live/          A6–A13, A22, telas
test/the_band/network_analysis/exposicao_test.exs      A17
```

**Structure Decision**: monólito único; o subsistema segue a forma de `ReviewNetwork` (topo de
`lib/the_band/`, fachada da §7.1, schema privado).

## Ordem de execução, e por que ela é esta

1. **Integrar `development`** (feito: merge `72eb9e8`);
2. **segurança primeiro (§14.0)**: o `Repo.insert!` da 073 (R10) e a frase da #1185 (DS4), antes de
   qualquer tarefa que toque o cálculo ou o alcance;
3. **a base**: as emendas do plano na proposta, revisadas pelo agente semântico; os YAMLs em
   `priv/knowledge_base/`; `Parameters`;
4. **a fundação de cálculo**: tabela, fila, gerador, projeção, job com as conferências, `compute`
   com impressão digital e teto, `View` e `Reader` vazios de medida mas com o recorte inteiro;
5. **US1** (menu e a página da 073 na área) — entrega visível sem esperar algoritmo;
6. **US2** (designação: tipo da conta, consulta, classificação, conta da organização) — a tela das
   contagens; a parte da A7 espera T002;
7. **US3 → US9**, cada uma com o algoritmo, a visão e a página juntos;
8. **acabamento**: exposição (A17), retenção (R18), o teto medido (T021 vale antes do merge),
   aceitação contra a origem e contra o protótipo, gates.

## Complexity Tracking

Nenhuma violação de princípio a justificar. Os custos estão em D1–D12.

## Decisões a confirmar com a pessoa mantenedora (nenhuma bloqueia o início)

| # | Pergunta | Opção padrão deste plano | O que espera por ela |
|---|---|---|---|
| **A7** | A marca de conta da organização (D3) vale também para a rede de revisão da 073? | **sim**: `review.network.edge` versão 2 com `organization_account`; coluna anulável na leitura da 073 | T017, T018 |
| **R10, item 8** | Os *"três mais centrais"* de cada comunidade seguem a DS1 (só com escopo concedido)? | **sim**, por serem ordenação por medida | o recorte de T051 |
| **R21** | Comunidade rotulada por letra (protótipo) ou por número (exemplo da spec)? | **letra**, como aprovado | o texto de T052 |
| **R5** | O teto provisório de 300 pessoas / 3 000 arestas | confirmar com T021 e a #1190 | nada antes do merge |

## O que este plano NÃO resolve

- **a medida de produção** (#1190): o plano mediu desenvolvimento;
- **A6 da revisão 2**: se as frações de pares alcançáveis dos aleatórios divergirem muito das reais
  com dado de produção, avaliar G(n, m) condicionado a grau mínimo 1 — escolha de modelo nulo, para
  depois da medida; a leitura já grava as duas frações;
- **A15 da revisão 2** (o validador não confere ids de conceito das necessidades nem as referências
  entre regras): lacuna da base, para issue própria;
- **o evento de designação com data** (opção (b) da D1): não é desta feature;
- **quem lê os papéis**: se a pessoa mantenedora quiser saber quem os leu, é FR nova (R15);
- **backup**: a leitura substituída continua nas cópias até a retenção delas (064, #885).
