# Pesquisa — feature 062, servidor MCP

**Data**: 2026-09-21 · **Branch**: `062-servidor-mcp`

Cada decisão aqui foi medida ou lida na origem. Onde não foi, está escrito que não foi.

---

## D1 — A biblioteca MCP

**Decisão**: `ex_mcp`, travada em `~> 1.5`.

**Como foi medido**: consulta ao Hex em 2026-09-21, pelos quatro candidatos que a busca
devolveu.

| Pacote | Versão | Publicado | Downloads | Licença |
|---|---|---|---|---|
| **`ex_mcp`** | **1.5.0** | **2026-09-21** | 13 070 no total · 1 685 em 7 dias | MIT |
| `hermes_mcp` | 0.14.1 | **2025-08-14** | 210 447 no total · 4 089 em 30 dias | MIT |
| `fastest_mcp` | 0.3.2 | 2026-08-28 | 586 no total · 86 em 30 dias | Apache-2.0 |
| `mcp_elixir_sdk` | — | — | não medido | — |

**Razão**:

1. **Pós-1.0.** Este repositório já tem a regra escrita, em `mix.exs`, sobre o `req`:
   *"fica fixado em `~> 0.7.2` e não `>= 0.7`: está em 0.x, onde mudança incompatível pode
   vir em versão menor"*. `fastest_mcp` está em 0.3, e `hermes_mcp` em 0.14;
2. **o protocolo revisa, e a biblioteca precisa acompanhar.** `hermes_mcp` tem mais que o
   dobro de downloads acumulados, e **não publica desde agosto de 2025** — treze meses. Para
   uma especificação que já teve a revisão `2026-07-28`, treze meses parados são risco, não
   estabilidade. `ex_mcp` declara suporte à revisão corrente;
3. **`fastest_mcp` é pequeno demais para o risco**: 586 downloads no total. Nada contra o
   código; é que não há uso o bastante para que um defeito apareça antes de aparecer aqui.

**O que fica pior, e isto é parte da decisão** (princípio VIII): `ex_mcp` é **jovem** —
13 mil downloads acumulados contra 210 mil do concorrente parado. Uma versão `1.5` publicada
no mesmo dia da escolha não tem histórico de estabilidade.

> **Corrigido em 2026-09-24 pela revisão independente (R3).** "Uma dependência nova" é uma
> dependência **direta**: a `ex_mcp` 1.5.0 traz **dez** pacotes, entre eles `plug_cowboy`, e
> faz o `mix hex.audit` sair 1, por duas advisories do `cowlib`. Foi medido que o `cowlib` não
> é alcançável sob o Bandit ([`r3-cowlib-alcance.md`](./r3-cowlib-alcance.md)), e a exceção
> entra no T001 com a versão fixada em `== 1.5.0` e três guardas.

**A mitigação é de desenho, e é o que torna a escolha reversível**: a camada MCP MUST ser
**fina**. As ferramentas são funções puras sobre os contextos que já existem; a biblioteca
carrega transporte e enquadramento do protocolo, e mais nada. Se ela tiver de ser trocada,
troca-se o adaptador — não as respostas. O teste que prova isso está no plano: as funções
de ferramenta são exercidas **sem** a biblioteca.

**Alternativa rejeitada**: escrever o JSON-RPC à mão. Resolveria a dependência jovem e
criaria uma pior — enquadramento de protocolo mantido por nós, que é exatamente o trabalho
que não agrega valor a esta plataforma.

---

## D2 — Dentro do monólito, e com qual fronteira

**Decisão**: dentro do monólito (Q1 da spec), servido pelo endpoint Phoenix que já existe, e
chamando **os contextos** — `EO`, `TeamWork`, `Quality`, `Profiles`, `Tenants` —, nunca o
`Repo` e nunca a própria API por HTTP.

**Razão**: chamar a própria API por HTTP de dentro do mesmo nó paga rede para não ganhar
isolamento nenhum. E o `Repo` direto é o que tornaria a extração posterior um reescreve em
vez de um mover.

**Como se verifica**: teste que varre os módulos de `lib/the_band/mcp/` e reprova se
qualquer um referenciar `TheBand.Repo` ou `Ecto.Query`. É a mesma forma da guarda de
consulta sem tenant que já existe.

---

## D3 — De onde vem a ressalva de cada medida

**Decisão**: da base de conhecimento, em tempo de resposta, por `id` da medida.

**Como foi lido** (2026-09-21, contra `priv/knowledge_base/`):

