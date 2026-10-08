# Sprint 043 — a análise de rede inteira: comunidades, hubs, distância, mundo pequeno, papel e perfil

**Período**: a partir de 2026-10-05, na iteration corrente do GitHub (Sprint 035, `ee36a246`)
**Feature**: [076](../../../specs/076-analise-de-rede/spec.md) · **Plano**: [plan.md](../../../specs/076-analise-de-rede/plan.md) · **Tarefas**: [tasks.md](../../../specs/076-analise-de-rede/tasks.md)
**Épico**: [#1309](https://github.com/The-Band-Solution/theband/issues/1309) · **Sprint anterior**: [041](../041-analise-de-rede/sprint-backlog.md)

**Número**: 043. Em `origin/development` o maior é 041, mas o **042 já está tomado** pela 077 (limite
por origem), no commit `82bd9aa` da branch aberta `origin/fix/1229-limite-por-ip-na-entrada`
(`docs/sprints/042-limite-por-origem/`). Usar 042 aqui faria dois sprints com o mesmo número quando
as duas branches chegarem a `development`; a numeração não se recicla. Conferido em 2026-10-05 com
`git log --all -- 'docs/sprints/042*' 'docs/sprints/043*'`.

## Objetivo do sprint

Quem coordena lê, na área **Network analysis**, a análise inteira da referência sobre as duas redes —
comunidades, hubs, distância e eficiência, mundo pequeno, a posição de cada pessoa e o perfil
individual —, com quem está fora do alcance agrupado e sem nome; e as leituras já gravadas ficam
fora de qualquer outra porta e somem quando a observação é encerrada.

## Escopo decidido

> *"quero a identificação das comunidades, dos hubs ... a mesma análise quero todas"*
> — a pessoa mantenedora, ao abrir este sprint (2026-10-05).

Por isso entra **tudo o que falta** do `tasks.md`: US4–US9 (T035–T048) e o Acabamento (T049–T053,
T055). A T054 é 👤 e fica com a pessoa mantenedora; a T003 (👤, medida de produção) continua com ela.

**Ordem — segurança primeiro (`AGENTS.md` §14.0).** Desde a T028 as leituras da análise são gravadas
em `development`. A T051 (a análise fica fora da API, do MCP e do perfil) e a T052 (as leituras são
apagadas ao encerrar a observação) protegem uma superfície **que já existe**, e por isso vêm antes
das US4–US9. Depois, na ordem do `tasks.md`: US4 → US9 e o Acabamento.

## PRs empilhados

| ordem | branch | tarefas | mira | merge |
|---|---|---|---|---|
| 1 | `feature/1309-seguranca` | T051, T052, este documento | `development` | squash |
| 2 | `feature/1309-us4` | T035–T037 | `feature/1309-seguranca` | merge commit |
| 3 | `feature/1309-us5` | T038–T040 | `feature/1309-us4` | merge commit |
| 4 | `feature/1309-us6-us7` | T041–T044 | `feature/1309-us5` | merge commit |
| 5 | `feature/1309-us8-us9` | T045–T048 | `feature/1309-us6-us7` | merge commit |
| 6 | `feature/1309-acabamento` | T049, T050, T053, T055 | `feature/1309-us8-us9` | merge commit |

PR empilhado não fecha issue (L48, memória *fecha em português não fecha issue*): as issues dos PRs
2 a 6 se fecham **à mão** depois do merge de cada um, com a evidência.

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md), lido antes deste documento:

