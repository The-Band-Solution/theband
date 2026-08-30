# Sprint 025 — Review

**Período**: 2026-08-29 (um dia)
**Herança**: retrabalho das US 047/US1–US2 · **Feature**: [051](../../specs/051-cadastro-por-github/spec.md)
**PRs**: [#611](https://github.com/The-Band-Solution/theband/pull/611) (retrabalho, squash) e
[#612](https://github.com/The-Band-Solution/theband/pull/612) (051, squash) — CI verde,
revisão pedida ao abrir nos dois, ambos no board.

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| User stories | 4 (2 herdadas + 2 novas) | 4 avaliadas |
| Tarefas | 10 (2 herança + 8 da 051) | 10 executadas |
| Entregáveis aceitos | 4 | **2** (D2 pendências, D3 cadastro) |

**Aceitação** ([registro completo](aceitacao.md)): confirmada pela pessoa mantenedora
em 2026-08-29. **#574 e #597 ACEITAS** com ressalvas; **#573 NÃO ACEITA pela segunda
vez** (o retrabalho fechou o contraexemplo e deixou o irmão: frases nascendo em
FUNÇÃO DE ORIGEM — `PatternValidator.explicar/1` no domínio e `primeira_mensagem/1`
— fora do catálogo e fora das pendências); **#598 NÃO ACEITA** (dois critérios de
borda escritos em spec/contrato/tasks e não entregues: organização na busca de
homônimos e observação terminada dita — com o agravante do comentário no código
contradizendo o contrato sem correção registrada).

## O que foi feito

| Tarefa | Issue | Entregável | Sucesso |
|---|---|---|---|
| 047/T012 | [#609](https://github.com/The-Band-Solution/theband/issues/609) | Verificador v2 (classe assign, 13 migrados por AST) | **não** — a classe função-origem ficou de fora, e a US1 caiu de novo |
| 047/T013 | [#610](https://github.com/The-Band-Solution/theband/issues/610) | Pendências com amostragem (L80), US3 alinhada | sim |
| 051/T001–T002, T004 | [#599](https://github.com/The-Band-Solution/theband/issues/599), [#600](https://github.com/The-Band-Solution/theband/issues/600), [#602](https://github.com/The-Band-Solution/theband/issues/602) | Cadastro transacional com temporária no ato | sim |
| 051/T003, T005–T008 | [#601](https://github.com/The-Band-Solution/theband/issues/601), [#603](https://github.com/The-Band-Solution/theband/issues/603)–[#606](https://github.com/The-Band-Solution/theband/issues/606) | O elo na área (busca, conflito nomeado, revogação) | **não** — dois edge cases da spec não entregues |

## O que não foi aceito, e o destino

Retrabalho nomeado e finito, **primeiro na fila do sprint 026** (tarefas novas,
nunca reabertura):

1. **#573**: a borda traduz o motivo — PatternValidator devolve tuplas,
   `humanizar/1` completa, `primeira_mensagem/1` e `motivo/1` pelo catálogo (os
   msgids do Ecto já existem em errors.po). 5 frases + 2 helpers.
2. **#598**: organização no resultado da busca + marca de observação terminada.

## Defeitos e correções no caminho (fora do escopo do sprint, na sessão)

- Flake da `API_KEY` (restauração assimétrica de env em teste) decidia CI por seed —
  consertado na raiz (#607) com três seeds fixos como prova.
- Gitflow adotado (constituição 1.7.0): `development` integra, **merge na `main` é
  deploy**; PRs remirados, branch default trocada.
- Hook do impeccable ligado para `.ex`/`.heex` (#615): o detector de design roda a
  cada edição de página.

## Evidências

- Gates 14/14 com EXIT no log nas duas branches; CI verde; `mix mensagens.verificar`
  EXIT=0 com a classe assign dentro; 13+6 testes novos verdes; o ciclo
  associar→revogar→login provado de ponta a ponta; captura da lista com os dois
  estados ao vivo, olhada.
- A aceitação executou as evidências de novo, de forma independente — e foi ela que
  achou os dois casos que os gates não veem.

## Dívida gerada

- Rótulos de situação (`origem_rotulo/1`) — classe HEEx-pendência por decisão do
  papel, nomeados nas pendências.
- Dois testes prometidos no contrato da 051 e não escritos (contagem de consultas
  L38 e de temporárias emitidas) — comportamento conferido por leitura.
- Eventos de busca não apagam a temporária (diverge do moduledoc; não reaparece).
- Revisão registrada: zero pela terceira família de PRs — pedido existe, revisão
  não; a saída estrutural (PR por identidade de agente) segue não decidida.

## Lições deste sprint

No [registro acumulado](../licoes-aprendidas.md): **L81** (fechar o contraexemplo
não fecha a classe — caçar os irmãos pelo padrão antes de entregar retrabalho) e
**L82** (comentário que contradiz o contrato é a violação documentando a si mesma —
divergir exige correção registrada no mesmo commit, e o verificador disso é a
aceitação).