| Campo | Onde | Obrigatório? |
|---|---|---|
| `limitations` | `measurement.schema.yaml`, linha 64 | **sim**, `minItems: 1` |
| `misinterpretations` | idem, linha 65 | não |
| `version` | `derivation_rule` — ex.: `team.dashboard.thresholds` tem `version: 1` | sim, nas regras |

**Consequência para a FR-010**: *"identificador e versão da regra"* só é preenchível quando o
valor vem de **regra**. Medida não tem `version` no schema. O envelope MUST então distinguir
os dois casos, e não inventar uma versão para medida.

**Falta uma função pública**: `KnowledgeBase` expõe `rule/1`, `mapping/1`, `axiom/1` e
`list/1`, e **não expõe `measurement/1`** — o `fetch/2` é privado. Acrescentá-la é uma linha,
e é pré-requisito da FR-011.

**A base carrega 77 perguntas de competência em seis das catorze ontologias.** As outras oito
não declaram nenhuma, e a FR-020 diz que não se inventa ferramenta que a base não declare.
Isto **limita** o primeiro corte, e é limite declarado, não descoberto depois.

---

## D4 — A autenticação

**Decisão**: o mesmo plug da 061 — `TheBandWeb.Plugs.ApiAuth` —, sem nada novo.

**Como foi lido**: o plug já resolve tenant e conta dona a partir da **linha do token**, e já
recusa token de conta desativada (`User.ativa?/1`). A FR-002 pede exatamente isso: tenant do
token, nunca de argumento.

**A dependência que a spec dava como bloqueada caiu**: a tabela dizia
*"`users.disabled_at` — não existe"*. Existe desde a migração `20260910050000`, e o plug já a
respeita. A spec foi corrigida nesta data.

**O que NÃO é herdado**: a 061 responde `404` para fora de alcance, porque ali a resposta é
HTTP. Aqui a recusa é **resposta de ferramenta com a razão** (FR-013), e não erro de
protocolo — um agente que recebe erro de transporte não sabe distinguir *não pode ver* de
*o servidor caiu*.

---

## D5 — As quatro ferramentas do primeiro corte

**Decisão**: as quatro perguntas da tela da equipe, todas com caminho de dados **provado** na
061 (FR-021: *"uma ferramenta que responde de verdade vale mais que doze que devolvem `{}`"*).

| Ferramenta | Pergunta | Caminho já provado em |
|---|---|---|
| `team_roster` | quem está na equipe | `GET /api/v1/teams/:id/members` |
| `team_open_work` | o que cada um tem aberto | `/teams/:id/measures` → `open_by_person` |
| `team_review_wait` | quanto o trabalho espera por revisão | `/teams/:id/measures` → `time_to_first_review` |
| `team_stale_work` | o que está parado | `/teams/:id/measures` → `work.stale` |

**Razão de serem quatro e não uma**: a Q2 da spec as nomeia, e cada uma responde uma pergunta
que a plataforma **já se compromete a responder**. Uma ferramenta só, com um argumento
`pergunta`, seria consulta arbitrária com outro nome — a FR-023 a proíbe.

**Razão de serem quatro e não doze**: as outras 73 perguntas de competência não têm tela, e
portanto não têm caminho provado.

---

## D6 — O que a implementação da 061 já mediu, e que o desenho tem de carregar

Estes números não são ilustração. São a razão de a FR-010 existir, e a medida do erro que
ela evita.

**As duas medianas de espera, na equipe `LEDS - ConectaFapes`, em 2026-09-21:**

| | Quantas | Mediana |
|---|---:|---:|
| revisadas | 23 | **0,2 h** |
| aguardando | 79 | **46 dias** |

Um campo único de segundos, com uma mediana só, teria respondido **"12 minutos"** sobre 102
solicitações das quais 79 esperam há mês e meio. O envelope MUST manter as duas separadas, e
`team_review_wait` MUST devolver as duas com os denominadores.

**`null` e `[]` são afirmações diferentes**, e a API já as separa: `competencies: null`
significa *não houve leitura*; `[]` significa *houve, e nada foi demonstrado*. É a FR-012, já
provada num consumidor.

---

## Incógnitas que permanecem

| # | O que | Por que não foi resolvida aqui |
|---|---|---|
| **I1** | `api.access.thresholds` na base | valores são decisão do Product Owner; a spec 061 já a declarava aberta |
| **I2** | como o registro de uso por MCP distingue abuso | é o item 4 da avaliação de segurança que a spec pede, e ela não foi feita |
| **I3** | injeção de instrução pelo conteúdo | item 2 da mesma avaliação. **Não é resolvível no plano**: é decisão de desenho que precisa do papel Security |

**I2 e I3 são declaradas, e não contornadas.** O plano não finge tê-las resolvido.
