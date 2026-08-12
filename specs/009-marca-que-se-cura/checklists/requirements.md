# Specification Quality Checklist: a marca de inacessível se cura

**Purpose**: Validar completude e qualidade da especificação antes do planejamento
**Created**: 2026-08-12
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] Sem detalhe de implementação (linguagem, framework, API)
- [x] Focada em valor para quem usa
- [x] Escrita para quem decide, não para quem implementa
- [x] Todas as seções obrigatórias completas

## Requirement Completeness

- [x] Nenhum marcador `[NEEDS CLARIFICATION]` restante
- [x] Requisitos testáveis e sem ambiguidade
- [x] Critérios de sucesso mensuráveis
- [x] Critérios de sucesso independentes de tecnologia
- [x] Cenários de aceitação definidos para as três user stories
- [x] Casos de borda identificados — cinco
- [x] Escopo delimitado, com o que fica fora e por quê
- [x] Dependências e premissas declaradas

## Feature Readiness

- [x] Cada requisito funcional tem critério de aceitação
- [x] Os cenários cobrem o fluxo principal
- [x] A feature atende aos resultados mensuráveis
- [x] Nenhum detalhe de implementação vazou

## O que a validação achou, e entrou na spec

**Os sete pontos do pedido foram decididos, e nenhum ficou como pergunta** — cada um tinha resposta
derivável do que o repositório já decidiu:

| Ponto | Decisão | De onde vem |
|---|---|---|
| tentar todos, ou por critério | **todos, sempre** | critério de tempo é constante que envelhece, e esta sessão a recusou duas vezes — no `rescue_after` e na carência |
| a data da marca ao falhar de novo | preserva o **começo**; o motivo carrega a **última** falha | são duas informações diferentes, e nenhuma exige coluna nova |
| distinguir "uma vez" de "há dias" | a **data** distingue, e não um estado novo | estado a mais obriga toda leitura a conhecê-lo |
| lista de erros com naturezas mistas | vence o **mais permanente** | marcar de menos volta a esconder repositório apagado |
| a tela muda? | sim: **desde quando** e **o motivo**, em texto | `unreachable` sozinho lê como abandono, e era verdade |
| excluído contra inacessível | **exclusão vence**, e não é tentado | exclusão é decisão de alguém; a plataforma não a desfaz |
| limpar a marca apaga o histórico | **sim, e é aceito** — declarado nas premissas | histórico de incidente exige evento append-only e necessidade de informação própria |

**O requisito que ninguém pediu e entrou: FR-014.** O relatório da coleta não diz quantos
repositórios não foram alcançados. Sem esse número, a próxima vez que 39 caírem também vai passar
em silêncio — e o percentual da tela continuará fechando em 100%, porque o denominador só conta o
que a plataforma decidiu olhar. É a L29 na parte que a correção anterior não cobriu.

**O caso de borda 1 é desconforto declarado, não resolvido.** Repositório apagado na origem vai ser
tentado para sempre. A alternativa é desistir, que é exatamente o defeito desta feature — então o
ruído fica, e se incomodar o critério será a **natureza do erro**, nunca o tempo.

## O que a análise achou depois, e uma correção é crítica

`/speckit-analyze` rodou antes do código. **Quatro das sete suspeitas procederam**, e a mais grave
não tinha nada a ver com a lógica da feature:

| # | O que estava errado | O que passou a valer |
|---|---|---|
| **A1** | `inaccessible_reason` é **`varchar(255)`**, o maior motivo gravado tem 181 e o da falha interna dá ~228 — **27 de folga**. Sem `validate_length`, o valor longo vai ao banco e **levanta**, e o tratamento de erro da coleta cobre changeset inválido, não exceção do driver | coluna vira `text`, truncagem na borda — FR-015, T001. **É a L05 literal**, e a feature multiplicava a frequência de escrita |
| A2 | SC-001 dizia "zero dos 39", o que é **inverificável**: um repositório inacessível porque a credencial não alcança volta a ser marcado, corretamente, e o critério reprovaria por estar certo | "nenhum repositório **que a origem alcança** permanece marcado" |
| A3 | o número de não alcançados era gravado **no fim** da fase; coleta interrompida ficaria com zero, afirmando que tudo foi alcançado | incremento **a cada** falha — FR-014a, SC-009a |
| A4 | a justificativa da ordem F1→F2 era **falsa**: sem F1, o repositório marcado por engano é tentado e limpo na coleta seguinte | a ordem é preferência declarada — F1 para de sangrar, F2 cura o que existe |
| A5 | "33 dos 39 têm zero issues" foi medido com a credencial de quem conferiu, não com a da plataforma | limitação declarada em R6, e o custo estimado é **piso**, não teto |
| A6 | o motivo ia para a tela sem limite | truncado na exibição, com o texto completo no `title` — T009 |

**Três suspeitas não procederam, e as três foram medidas** em vez de aceitas: o orçamento da origem
(`cost = 1` por página, 160 pontos de 5 000 — sem risco), outro consumidor de `list_collectable/2`
(**um** de produção, zero em teste), e `clear_inaccessible/2` deixar o motivo para trás (ele limpa os
**dois** campos).

## Notes

Nenhum item incompleto.

**Dezesseis requisitos, doze critérios.** Cresceu em relação à primeira versão — 14 e 10 —, e o
acréscimo veio todo da análise.

**O peso desta spec vem de medida.** 39 repositórios marcados, 899 issues dentro, duas coletas
concluídas depois da última marca e zero limpezas. E o custo já começou:
`leds-conectafapes-prestacao-de-contas` tem 11 issues na origem e 9 no banco.

O agregado da organização está a 3 issues do total da origem — e é isso que esconde o defeito: a
perda é de tudo que for criado a partir de agora.
