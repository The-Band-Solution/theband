# Sprint 013 — clicar leva à página, e quem escreveu passa a existir

**Período**: 2026-08-13 a 2026-08-19
**Features**: [014](../../specs/014-clicar-leva-a-pagina/spec.md) · [015](../../specs/015-quem-escreveu-a-issue-tambem-e-observado/spec.md)
**Origem**: [#281](https://github.com/The-Band-Solution/theband/issues/281) e [#283](https://github.com/The-Band-Solution/theband/issues/283)

## Objetivo

Ao fim do sprint, clicar no nome de uma pessoa leva à página dela — e as pessoas que só apareceram
como autoras passam a existir, com identidade vinda da origem.

## A conferência da L44 e da L45

```text
docs/sprints/012-pagina-da-pessoa-mais-rapida/sprint-backlog.md   ✓
docs/sprints/012-pagina-da-pessoa-mais-rapida/sprint-review.md    ✓
specs/013-pagina-da-pessoa-mais-rapida/aceitacao.md               ✓
```

**E onde estão** — L45: os três estão na `main`, incorporados pelo PR #282. Esta branch saiu da
`main` e enxerga tudo.

## Duas features no mesmo sprint, e por que não é um PR só

O sprint 005 já teve duas. O que **não** pode é o mesmo PR: coleta e navegação têm critérios de
revisão diferentes, e `AGENTS.md` §17 proíbe misturar. **Dois PRs, um sprint.**

## Lições aplicadas

| Lição | Como |
|---|---|
| **L25** | identidade pelo `id` da origem, nunca pelo login — foi o que mudou o caminho da 015 |
| **L28** | "a coleta cria" e "a tela liga" são afirmações diferentes; cada uma tem teste próprio |
| **L30** | a medida veio antes: 288 aparições, 15 logins, 135 repositórios já clicáveis |
| **L32** | a tela não afirma o que não observou — nome sem pessoa continua texto |
| **L34** | "membro" e "trabalhou" são duas palavras para coisas diferentes, e a 015 as separa |
| **L42** | o contador de consultas exclui o Oban — foi o que reprovou o CI do sprint 012 |
| **L44**, **L45** | a conferência acima |
| **L49** | medir a cauda: a página da pessoa foi medida em oito pessoas, não numa |

## Escopo

| # | Tarefa | Feature | Fase | Estado |
|---|---|---|---|---|
| 014-T001 | Ligar autor e designados quando há pessoa | 014 | F1 | a fazer |
| 014-T002 | Ligar os membros da equipe | 014 | F2 | a fazer |
| 014-T003 | Nome sem destino continua texto | 014 | F3 | a fazer |
| 014-T004 | Nenhuma consulta nova | 014 | F3 | a fazer |
| 014-T005 | Teclado e sem depender de cor | 014 | F3 | a fazer |
| 015-T001 | Pedir o identificador à origem | 015 | F1 | a fazer |
| 015-T002 | Registrar quem escreveu | 015 | F2 | a fazer |
| 015-T003 | Recusar o que não é pessoa | 015 | F2 | a fazer |
| 015-T004 | Fixar a idempotência | 015 | F2 | a fazer |
| 015-T005 | Membro continua membro | 015 | F3 | a fazer |
| 015-T006 | A organização veio do trabalho | 015 | F3 | a fazer |
| 015-T007 | Conferir no dado real | 015 | F4 | **precisa da chave mestra** |

**Ordem**: a 014 primeiro — ela entrega **8 470** nomes sem depender de coleta. A 015 em seguida move
os 288 restantes.

## O que a análise achou, antes do código

| # | Achado | Correção |
|---|---|---|
| **A1** | `ctx.pessoas` é montado **uma vez**: a pessoa criada no repositório #3 não existiria no mapa ao coletar o #4, e as issues dela ficariam sem vínculo — sem erro | FR-012 e o teste com dois repositórios na mesma execução |
| **A2** | `gravar_issue` lê o mapa na mesma passada: registrar depois deixa `author_person_id` nulo | T002 declara a ordem |
| **A3** | `replace_assignees` grava `person_id` do mesmo mapa — o defeito atinge designado | FR-013 |
| **A4** | contar consultas incluiria o Oban | T004 já exclui |

## Fora do escopo

| Fora | Por quê |
|---|---|
| página de organização | não existe rota; criar é outra decisão de produto |
| papel organizacional | o GitHub não fornece; é a #99/#100 |
| reprocessar payloads antigos para achar autor | eles não têm o `id` — limitação declarada |
| unificar contas da mesma pessoa | o mapeamento já declara que exige regra explícita, nunca heurística |

## Definition of Done

- [ ] `mix gates` verde por código de saída
- [ ] **dois** PRs, um por feature, com revisão pedida à equipe
- [ ] `aceitacao.md` das duas, critério a critério
- [ ] `sprint-review.md` escrito neste sprint — L44
- [ ] lições atualizadas
- [ ] palavra de fechamento das issues **em inglês** — L48
