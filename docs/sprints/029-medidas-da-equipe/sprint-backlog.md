# Sprint 029 — As medidas que faltam na tela da equipe

**Período**: 2026-09-02 a 2026-09-09 (cadência de uma semana)
**Feature**: [058](../../specs/058-medidas-da-equipe/spec.md)
**Plano**: [plan.md](../../specs/058-medidas-da-equipe/plan.md) ·
**Pesquisa**: [research.md](../../specs/058-medidas-da-equipe/research.md)

## Objetivo do sprint

**Fechar o que resta do épico [#504](https://github.com/The-Band-Solution/theband/issues/504)
com o que a feature 057 já sustenta** — e deixar declarado o que só a feature 042
destrava.

Duas colunas de período ganham o primeiro consumidor desde que foram criadas, e
uma medida que já é calculada chega à tela.

## De onde este sprint veio

O épico #504 estava aberto desde 2026-08-25 com três dependências. A revisão de
2026-09-02 encontrou que **as três mudaram de estado sem ninguém revisar o
épico** — duas fecharam, e a 057 entregou parte do que ele pedia sem que os dois
fossem ligados.

Foi a **L99** funcionando: conferir item por item acha o que planejar não acha.

## Lições aplicadas

| Lição | Origem | Como está sendo aplicada |
|---|---|---|
| **L99** conferir issue por issue | 028 | é a origem deste sprint — a revisão do #504 |
| **L98** lição que não vira regra reincide | 028 | a rastreabilidade FR/SC foi corrigida **no `/speckit-tasks`**, e não esperando o `/speckit-analyze` que a pegou no sprint passado |
| **L67** duas medidas do mesmo nome | 022 | é a razão de o caminho do ator **não entrar**: dois números com o mesmo rótulo e denominadores diferentes |
| **L95** pedir revisor ≠ obter revisão | 027 | campo no template de PR criado no #763; medir `reviews` antes de incorporar |
| **L96** issue que ninguém fecha | 028 | `gh issue list --state open` com o prefixo `058/` entra na DoD |
| **L30** conferir contra a origem | 003 | é a T020 — e a origem está inacessível, o que está **declarado** em vez de estimado |
| **L91** o passo sem gate some | 025 | as 24 issues linkadas no `tasks.md`, conferidas na origem |
| **L60** o veredito é o código de saída | 019 | na DoD, e no template de PR |
| merge, branch e histórico | 028 | tipo de merge **declarado no PR** — `AGENTS.md` §12 |

**A família "o defeito que não produz erro"** atravessa a feature inteira: o
`{:parcial, _}`, o `{:aguardando, _}` e o `{:sem_projeto, _}` existem porque
ausência não é zero.

## Sprint no GitHub

**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2) ·
24 itens acrescentados

### Duas limitações declaradas, não contornadas

**Este sprint não tem iteration** — o terceiro seguido. Acrescentá-la recria as
existentes, e a **L11** mediu o custo em 97 itens órfãos. A lacuna se acumula, e
resolvê-la é trabalho próprio, com o snapshot dos `item id` antes.

**As user stories ficam sem tipo.** `User Story` não existe na organização, e
tipá-las como `Feature` faria a regra de roteamento classificá-las erradamente.
**Sem tipo é ausência; com o tipo errado é afirmação falsa.**

As 21 tarefas **estão** tipadas como `Task`, e as 13 que atendem user story estão
ligadas como sub-issue.

## User stories selecionadas