| Lição | Como está sendo aplicada |
|---|---|
| L19 — marcar por tenant marca o que é de outra organização | T052 apaga por tenant **e** organização; o defeito injetado é apagar só por tenant |
| L20 — estado derivado do "último" precisa de desempate determinístico | comunidades desempatam pelo par de menor índice; hubs empatados pelo id, marcados *"tied"* (T035, T040) |
| L41 — teste que compara uma coisa com ela mesma passa sempre | a reprodutibilidade compara dez execuções independentes, e a entrada invertida (T035, T049) |
| L48 — palavra de fechamento não fecha issue em PR empilhado | issues dos PRs 2–6 fechadas à mão |
| L50 — teste que compara precisa provar que mediu | `assert` de leituras/arestas > 0 antes de todo `refute` |
| L53 — o teto de um teste de custo vem da medida dos dois lados | T050 mede antes de fixar o teto |
| L58 — PR empilhado incorporado depois da base não chega a lugar nenhum | cada PR mira a branch anterior; a ordem de merge é a da tabela |
| L60 — o pipe devolve o código do `tail` | `mix gates > log; echo EXIT=$?` |
| L73 — a prova de tela é a imagem | T053 com capturas comparadas ao protótipo |
| L102 — `git add -A` numa árvore compartilhada | commits por caminho explícito |
| L105 — o segredo chega ao texto pela pilha | nenhum `{:ok, _} =` sobre termo com a leitura; o resultado do encerramento leva só contagens |
| L106 — a verificação que ninguém lê | scripts de injeção com `set -e`, cópia antes e `diff` vazio depois |
| L108 — feature sem sprint backlog | este documento existe antes do código das US4–US9 |
| L109 — tarefa fechada sem código | issue só fecha com a evidência do critério como escrito |

## Sprint no GitHub

