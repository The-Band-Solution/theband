# Sprint 008 — a marca de inacessível se cura

**Período**: 2026-08-12 a 2026-08-18 (cadência de uma semana)
**Feature**: [009 — marca que se cura](../../../specs/009-marca-que-se-cura/spec.md)
**Plano**: [plan.md](../../../specs/009-marca-que-se-cura/plan.md)
**Origem**: [#213](https://github.com/The-Band-Solution/theband/issues/213) e
[#214](https://github.com/The-Band-Solution/theband/issues/214), **Bug, P0**
**Análise**: rodada antes do código, **seis correções**, uma delas crítica

## Objetivo do sprint

Ao fim deste sprint, **899 issues voltam a ser alcançadas** — e a próxima queda não passa em
silêncio.

Uma falha de rede de um instante tirou 39 repositórios da coleta. Duas coletas concluíram depois
disso e **nenhuma limpou nada**, porque o repositório inacessível é filtrado **antes** da fase que
limparia a marca.

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md), 35 lições. As que entram como **restrição**:

| Lição | Origem | Como está sendo aplicada |
|---|---|---|
| **L05** | Sprint 001 | é a lição que a análise trouxe de volta: `inaccessible_reason` é `varchar(255)` com **27 caracteres de folga**, e coluna de diagnóstico não tem limite arbitrário. T001 |
| **L28** | Sprint 005 | "a função classifica" e "o repositório não é marcado" são afirmações diferentes: T003 é o teste de ponta a ponta, com asserção **no banco** |
| **L29** | Sprint 005 | é o defeito que esta feature corrige, e a segunda vez que ele aparece |
| **L30** | Sprint 005 | os números vêm da origem e do banco, não de estimativa — e a medida do custo (`cost = 1`, 160 de 5 000) derrubou uma suspeita |
| **L32** | Sprint 006 | zero em `repositories_unreachable` **afirma** que tudo foi alcançado; por isso o número é incrementado a cada falha, e não no fim |
| **L34** | Sprint 007 | "inacessível" cobria duas coisas — decisão do tenant e inferência da plataforma — e `list_collectable/2` tratava as duas como uma |
| **L35** | Sprint 007 | **é o corolário que abriu este sprint**: *cura que pressupõe um passo que o filtro impede não é cura* |
| L08, L18, L22, L23, L27 | 002 a 005 | contrato antes da função; aceitação com evidência por critério; gate por código de saída; ciclo completo antes do código |

**A L35 é a razão de este sprint existir**, e ela foi escrita há duas horas. A correção da L29
declarou *"a cura é a própria coleta — alcançou, limpa"*, e o corolário da L35 pede para conferir se
o caminho da cura é **alcançável**. Não era.

## Sprint no GitHub

**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)

**Iteração**: **não existe para este sprint** — limitação declarada, não esquecimento. Configurar
iterations do ProjectV2 recria as existentes (L11), e já custou reatribuir 96 itens.

**Tipos**: a organização tem `Task`, `Bug` e `Feature`. Épico e user stories são tipados `Feature`.

## User stories selecionadas

