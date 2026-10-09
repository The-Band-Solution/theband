# Implementation Plan: rede de revisão

**Branch**: `feature/1182-rede-de-revisao` · **Spec**: [spec.md](spec.md) · **Data**: 2026-10-03 · **Épico**: [#1182](https://github.com/The-Band-Solution/theband/issues/1182)

**Pesquisa**: [research.md](research.md) · **Modelo**: [data-model.md](data-model.md) · **Contratos**: [contracts/](contracts/) · **Validação**: [quickstart.md](quickstart.md)

**Entradas paralelas, de outros agentes, que este plano referencia e não duplica**:

- [`proposta-base/`](proposta-base/): o **conteúdo** dos YAMLs da base (necessidade de informação,
  medidas, mapeamento, regra com k, amostra e grupo mínimo, perguntas de competência). É a fonte;
  este plano decide só a forma que o código lê ([research.md R11](research.md#r11--a-base-de-conhecimento-forma-de-cada-artefato));
- [`prototipo/`](prototipo/): o protótipo da tela. **O código da tela espera a aprovação dele pela
  pessoa mantenedora** (FR-017).

---

## Summary

Quem coordena abre a rede de revisão de uma organização observada e lê, numa janela de 30, 90 ou
180 dias, **se a revisão está concentrada**: o total, quantas pessoas revisaram, e que fração coube
às uma, duas e três pessoas que mais revisaram, sem nomear ninguém. Depois vê quem revisa quem, por
pessoa, e se a rede é um bloco só ou grupos que não se revisam.

O desenho:

1. um job Oban, disparado **ao fim da coleta de revisões** da sincronização, calcula as três
   janelas de uma vez e **substitui** a leitura vigente da organização numa transação. A leitura
   guarda arestas com peso e ids de pessoa, nunca nome;
2. **uma** função de domínio, `ReviewNetwork.read/4`, recorta a leitura pelo alcance de quem
   consulta, recalculado a cada chamada, e calcula grupos e concentração sobre o recorte. A tela
   só chama essa função;
3. o grafo é Elixir puro (busca em largura, frequências, prefixos de soma). **Sem dependência
   nova**: 40 nós e 233 arestas medidos, 11,8 ms de consulta;
4. a semântica (o que vira aresta, os estados que contam, k, amostra, grupo mínimo, janelas) mora
   na base, com limitações e interpretações incorretas.

## Technical Context

| | |
|---|---|
| **Linguagem** | Elixir ~> 1.17 (CI e imagem em 1.20.2 / OTP 29) |
| **Web** | Phoenix 1.8.11 · LiveView 1.2.9 (`mix.lock`) |
| **Persistência** | PostgreSQL 16 · Ecto SQL 3.14.0 · Postgrex 0.22.4. Multitenant por `tenant_id`, toda consulta recebe `%Tenant{}` |
| **Jobs** | Oban 2.23.1, fila `:transformation` já configurada (`config/config.exs:114`) |
| **Base** | YAML via `yaml_elixir` 2.12.2, carregada no boot (`TheBand.Ontology.KnowledgeBase`) |
| **Dependência nova** | **nenhuma** ([research.md R5](research.md#r5--os-algoritmos-em-elixir-puro-e-por-que-sem-dependência)) |
| **Testes** | ExUnit, dois tenants povoados, cenários A1–A18 da segurança, guarda vista reprovando |
| **O que verifica** | `mix gates`; o veredito é o código de saída |
| **Escala medida** | desenvolvimento, 2026-10-03: 4 954 avaliações numa organização; 2 541 em 180 dias; 40 revisores; 233 arestas; consulta de 11,8 ms. **Produção não medida** (tarefa antes do merge da US1) |
| **Desempenho** | o cálculo roda em segundo plano; a leitura tem número fixo de consultas, independente do tamanho da rede |

**NEEDS CLARIFICATION: nenhum bloqueante.** Três decisões tomadas aqui pedem **confirmação no
protótipo**, e nenhuma muda a tabela:

1. a unidade de "uma revisão" é o **par (revisor, solicitação)**: uma solicitação com dois
   revisores conta duas revisões ([R2](research.md#r2--a-unidade-o-que-é-uma-revisão-nesta-rede));
2. com alcance parcial, as **contagens de exclusão** (bot, não ligada, auto-revisão) não aparecem,
   só a regra ([R12](research.md#r12--o-que-a-tela-de-alcance-parcial-mostra-das-exclusões));
3. a rota `/organizations/:id/review-network` ([R15](research.md#r15--a-tela-e-o-protótipo-antes-dela)).

## Constitution Check

*Antes da Fase 0, e de novo depois da Fase 1. Resultado nas duas: **passa**, com as decisões
registradas abaixo.*

| princípio | como o plano o cumpre |
|---|---|
| **I — domínio pelas ontologias** | a rede é leitura derivada de `qapo.stakeholder_performed_artifact_evaluation` sobre `cmpo.change_request`, entre `eo.person`. Pull Request ≠ merge: a aresta é sobre a revisão, nunca sobre quem integrou (FR-002). Nenhum mapeamento por nome: a aresta tem equivalência `derived`, justificativa e limitações (FR-005), e **não** se chama colaboração |
| **II — fonte externa não é domínio** | nenhuma coleta nova; a rede lê o que já foi coletado, pelas APIs de `Quality`, `Changes`, `EO` e `CMPO` |
| **III — proveniência e idempotência** | a leitura guarda janela, instante, contagens de exclusão e versões da base (FR-011). Recalcular com o mesmo instante dá o mesmo resultado (FR-012); a substituição é atômica |
| **IV — semântica em YAML** | necessidade, quatro medidas, regra da aresta e regra dos limiares na base (conteúdo em `proposta-base/`). Base inconsistente levanta na carga. Medidas com limitações e interpretações incorretas |
| **V — multitenant** | cada tabela filtrada pelo tenant, nas duas pontas do join (R12 da segurança); job valida tenant e organização por id **e** tenant antes de ler; FK composta na tabela nova; testes com dois tenants |
| **VI — Spec Kit, contrato antes** | contratos em [contracts/](contracts/), com o que não se expõe. Fatia vertical: a US1 entrega tela e backend juntos. A tela espera o protótipo |
| **VII — gates e revisão** | nenhuma exceção de gate; revisão semântica da regra da aresta, da unidade (R2) e da mudança de schema antes do código |
| **VIII — desenho que o problema justifica** | registro abaixo. Antipadrões evitados por nome: consulta sem tenant, fallback silencioso (cancelar não grava leitura vazia), zero no lugar de ausência, número mágico (k e mínimos na base), booleano no lugar de relator (o job devolve relator) |
| **IX — ontologias autônomas** | nenhum conceito novo de ontologia; nenhuma tabela de outra ontologia lida fora do dono |
| **X — responsabilidade única** | `Graph` (matemática), `Slice` (regra de acesso), `Commands` (substituição), `Parameters` (base), job (orquestração): cada um muda por uma razão. A tela mostra uma coisa: a rede da organização na janela |
| **XI — estado conferido** | o job confere tenant, atividade e organização antes de ler; o invariante de contagem faz a classificação errada aparecer como diferença |
| **§14.0 — segurança primeiro** | avaliação do agente `security` feita **antes** deste plano, por quem não escreveu o desenho ([seguranca.md](seguranca.md)); decisões de 2026-10-03 incorporadas; A1–A18 viram testes; a #1181 está em `development` e entra na branch antes da leitura com alcance |

### Registro das decisões de desenho (princípio VIII)

Padrões já justificados em `AGENTS.md` §7.7 e usados no problema deles (fachada com `defdelegate`,
separação comando/consulta, discriminador) não são rejustificados.

**D1. Subsistema `TheBand.ReviewNetwork`, fora de `Quality`**
([R1](research.md#r1--onde-o-módulo-mora-e-o-nome))

- *Problema*: a rede tem tabela, job, regra de alcance e parâmetros próprios, e cruza três
  ontologias. Dentro de `Quality`, o módulo passaria a mudar por duas razões.
- *Existe agora?* Sim: é esta feature.
- *O que piora*: mais um módulo de topo com fachada; quem procura "revisão" tem dois lugares
  (`Quality` para o tempo até a primeira revisão, `ReviewNetwork` para a rede).

**D2. Leitura materializada, uma vigente por organização e janela**
([R7](research.md#r7--a-leitura-materializada-uma-por-organização-e-janela))

- *Problema*: a spec exige cálculo em segundo plano, proveniência gravada e nenhuma ação de conta
  comum gerando trabalho (FR-010, FR-011, FR-013).
- *Existe agora?* Sim, por decisão da spec. **Não** por custo: a consulta leva 12 ms, e calcular na
  hora funcionaria.
- *O que piora*: uma tabela, um job e a defasagem (a leitura é do fim da última coleta, e a tela
  precisa dizer o instante).

**D3. Grafo em Elixir puro, sem biblioteca**
([R5](research.md#r5--os-algoritmos-em-elixir-puro-e-por-que-sem-dependência))

- *Problema*: componentes fracos, graus e prefixos de soma.
- *Existe agora?* Sim, e é pequeno: 40 nós, 233 arestas.
- *O que piora*: cerca de quarenta linhas de grafo nossas para testar. A alternativa (biblioteca)
  traria dependência nova para duas funções, contra a spec.

**D4. `Slice` separado de `Graph`, aplicado dentro de `read/4`**

- *Problema*: o recorte tem de morar em **uma** função de domínio (R3 da segurança), e a regra de
  acesso muda por razão diferente da matemática.
- *Existe agora?* Sim: R1 e R2 decididas em 2026-10-03 mudam o que cada leitor vê.
- *O que piora*: concentração e grupos recalculados a cada leitura (pouco: O(E) sobre centenas de
  arestas), e um módulo a mais.

**D5. Grupos e concentração não gravados**

- *Problema*: dependem do alcance de quem lê; gravados, haveria dois caminhos de cálculo.
- *Existe agora?* Sim.
- *O que piora*: a entidade-chave da spec (*"a leitura contém os grupos e a concentração"*) passa
  a valer **por derivação**, e não por coluna. A auditoria de uma leitura antiga não existe de
  qualquer modo: a anterior não é guardada (FR-011).

**D6. Gatilho em `coletar_mudancas/1`, e não no fim da sincronização**
([R8](research.md#r8--o-gatilho-o-fim-da-coleta-de-revisões))

- *Problema*: recalcular quando as revisões chegam (FR-013).
- *Existe agora?* Sim: as etapas REST depois dela podem hibernar por horas.
- *O que piora*: o job de coleta passa a conhecer um subsistema de leitura. Acoplamento escrito ao
  lado da linha.

**D7. Fila `:transformation` com unicidade por organização, sem `:executing`**
([R9](research.md#r9--o-job-fila-unicidade-conferências-e-cancelamento))

- *Problema*: duas coletas seguidas não podem empilhar cálculos, e uma coleta durante o cálculo
  não pode ser perdida.
- *Existe agora?* Sim: o agendador roda a cada 5 minutos, com intervalo mínimo de 15.
- *O que piora*: no pior caso, dois cálculos da mesma organização (um rodando, um esperando).

**D8. Índice `(tenant_id, external_submitted_at)`**
([R10](research.md#r10--índice-e-volume))

- *Problema*: o recorte por data lê todas as avaliações do tenant.
- *Existe agora?* Em parte: 49% das linhas já estão fora de 180 dias, e a tabela só cresce. Hoje a
  varredura custa 1,4 ms.
- *O que piora*: um índice a mais a cada gravação de avaliação.

**D9. Cinco leituras pelas fronteiras, e não uma consulta com cinco tabelas**
([R4](research.md#r4--a-organização-e-as-consultas-sem-furar-fronteira))

- *Problema*: a rede lê dado de quatro donos; o princípio X, letra D, exige a fronteira pública.
- *Existe agora?* Sim.
- *O que piora*: quatro funções novas em outros módulos e cinco consultas em vez de uma; o
  precedente `Verification.by_organization/1` faria em uma.

**D10. Aresta como `derivation_rule`, e `version` opcional no schema de medida**
([R11](research.md#r11--a-base-de-conhecimento-forma-de-cada-artefato))

- *Problema*: a aresta não tem identidade externa, que o schema de mapeamento exige; a FR-011 pede
  a versão das medidas, que o schema não tem.
- *Existe agora?* Sim.
- *O que piora*: regra de derivação não tem schema, e a forma passa a ser garantida por teste;
  ninguém além do revisor confere que a versão sobe. **Se `proposta-base/` declarar a aresta como
  `mapping:`**, a revisão semântica decide entre as duas formas antes do código.

**D11. Remover `Quality.by_reviewer/2`**
([R13](research.md#r13--qualitybyreviewer2-sai-nesta-feature))

- *Problema*: ranking sem alcance e sem chamador, o atalho que a FR-018a proíbe.
- *Existe agora?* Sim, desde a feature 039.
- *O que piora*: quatro testes saem junto. O isolamento que um deles provava passa aos cenários A1
  e A2.

## Project Structure

### Documentation (this feature)

```text
specs/073-rede-de-revisao/
├── spec.md, seguranca.md      entradas
├── plan.md                    este arquivo
├── research.md                Fase 0
├── data-model.md              Fase 1
├── contracts/                 Fase 1
│   ├── review-network.md      a API pública do módulo, e o que ela não expõe
│   ├── fronteiras.md          o que muda em Quality, Changes, EO e CMPO
│   ├── job.md                 ComputeReviewNetwork
│   └── tela.md                rota e restrições da tela (provisório até o protótipo)
├── quickstart.md              Fase 1
├── proposta-base/             conteúdo dos YAMLs (outro agente; fonte)
├── prototipo/                 protótipo da tela (outro agente; espera aprovação)
└── tasks.md                   Fase 2, /speckit-tasks
```

### Source Code

```text
lib/the_band/
├── review_network.ex                  fachada, só defdelegate
├── review_network/
│   ├── graph.ex                       puro: arestas, totais, grupos, concentração, subgrafo
│   ├── slice.ex                       puro: o alcance aplicado à leitura → view()
│   ├── classification.ex              par → aresta | auto_revisao | bot_ou_aplicativo | nao_ligada
│   ├── parameters.ex                  lê as duas regras da base; levanta se faltar chave
│   ├── commands.ex                    compute/4 (parâmetros explícitos): lê, calcula, substitui na transação
│   ├── queries.ex                     a leitura vigente por (tenant, organização, janela)
│   ├── reader.ex                      read/5 (parâmetros explícitos): janela, organização, alcance, recorte, nomes
│   └── schemas/reading.ex             privado ao módulo
├── jobs/compute_review_network.ex     o worker
├── jobs/sync_github_eo.ex             + organization_id no ctx; + enqueue em coletar_mudancas/1
├── quality.ex                         + review_pairs/3; − by_reviewer/2
├── changes.ex                         + change_request_authors/3
├── ontology/seon/eo.ex, eo/queries.ex + fetch_organization/2, account_types/2, organization_person_ids/2
└── ontology/seon/cmpo/queries.ex      + opção organization_id: em list_observed/2

lib/the_band_web/
├── router.ex                          + live "/organizations/:id/review-network" (depois do protótipo)
└── live/review_network_live/show.ex   depois do protótipo aprovado

priv/repo/migrations/<ts>_create_review_network_readings.exs   tabela, índice único, FK composta, índice em avaliações
priv/knowledge_base/                   YAMLs aceitos de proposta-base/; schema de medida com version opcional

test/the_band/review_network/          graph, slice, classification, parameters, commands, read (A1–A16)
test/the_band/jobs/compute_review_network_test.exs   A10, A11, A16
test/the_band_web/live/review_network_live/          A4–A8, A13, A15, FR-016–FR-018b
test/the_band/review_network/exposicao_test.exs      A17: nenhuma rota de API nem ferramenta MCP
```

**Structure Decision**: monólito único, como o resto do repositório. O subsistema novo segue a
forma de `Verification` e `Forecast` (topo de `lib/the_band/`), com a fachada da §7.1.

## Ordem de execução, e por que ela é esta

1. **Integrar `development`** na branch (traz a #1181, `2535f6d`). Merge, e não rebase: a branch
   já está no remoto. Sem isso, A18 reprova, e a §14.0 põe o defeito conhecido antes da feature;
2. **revisão semântica** da regra da aresta, da unidade e da mudança de schema, sobre
   `proposta-base/`; YAMLs aceitos entram em `priv/knowledge_base/` (US1 depende);
3. **medir em produção** o volume de 180 dias da maior organização (R6 da segurança), e escrever o
   número no `research.md` R10. Só leitura agregada, sem nome;
4. **US1, backend**: migração → APIs de fronteira (com A1, A2, A14 reprovando antes) → `Graph`,
   `Classification`, `Parameters` → `compute/3` → job e gatilho (A10, A11, A16) → `read/4` com
   `Slice` (A3–A7, A12, A13, A18);
5. **remover `Quality.by_reviewer/2`**, em commit próprio;
6. **US1, tela**: **bloqueada até o protótipo aprovado**; então rota, LiveView, A4, A7, A8, A15,
   FR-016;
7. **US2** (lista por pessoa, pares) e **US3** (grupos), cada uma com tela e backend juntos;
8. **A17**, documental, e os gates.

Cada US é uma fatia vertical: nenhuma entrega fica sem algo que a pessoa veja, exceto o passo 4,
que só se fecha junto com o 6.

## Complexity Tracking

Nenhuma violação de princípio a justificar. As decisões que trazem custo estão no registro D1–D11.

## O que este plano NÃO resolve

- **a medida de produção** (R10): o plano mediu desenvolvimento; a produção é tarefa antes do merge
  da US1;
- **a forma final da tela**: é do protótipo, e o contrato da tela é provisório;
- **o conteúdo dos YAMLs**: é de `proposta-base/`; este plano fixa só o que o código exige deles;
- **o aviso de recorte de `verification_live/people.ex:157-161`**, que promete a liderança
  declarada que `pessoas_alcancadas/2` não aplica: achado lateral, para issue própria;
- **as outras telas que mostram revisor por login** (`change_live/show.ex`, `teams_live/show.ex`),
  que a segurança deixou como pergunta para um inventário próprio;
- **o estado de falha do cálculo**: não se grava; a tela mostra a leitura vigente com o instante
  dela ([R14](research.md#r14--ausências-o-que-a-leitura-devolve-quando-não-há-o-que-mostrar));
- **exposição por API, MCP ou perfil** (FR-020): fora, por decisão; exige spec própria.