**Iteration**: Sprint 035 — O operador da plataforma (`ee36a246`), desde 2026-10-03, 7 dias, no
projeto [The Band](https://github.com/orgs/The-Band-Solution/projects/2). As issues da 076 já estão
na iteration desde o sprint 041 (conferido em 2026-10-05, item por item), com `Status = Backlog`.

**Limitações** (as mesmas do 041): `Estimate` não preenchido (ausência, e não zero); `Priority` só
tem P0–P2, e as US P3 ficam sem prioridade.

## User stories

| # | User story | Issue | Priority |
|---|---|---|---|
| US4 | As comunidades | [#1319](https://github.com/The-Band-Solution/theband/issues/1319) | P2 |
| US5 | Os hubs | [#1320](https://github.com/The-Band-Solution/theband/issues/1320) | P2 |
| US6 | Distância e eficiência | [#1321](https://github.com/The-Band-Solution/theband/issues/1321) | — (P3) |
| US7 | Mundo pequeno | [#1322](https://github.com/The-Band-Solution/theband/issues/1322) | — (P3) |
| US8 | O papel de cada pessoa | [#1323](https://github.com/The-Band-Solution/theband/issues/1323) | — (P3) |
| US9 | O perfil individual | [#1324](https://github.com/The-Band-Solution/theband/issues/1324) | — (P3) |

## Tarefas

| # | Tarefa | Atende | Issue | security | PR | Estado |
|---|---|---|---|---|---|---|
| T051 | Guardar a análise fora da API, do MCP e do perfil | épico | [#1376](https://github.com/The-Band-Solution/theband/issues/1376) | sim | 1 | a fazer |
| T052 | Apagar as leituras ao encerrar a observação | épico | [#1377](https://github.com/The-Band-Solution/theband/issues/1377) | sim | 1 | a fazer |
| T035 | Detectar comunidades pelo guloso com peso | US4 | [#1360](https://github.com/The-Band-Solution/theband/issues/1360) |  | 2 | a fazer |
| T036 | Comparar a modularidade com a dos aleatórios, com peso (A5) | US4 | [#1361](https://github.com/The-Band-Solution/theband/issues/1361) |  | 2 | a fazer |
| T037 | Mostrar as comunidades com o recorte | US4 | [#1362](https://github.com/The-Band-Solution/theband/issues/1362) | sim | 2 | a fazer |
| T038 | Calcular distâncias de cada pessoa e a proximidade | US5 | [#1363](https://github.com/The-Band-Solution/theband/issues/1363) |  | 3 | a fazer |
| T039 | Calcular o autovetor por componente | US5 | [#1364](https://github.com/The-Band-Solution/theband/issues/1364) |  | 3 | a fazer |
| T040 | Mostrar os hubs só entre alcançados | US5 | [#1365](https://github.com/The-Band-Solution/theband/issues/1365) | sim | 3 | a fazer |
| T041 | Calcular distância média, diâmetro e eficiência, e as dos aleatórios | US6 | [#1366](https://github.com/The-Band-Solution/theband/issues/1366) |  | 4 | a fazer |
| T042 | Mostrar distância, diâmetro e eficiência | US6 | [#1367](https://github.com/The-Band-Solution/theband/issues/1367) |  | 4 | a fazer |
| T043 | Calcular o clustering e o σ | US7 | [#1368](https://github.com/The-Band-Solution/theband/issues/1368) |  | 4 | a fazer |
| T044 | Mostrar o mundo pequeno como critério | US7 | [#1369](https://github.com/The-Band-Solution/theband/issues/1369) |  | 4 | a fazer |
| T045 | Derivar percentil e papel na leitura | US8 | [#1370](https://github.com/The-Band-Solution/theband/issues/1370) |  | 5 | a fazer |
| T046 | Mostrar as posições por nome, com o critério | US8 | [#1371](https://github.com/The-Band-Solution/theband/issues/1371) | sim | 5 | a fazer |
| T047 | Abrir o perfil só de quem se alcança | US9 | [#1372](https://github.com/The-Band-Solution/theband/issues/1372) | sim | 5 | a fazer |
| T048 | Mostrar o perfil | US9 | [#1373](https://github.com/The-Band-Solution/theband/issues/1373) |  | 5 | a fazer |
| T049 | Provar as cinco redes conhecidas e a reprodutibilidade | épico | [#1374](https://github.com/The-Band-Solution/theband/issues/1374) |  | 6 | a fazer |
| T050 | Medir o teto e o tempo do job | épico | [#1375](https://github.com/The-Band-Solution/theband/issues/1375) |  | 6 | a fazer |
| T053 | Conferir a tela contra o protótipo aprovado — QA e Design | épico | [#1378](https://github.com/The-Band-Solution/theband/issues/1378) |  | 6 | a fazer |
| T055 | Rodar os gates e abrir o PR | épico | [#1380](https://github.com/The-Band-Solution/theband/issues/1380) |  | cada PR | a fazer |

## Fora do escopo deste sprint

| Tarefa | Issue | Por quê |
|---|---|---|
| T003 👤 Medir a rede de designação em produção | [#1327](https://github.com/The-Band-Solution/theband/issues/1327) | precisa de acesso de leitura à produção; o teto de 300 / 3 000 segue provisório |
| T054 👤 Aceitar contra a origem (SC-001, SC-006) | [#1379](https://github.com/The-Band-Solution/theband/issues/1379) | contagem à mão na origem, pela pessoa mantenedora, depois da T053 |

## Decisões já tomadas que valem para a tela

O protótipo aprovado (`specs/076-analise-de-rede/prototipo/`, link e prompt no sprint 041) é a tela.
Decisões que valem aqui:

- comunidades rotuladas por **letra**;
- os três mais centrais de cada comunidade só com escopo **concedido** (DS1);
- o papel como *frase sobre as ligações*, nunca percentil como rótulo de pessoa;
- vistas alternadas pelo seletor;
- a rede inteira, com o que está fora do alcance **sem nome**; nomes só dentro do alcance.

Defeitos da referência que não se repetem: σ dividido por 10; a reserva de 0,01; *"1 componentes"*;
bots ou a conta da organização como nós; rótulo de papel por percentil.

## Riscos e dependências

- **teto provisório** (T003, #1190): 300 pessoas / 3 000 arestas até a medida de produção;
- **custo do layout com alcance parcial** (#1384, aberta): a recomendação de recalcular segue até a
  pessoa mantenedora decidir;
- **mudança semântica na base**: passa por revisão de um subagente independente no papel Ontology &
  Semantic Integration antes de entrar;
- **seis PRs empilhados**: a ordem de merge é a da tabela; fora dela, o PR seguinte chega sem a base.

## Definition of Done do sprint

- [ ] `mix gates` com `EXIT=0`, lido do log, em cada PR
- [ ] cada guarda vista reprovando com o defeito injetado, evidência na issue
- [ ] capturas da tela comparadas ao protótipo (T053)
- [ ] issues encerradas com evidência, ou com o motivo de continuarem abertas
- [ ] `sprint-review.md` escrito; `licoes-aprendidas.md` atualizado