| # | User story | Issue | Priority | Estimate | Tarefas |
|---|---|---|---|---|---|
| US2 | Quem trabalhou neste projeto, e quando 🎯 | [#766](https://github.com/The-Band-Solution/theband/issues/766) | P0 | 5 | T004–T007 |
| US1 | O tempo até a primeira revisão, desta equipe | [#765](https://github.com/The-Band-Solution/theband/issues/765) | P0 | 5 | T008–T011 |
| US3 | A taxa do pipeline dos projetos desta equipe | [#767](https://github.com/The-Band-Solution/theband/issues/767) | P1 | 5 | T012–T016 |

`Priority` é a *importance* — valor para a organização. `Estimate` é a
*complexity*. **As tarefas não recebem `Priority`**: herdam a da story.

## Tarefas

Todas em [`tasks.md`](../../specs/058-medidas-da-equipe/tasks.md), com os quatro
campos e o link da issue. Faixa:
[#768](https://github.com/The-Band-Solution/theband/issues/768) a
[#788](https://github.com/The-Band-Solution/theband/issues/788).

| Fase | Tarefas | Issues | Atende |
|---|---|---|---|
| Foundational | T001–T003 | #768–#770 | bloqueia tudo |
| US2 | T004–T007 | #771–#774 | #766 |
| US1 | T008–T011 | #775–#778 | #765 |
| US3 | T012–T016 | #779–#783 | #767 |
| Polish | T017–T021 | #784–#788 | — |

Estados: `a fazer` · `em andamento` · `feito` · `bloqueado` · `não iniciado` —
todas em **a fazer**.

## Herdado do sprint 028

| Item | Issue | Por que veio |
|---|---|---|
| T033 da 057 — gates, PR e revisão **CONFERIDA** | [#753](https://github.com/The-Band-Solution/theband/issues/753) | os cinco PRs do 028 foram incorporados com **zero revisões**. Pelo terceiro sprint, é condição de entrada |

## Fora do escopo deste sprint

| O que | Por quê |
|---|---|
| `flow.throughput.rate` e `flow.wip.count` | dependem do critério de início da **feature 042** — 24 issues sem código. São o único item do épico #504 que ainda precisa dela |
| `rework.not_accepted_deliverable_ratio` | **não se calcula**: a aceitação nunca é registrada |
| a taxa do pipeline **por ator da execução** | responde outra pergunta (R1), e oferecer as duas é a L67 |
| o burn da página da pessoa | [backlog](../../docs/backlog/burn-da-pessoa-sem-linha-de-base.md) — a pergunta precisa ser decidida antes do código |
| [servidor MCP](../../docs/backlog/servidor-mcp.md) | bloqueado até autenticação e tenant serem decididos |
| criar os tipos `User Story` e `Epic` | altera a configuração da organização; exige confirmação |
| acertar as iterations | L11 mediu o custo: 97 itens órfãos |

## Riscos e dependências

| Risco | Efeito | Mitigação |
|---|---|---|
| **a cobertura do dado ser quase zero** | a US3 entrega só o ramo da recusa | T020 mede **antes** da aceitação; se for zero, isso é **resultado** e vai para a review |
| **T020 depende da chave mestra**, que esta sessão não tem | a cobertura fica desconhecida | declarado na tarefa, no plano e aqui — não escondido atrás de estimativa |
| **revisão independente de novo não acontecer** | princípio VII violado pelo terceiro sprint | medir `reviews` antes de cada merge; zero é impedimento |
| o `{:parcial, _}` ser ignorado por quem consome | volta o fallback silencioso | o tipo tem três estados, e o `case` sem a terceira cláusula não passa limpo |
| teto de consultas estourar | tela lenta, gate vermelho | teto de 16 já é teste desde a 057; T018 mede o acréscimo |

## Definition of Done do sprint

- [ ] `mix gates` com **código de saída 0** — o veredito é o código, e nenhum
      comando depois dele (L60)
- [ ] base de conhecimento válida, com as medidas declaradas (T002, T003)
- [ ] **`gh pr view <n> --json reviews` > 0 em todo PR incorporado** (L95)
- [ ] **tipo de merge declarado** no corpo de cada PR (`AGENTS.md` §12)
- [ ] **`gh issue list --state open --search "058/ in:title"` conferida antes da
      review**, e toda divergência com o `tasks.md` resolvida (L96, L99)
- [ ] **os três números da T020 escritos na review** — ou a declaração de que a
      chave não estava disponível
- [ ] issues encerradas ou repriorizadas com justificativa
- [ ] `sprint-review.md` escrito
- [ ] `licoes-aprendidas.md` atualizado

## Baseline dos gates

Medido em 2026-09-02, no `development`, depois dos cinco merges do sprint 028:

```text
14 gates verdes.
MIX_GATES_NO_DEVELOPMENT=0
```
