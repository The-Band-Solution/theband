# Sprint 006 — Review

**Período**: 2026-08-12 a 2026-08-18
**Feature**: [007 — marca de issues](../../specs/007-marca-de-issues/spec.md)
**PR**: [#195](https://github.com/The-Band-Solution/theband/pull/195), base
`007-interface-em-ingles`

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| User stories | 2 | 2 |
| Tarefas | 7 | 7 |
| Entregáveis aceitos | 7 | **7** |

**Incorporado em 2026-08-12T12:21:51Z**, PR [#195](https://github.com/The-Band-Solution/theband/pull/195),
depois do #184 — a ordem importava, porque a marca aplica o design system que vive lá.

`main` em `277d159` com **10 gates verdes por código de saída**. A avaliação critério por
critério está em [aceitacao.md](../../specs/007-marca-de-issues/aceitacao.md): **10 dos 11 SC
atendidos**, e o restante — SC-009, legibilidade em 360 px — está declarado como **não
verificado**, porque a estrutura existe e ninguém olhou a tela. Declarar atendido seria declarar
sucesso sem evidência.

## O que foi feito

| Tarefa | Issue | Entregável | Estado |
|---|---|---|---|
| T001 | [#188](https://github.com/The-Band-Solution/theband/issues/188) | `count_collected_by_repository/2` — consulta agrupada de issues vigentes, com 5 testes | aceito |
| T002 | [#189](https://github.com/The-Band-Solution/theband/issues/189) | `por_repositorio/2` faz **1** consulta em vez de 135 | aceito |
| T003 | [#190](https://github.com/The-Band-Solution/theband/issues/190) | migração `issues_collected_at`, campo no schema e em `list_observed/2`; round trip conferido | aceito |
| T004 | [#191](https://github.com/The-Band-Solution/theband/issues/191) | `CMPO.mark_issues_collected/3`, gravada no mesmo ponto do checkpoint, com 2 testes de ingestão | aceito |
| T005 | [#192](https://github.com/The-Band-Solution/theband/issues/192) | a marca com três canais, contagem decidindo primeiro | aceito |
| T006 | [#193](https://github.com/The-Band-Solution/theband/issues/193) | `no current work` — houve trabalho e não há vigente | aceito |
| T007 | [#194](https://github.com/The-Band-Solution/theband/issues/194) | os 135 seguem clicáveis, inclusive os 94 sem trabalho | aceito |

## O que não foi feito

| Item | Motivo | Destino |
|---|---|---|
| iteration própria do sprint no ProjectV2 | configurar iterations recria as existentes — L11, custou reatribuir 96 itens | product backlog, decisão da pessoa mantenedora |
| tipos `Epic` e `User Story` na organização | criar tipo altera a configuração da organização | product backlog |
| verificação visual de V1 e V7 (olho na tela, 360 px) | os três estados estão asseridos no HTML renderizado, e ninguém **olhou** | pendente — SC-009 registrado como não verificado na aceitação |

## Duas mudanças de desenho durante a execução, e as duas são declaradas

### O contrato ganhou uma terceira função

`repositories_with_absent_issues/2`. O contrato declarava duas, e o quarto texto —
`no current work` — **não é derivável** delas: a contagem de vigentes não distingue "nunca teve
issue" de "teve e não tem mais". A correção entrou no mesmo commit, e o contrato registra o
porquê.

### O texto do terceiro estado mudou, e a razão foi medida

Era `not collected yet`, que **afirma** que a coleta não ocorreu. Medido no banco depois da
migração: 94 repositórios com data nula, e a coleta visitou **61** deles e não achou nada. Dizer
"não coletado" sobre eles é a tela afirmando o que não observou.

Virou **`no collection recorded`** — nomeia a ausência do **registro**, que é o que existe. É o
mesmo princípio do achado A1, na direção oposta: não afirmar coleta que não houve, e não afirmar
ausência de coleta que houve.

## O defeito que o teste desta feature achou em código que já existia

O teste de T004 reproduz a corrida real — o repositório sai da observação **durante** a fase — e
a fase morreu com `MatchError` em `{:ok, _} = CMPO.clear_inaccessible/2`, **um ponto antes** do
código novo. As duas chamadas agora registram em log com o nome do repositório e seguem.

Não é fallback silencioso: o log nomeia, e nada depois lê a data como se ela existisse.

## Evidências

**Os dez gates, por código de saída:**

```
$ mix gates > /tmp/gates2.txt 2>&1; echo "exit=$?"
exit=0

10 gates verdes.
```

370 testes, 19 novos.

**V9 no dado real** — a medida que a análise pediu, contra o banco de desenvolvimento **depois**
da migração:

```
observados=135  com_data=0  sem_data_com_issues=41  sem_issues_vigentes=94
```

Nenhuma coleta anterior registrou a data. Os 41 aparecem com trabalho porque a contagem decide
primeiro; se a data decidisse, os 41 apareceriam como não coletados.

**Os dois defeitos, verificados por reprovação** — invertendo o código de propósito:

| Defeito introduzido | Testes que reprovaram |
|---|---|
| data decidindo antes da contagem | **5**, incluindo o de FR-005a com a mensagem sobre os 41 |
| forma igual nos três estados, distinguindo só por cor | **1**, o de WCAG 1.4.1 |

Um teste que não reprova quando o defeito existe não é evidência de nada — é a L18.

## Dívida gerada

| Dívida | Por quê |
|---|---|
| a marca só existe em `/work` | FR-013 fechou o escopo; o segundo chamador é o que justifica o componente — R1 |
| os 135 seguem sem `issues_collected_at` até a próxima coleta | a migração não inventa data que não foi observada; a coleta grava |
| dois sprints sem iteration no ProjectV2 | `flow.throughput` e `flow.wip.count` não separam 003 a 006 |

## Lições deste sprint

**L32 — Texto que afirma o que a plataforma não observou é o mesmo defeito, na direção
oposta.** A feature nasceu para impedir que ausência fosse desenhada como zero, e a primeira
versão do texto dizia `not collected yet` sobre 94 repositórios de que a plataforma só sabe não
ter registro. Vigiar uma direção e não a outra é fácil: as duas são a mesma pergunta — *o que
esta frase afirma, e a plataforma observou isso?*

**L33 — A pergunta que a análise faz e o teste de unidade não faz é "o que a tela diz no dia da
migração".** Cada peça de A1 funcionava. O defeito só aparece quando se pergunta pelo estado do
mundo no instante seguinte à mudança de esquema — e nenhum teste de unidade tem esse instante
como cenário.

Detalhamento em [licoes-aprendidas.md](../licoes-aprendidas.md).
