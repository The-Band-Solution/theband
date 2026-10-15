# Sprint 044 — Observabilidade da entrada: o que falta da 074

**Período**: 2026-10-14 a 2026-10-20 (7 dias)
**Feature**: [074](../../../specs/074-jornada-entrar-e-sair/spec.md) · **Plano**: [plan.md](../../../specs/074-jornada-entrar-e-sair/plan.md) · **Tarefas**: [tasks.md](../../../specs/074-jornada-entrar-e-sair/tasks.md)
**Sprint anterior da mesma feature**: [038](../038-jornada-entrar-e-sair/sprint-backlog.md) (T001–T020, mergeado no #1311)

## Objetivo do sprint

Quem opera passa a saber quando definir ou trocar a senha falhou (US4), e encontra as três respostas da
entrada num painel e num alerta do SigNoz, sem escrever consulta (US5).

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md), lido em 2026-10-14 pelas sete regras de família:

| Lição | Família | Como está sendo aplicada |
|---|---|---|
| L11 | O passo do ciclo sem dono | **Reincidiu ao abrir este sprint**: ver *Incidente* abaixo. A regra passa a ser o retrato antes de qualquer mutação de iteration, e a conferência item a item depois |
| O defeito que não produz erro | regra da família | cada teste da T021 é visto reprovando com o defeito do `tasks.md` (o motivo derivado de `inspect(changeset.errors)`) |
| Teste que não prova o que diz provar | regra da família | o painel e o alerta (T022, T023) são conferidos no SigNoz local com a captura anexada, e não só pelo JSON |
| Afirmar sem medir na origem | regra da família | a T030 mede a mediana com e sem telemetria. O número entra na ADR, e não é estimado |
| Revisão e PR | regra da família | revisor é a equipe `the-band`, conferido em `reviewRequests`; o template inteiro |

## Sprint no GitHub

**Iteration**: Sprint 044 — Observabilidade da entrada (074) · 2026-10-14 · 7 dias (`77d8b35c`)
**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)

### Incidente ao criar a iteration (2026-10-14)

Não havia iteration ativa: a última, a Sprint 035, terminou em 2026-10-10. A premissa foi que, sem
iteration ativa, as completas seriam preservadas. Essa premissa não foi medida, e estava errada.
`updateProjectV2Field.iterationConfiguration` **apagou as seis completas** (Sprint 023, 024, 025, 026,
034 e 035), e os **536 itens** que as tinham ficaram sem Iteration. É a L11, que já estava escrita e
foi lida antes da mutação.

**O reparo**:

1. Antes da mutação tinha sido tirado um retrato de cada item com a iteration dele (o que a L11
   manda).
2. As seis iterations foram recriadas com os mesmos títulos e datas, mas com ids novos.
3. Os 536 itens foram reatribuídos pelo título: 207 na primeira passada e 328 na segunda. As falhas
   eram de rede e de limite de taxa.
4. A conferência por consulta deu **"IDENTICO: cada item na mesma iteração de antes"** (536 contra
   536).

O que se perdeu foram os **ids** antigos das iterations. Quem os guardou fora do GitHub, como os
backlogs dos sprints 023 a 043, tem agora ids que não existem mais.

**Limitações herdadas**: os tipos `Epic` e `User Story` seguem fora da organização; `Estimate` não é
preenchido (é ausência, e não zero); `Priority` vai só até P2.

## User stories selecionadas

| # | User story | Issue | Priority | Estimate | Critérios |
|---|---|---|---|---|---|
| US4 | Sei quando definir ou trocar a senha falhou | [#1233](https://github.com/The-Band-Solution/theband/issues/1233) | P2 | — | os da spec, *User Story 4* |
| US5 | Quem opera encontra as respostas sem montar consulta | [#1234](https://github.com/The-Band-Solution/theband/issues/1234) | P2 | — | os da spec, *User Story 5* |

## Tarefas

| # | Tarefa | Atende | Issue | Estado |
|---|---|---|---|---|
| T021 | Definir e trocar a senha emitem o desfecho | US4 | [#1255](https://github.com/The-Band-Solution/theband/issues/1255) | a fazer |
| T022 | O painel das três perguntas | US5 | [#1256](https://github.com/The-Band-Solution/theband/issues/1256) | a fazer |
| T023 | O alerta de enumeração de contas | US5 | [#1257](https://github.com/The-Band-Solution/theband/issues/1257) | a fazer |
| T030 | Medir o custo da telemetria na entrada | — | [#1264](https://github.com/The-Band-Solution/theband/issues/1264) | a fazer |
| T031 | Rodar os gates e abrir o PR | — | [#1265](https://github.com/The-Band-Solution/theband/issues/1265) | a fazer |
| T029 | Atualizar o runbook | — | [#1263](https://github.com/The-Band-Solution/theband/issues/1263) | bloqueado pela T026 (👤) |

**O que já existe da T021**: os pontos de emissão em `session_controller.ex` (`definir_a_senha` e
`trocar_a_senha`, com todos os motivos) entraram com o MVP (#1311), e o #1426 acrescentou à régua os
motivos da espera (`em_espera`, `tentativas_esgotadas`). **Falta o que a tarefa pede como prova**:
- os sete casos de *A régua* em `regua_test.exs`;
- os passos de senha em `sentinelas_test.exs`;
- o defeito de derivar o motivo do changeset, visto reprovando.

## Fora do escopo deste sprint

| Tarefa | Issue | Por quê |
|---|---|---|
| T024 Medir o VPS antes de subir | [#1258](https://github.com/The-Band-Solution/theband/issues/1258) | 👤 pessoa mantenedora, em produção |
| T025 Consertar a distribuição Erlang | [#1259](https://github.com/The-Band-Solution/theband/issues/1259) | 👤, e depende da #1162 fechada com a evidência de produção |
| T026 Subir o SigNoz no Dokploy | [#1260](https://github.com/The-Band-Solution/theband/issues/1260) | 👤 |
| T027 Ligar a aplicação ao coletor | [#1261](https://github.com/The-Band-Solution/theband/issues/1261) | 👤, depois da T026 |
| T028 Medir depois | [#1262](https://github.com/The-Band-Solution/theband/issues/1262) | 👤, depois da T027 |

As US4 e US5 só são **aceitas** em produção depois da T027. Até lá, o painel e o alerta são
conferidos no SigNoz local.

## Riscos e dependências

- **O SigNoz local** (o profile `telemetria` do `compose.yaml`, da T006) precisa subir na máquina de
  desenvolvimento para a T022 e a T023. Se não couber na memória, a conferência vai para quando
  houver máquina, e a lacuna fica declarada.
- **A T030** compara 200 entradas com e sem telemetria. Se a diferença passar de 5%, a ADR 0005 volta
  à mesa (alternativa "log estruturado"), e isso é decisão da pessoa mantenedora.

## Definition of Done do sprint

- [ ] quality gates verdes (`mix gates`, código de saída lido sem pipe)
- [ ] base de conhecimento válida
- [ ] cada guarda vista reprovando com o defeito injetado
- [ ] o painel e o alerta importados no SigNoz local, com captura
- [ ] issues encerradas ou repriorizadas com justificativa
- [ ] `sprint-review.md` escrito
- [ ] `licoes-aprendidas.md` atualizado, com a **reincidência da L11**