| # | User story | Épico | Issue | Priority | Estimate | Estado |
|---|---|---|---|---|---|---|
| US1 | A coleta volta a alcançar o que falhou | [#216](https://github.com/The-Band-Solution/theband/issues/216) | [#217](https://github.com/The-Band-Solution/theband/issues/217) | **P0** | 11 | feito |
| US2 | Falha do momento não vira decisão permanente | [#216](https://github.com/The-Band-Solution/theband/issues/216) | [#218](https://github.com/The-Band-Solution/theband/issues/218) | **P0** | 8 | feito |
| US3 | Ver desde quando não se alcança, e por quê | [#216](https://github.com/The-Band-Solution/theband/issues/216) | [#219](https://github.com/The-Band-Solution/theband/issues/219) | P1 | 5 | feito |

**US1 e US2 são P0**: enquanto elas não entram, 899 issues estão fora de toda coleta futura e o
número cresce sozinho.

## Tarefas

Detalhadas em [009/tasks.md](../../../specs/009-marca-que-se-cura/tasks.md). Cada tarefa é filha da
**user story que ela atende** — nunca do épico.

| # | Tarefa | Atende | Issue | Estimate | Fase | Estado |
|---|---|---|---|---|---|---|
| T001 | Tirar o limite da coluna de motivo | US2 | [#220](https://github.com/The-Band-Solution/theband/issues/220) | 2 | F1 | feito |
| T002 | Julgar a natureza do erro da origem | US2 | [#221](https://github.com/The-Band-Solution/theband/issues/221) | 5 | F1 | feito |
| T003 | Não marcar por falha do momento | US2 | [#222](https://github.com/The-Band-Solution/theband/issues/222) | 2 | F1 | feito |
| T004 | Voltar a tentar o repositório marcado | US1 | [#223](https://github.com/The-Band-Solution/theband/issues/223) | 3 | F2 | feito |
| T005 | Preservar desde quando não se alcança | US1 | [#224](https://github.com/The-Band-Solution/theband/issues/224) | 2 | F2 | feito |
| T006 | Limpar a marca ao alcançar | US1 | [#225](https://github.com/The-Band-Solution/theband/issues/225) | 2 | F2 | feito |
| T007 | Concluir mesmo com tudo falhando | US1 | [#226](https://github.com/The-Band-Solution/theband/issues/226) | 3 | F2 | feito |
| T008 | Contar os repositórios não alcançados | US3 | [#227](https://github.com/The-Band-Solution/theband/issues/227) | 3 | F3 | feito |
| T009 | Dizer desde quando, e por quê | US3 | [#228](https://github.com/The-Band-Solution/theband/issues/228) | 2 | F3 | feito |

**Total: 24 de complexity, nove tarefas.**

## O que a análise mudou, antes do código

| # | Achado | Correção |
|---|---|---|
| **A1** | `inaccessible_reason` é `varchar(255)`; o motivo real dá **~228** com o prefixo, e o maior gravado hoje tem 181. Sem `validate_length`, o valor longo vai ao banco e **levanta** — e o tratamento de erro da coleta cobre changeset inválido, não exceção. **A fase cai** | T001: coluna vira `text`, truncagem na borda |
| A2 | SC-001 dizia "zero dos 39", e era inverificável | "nenhum repositório **que a origem alcança**" |
| A3 | o número de não alcançados gravado no fim deixaria **zero** numa coleta interrompida | incremento a cada falha — a regra do checkpoint |
| A4 | a justificativa da ordem F1→F2 era **falsa** | F1 para de sangrar, F2 cura; ordem preferida, não dependência |
| A5 | "33 dos 39 têm zero issues" foi medido com credencial diferente da plataforma | limitação declarada; o custo é **piso** |
| A6 | o motivo ia para a tela sem limite | truncado na exibição, completo no `title` |

**O A1 é o achado que justifica a fase ter existido**, e ele não é sobre a lógica da feature: é sobre
a feature **multiplicar a frequência** de uma escrita que já estava a 27 caracteres de derrubar a
coleta.

## Escopo confirmado

**Feature 009 completa — F1 a F3, T001 a T009.**

**O MVP é F1+F2**: os 39 voltam à coleta e as 899 issues voltam a ser alcançadas. **F3 não é
opcional para declarar a feature completa** — sem o número de não alcançados, a próxima queda
conclui com sucesso e 100%, porque o denominador só conta o que a plataforma decidiu olhar. Foi assim
que este defeito viveu dois dias.

## Fora do escopo deste sprint

| Fora | Por quê |
|---|---|
| histórico de incidentes por repositório | exige evento append-only e necessidade de informação própria |
| desistir de repositório que falha há muito tempo | é o defeito que esta feature corrige |
| módulo de classificação de erro | a pergunta já tem lugar — princípio X |
| `last_attempt_at` | o registro de sincronização já data a última tentativa |
| **página de detalhe da pessoa** | [#211](https://github.com/The-Band-Solution/theband/issues/211), com ciclo próprio |

## Riscos e dependências

| Risco | Mitigação |
|---|---|
| **motivo longo derrubar a fase de coleta** | T001 primeiro: coluna `text` e truncagem na borda |
| zero afirmar que tudo foi alcançado | incremento por falha; teste com falha total **e** com interrupção |
| repositório apagado consultado para sempre | `NOT_FOUND` é permanente; custo medido de 1 consulta por coleta |
| a classificação depender de texto de terceiro | teste com o **payload real**; e a cura torna a marca reversível |
| exclusão ser desfeita por engano | excluído **nunca** é tentado; teste conta as requisições |

**Nenhuma dependência de outra branch.** A `012-marca-que-se-cura` sai de `main`.

## Definition of Done do sprint

- [x] `mix gates` verde pelo **código de saída** — dez gates, em `main` (`26f8a45`), 430 testes
- [x] V1 e V4 a V9 do [quickstart](../../../specs/009-marca-que-se-cura/quickstart.md) verificados
- [ ] **V2 e V3 — no dado real**: exigem a chave mestra e o token, que são da pessoa mantenedora.
      Declarado como pendente na [aceitação](../../../specs/009-marca-que-se-cura/aceitacao.md), e o
      mecanismo está medido no banco: **96 → 135** repositórios coletáveis
- [x] as nove issues encerradas — #216 a #228, todas `Done` no projeto
- [x] PR [#230](https://github.com/The-Band-Solution/theband/pull/230) com revisor `the-band`
      **conferido** por `requested_reviewers`, ligado ao projeto, incorporado em `26f8a45`
- [x] [`sprint-review.md`](sprint-review.md) escrito, separando feito de não feito
- [x] `licoes-aprendidas.md` atualizado — L36 e L37, e a **L36 foi reescrita** quando o experimento
      mostrou que o mecanismo que eu havia publicado estava errado
- [x] [`aceitacao.md`](../../../specs/009-marca-que-se-cura/aceitacao.md) com os 12 SC avaliados um a um

**O sprint fecha com um item aberto e ele está nomeado**: a prova no dado real. Marcar como feito o
que depende de credencial que não é minha seria declarar sucesso sem evidência.
