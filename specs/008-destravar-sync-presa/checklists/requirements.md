# Specification Quality Checklist: destravar a sincronização presa

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

**Os sete pontos que o pedido levantou foram decididos na spec, e nenhum ficou como pergunta.**
A razão de não haver `[NEEDS CLARIFICATION]` é que cada um tinha resposta derivável do que o
repositório já decidiu:

| Ponto | Decisão | De onde ela vem |
|---|---|---|
| quem encerra | **um caminho de decisão, vários gatilhos** — FR-007 | o projeto pagou três vezes por dois caminhos para a mesma decisão |
| o motivo | distinto por causa, e ausência dita como ausência — FR-002, FR-003 | a L29: falha transitória e permanente não são a mesma coisa |
| estado novo | **não** — `interrupted` já significa "não terminou e não vai terminar" | o estado existe e a `finish/3` já o aceita |
| autor | registrado quando é pessoa, **ausente** quando é a plataforma — FR-009 | decisão tem autor, como `excluded_by_user_id`; e ausente é informação |
| apagar | nada é apagado — FR-004 | regra da plataforma: nunca se apaga dado |
| órfão | **volta a executar** e retoma pelos cursores — FR-010 | a coleta é idempotente por desenho, com checkpoint por entidade |
| escopo | ação só onde a plataforma não prova o trabalho vivo — FR-005, FR-008 | encerrar coleta viva é pior que o problema |

**O defeito oposto entrou como requisito.** FR-005 e o caso de borda 5 existem porque a correção
tem um jeito fácil de ficar pior que o problema: encerrar tudo que está `running` destravaria a
ferramenta e derrubaria a coleta de 4 474 issues que está no meio.

**A ausência do autor é informação, e a spec diz qual.** Nulo significa "quem encerrou foi a
plataforma" — não "não se sabe quem". A plataforma sabe que não foi pessoa, e SC-007 exige que a
tela diga qual dos dois foi.

**O que ficou fora está fora por decisão, não por esquecimento.** Cancelar coleta em andamento é
outra pergunta; painel de fila é outra tela; repetição automática esconderia falha permanente.

## Notes

Nenhum item incompleto.

**O peso desta spec vem de medida, não de hipótese.** Duas execuções já foram destravadas por SQL,
e o procedimento está registrado em `docs/sprints/RETOMAR.md`. Há um trabalho executando desde
2026-08-09 num nó que não existe mais, e cinco descartados — dois deles por módulo que nem existe
no repositório.

O caminho manual já é prática. A feature é transformá-lo em caminho da plataforma.
