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

## Notes

Nenhum item incompleto.

**O peso desta spec vem de medida.** 39 repositórios marcados, 899 issues dentro, duas coletas
concluídas depois da última marca e zero limpezas. E o custo já começou:
`leds-conectafapes-prestacao-de-contas` tem 11 issues na origem e 9 no banco.

O agregado da organização está a 3 issues do total da origem — e é isso que esconde o defeito: a
perda é de tudo que for criado a partir de agora.
