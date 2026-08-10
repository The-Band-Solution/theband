# Sprint 003 — Corrigir a marca de ausência, e encerrar observação

**Período**: 2026-08-11 a 2026-08-17 (7 dias — cadência semanal)
**Feature**: [003-editar-remover-ferramentas](../../../specs/003-editar-remover-ferramentas/spec.md)
**Plano**: [plan.md](../../../specs/003-editar-remover-ferramentas/plan.md)

## Objetivo do sprint

A marca de "não mais observado" volta a significar o que diz, e a plataforma passa a
saber encerrar a observação de uma organização.

## Duas coisas erradas antes de começar

Registradas em vez de omitidas, porque as duas são minhas.

**Implementei a 003 sem abrir sprint.** A skill `sprint-backlog` diz, na primeira
linha, que ela é obrigatória antes de implementar — e eu fui de `tasks.md` direto para o
código. O trabalho está rastreável pelas 30 tarefas, mas ficou fora do sprint enquanto
acontecia. Este documento o traz para dentro, declarando o que já estava feito.

**A janela do sprint 002 ainda não fechou.** A iteration diz 2026-08-10 a 2026-08-16, e
o sprint foi encerrado e aceito **no primeiro dia**. É a segunda vez que a duração
declarada não corresponde à ocorrida — a primeira virou parte da [L17](../licoes-aprendidas.md).

Este sprint parte de 11/08 e a iteration do 002 continua dizendo 16/08. Corrigir exige
mexer na configuração de iterations, que é o que causou a [L11](../licoes-aprendidas.md)
e custou reatribuir 96 itens. **Fica como decisão pendente**, não como correção
silenciosa.

## Herança — tudo com destino, antes de escopo novo

É a regra que a skill `product-owner` passou a exigir. Item aberto sem destino não é
trabalho, não é decisão e não é descarte.

| O que sobrou | De onde | Destino |
|---|---|---|
| **L19 — marca de ausência sem escopo de organização** | feature 001 | **primeira fase deste sprint.** Está ativa e errada agora |
| **003: F1, F2 e F3 implementadas** | esta feature, fora de sprint | **registradas como feitas**, com o motivo. Não se refaz o que está pronto e verificado |
| **003: US2 — retomar** | esta feature | **entra neste sprint**, depois da L19 |
| **003: US3 e telas restantes** | esta feature | **fora deste sprint**, com o custo declarado abaixo |
| **US2 e US3 da feature 002** | sprint 002 | **no product backlog**, sem iteration — decisão já tomada |
| **Paridade Elixir/Python** | sprints 001 e 002 | **dívida declarada**: 4 verificações contra 12. O gate Python é o que decide, e roda no CI |
| **10 vínculos sem lastro** | feature 002 | **fechada por limitação declarada**, com o conceito nomeado em cada mapeamento |
| **`connected_tools.status` materializa situação** | feature 001 | **dívida declarada**, contra a ADR 0004 D7. Não ampliada pela 003 |
| **Aprovação de revisão registrada** | sprints 001 e 002 | **bloqueada por ferramenta**: com uma identidade, o autor não aprova. Fecha com bot ou GitHub App |
| **Feature 004 — agendamento** | fila da pessoa mantenedora | **não entra**, e a razão está abaixo |

## Por que a L19 vem antes de tudo

Não é prioridade por severidade apenas. É **dependência**.

A promessa do retomar é *"a coleta seguinte devolve vigência ao que a origem ainda
mostra"*. Com a L19, a coleta marca e desmarca errado — não haveria como **demonstrar**
o retomar funcionando, só afirmar. Entregar US2 sobre a L19 produziria uma verificação
que passa sem provar nada.

E o defeito está ativo: `EduardoNFraiz` aparece com zero organizações vigentes estando em
duas observadas. Toda consulta que pede só o vigente devolve menos do que a plataforma
observa.

## Por que a 004 não entra

**Agendamento amplifica a L19.** Hoje o estrago exige alguém disparar uma coleta; com
sincronização periódica, cada execução remarca os vínculos das outras organizações
sozinha, sem ninguém olhando.

Especificar a 004 agora também faria ela assumir uma API de observação que a 003 ainda
pode mudar.

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md) — dezenove lições, L01 a L19.

| Lição | O que muda neste sprint |
|---|---|
| **L19** | é o escopo da primeira fase, e a correção precisa de teste com **duas** organizações e duas coletas em sequência — a forma que os 151 testes não tinham |
| **L18** — um critério atendido não é suficiente | a verificação da L19 não para em "o vínculo certo foi marcado": confere também que **nenhum outro** foi |
| **L17** — execução revela o que implementação esconde | a L19 só apareceu ao demonstrar no banco real. Este sprint demonstra de novo, depois da correção |
| **L03** — teste com dado inválido acha o que o caminho feliz esconde | o teste da L19 é a violação: coletar A e conferir que B não foi marcada |
| **L11** — configurar iterations recria as existentes | nenhuma alteração de iteration sem snapshot antes |
| **L12** — PR não aberto na hora carrega outra feature | o PR da 003 é aberto quando a fase pedir |
| **L14, L15** — revisão | todo PR nasce com revisor pedido, e a lacuna de aprovação é declarada |

## Escopo

| # | Fase | Estado |
|---|---|---|
| **F0** | Herança: corrigir a L19 | **a fazer** — primeira |
| F1 | Base de conhecimento: duas causas | **feito**, fora de sprint |
| F2 | Eventos append-only e estado derivado | **feito**, fora de sprint |
| F3 | Encerrar: marcar por vínculo, destruir credencial | **feito**, fora de sprint |
| F4 | US2 — retomar | a fazer |
| F5 | US3 e telas restantes | **fora do escopo** |

## MVP

**F0 e F4.** A correção da L19 e o retomar.

**O custo de F5 ficar de fora, declarado**: sem as telas de T019 a T022, encerrar existe
na API e a lista de ferramentas não distingue os três estados. Quem encerrar pela API não
verá o resultado refletido. **A tela de encerramento existe** — foi entregue com F3 —,
então o caminho principal está coberto.

## Riscos

| Risco | Mitigação |
|---|---|
| **Corrigir a L19 marcar de menos** | o oposto do defeito atual, e igualmente errado. O teste confere os dois lados: o que deve ser marcado é, e o que não deve não é |
| **Os dados atuais já estão marcados errado** | a correção muda o comportamento futuro; o passado exige decisão à parte — não desmarcar por conta própria, porque não se sabe o que a origem mostrava |
| **Mexer em iterations** | nenhuma alteração sem snapshot; a discrepância da janela do 002 fica declarada |

## Definition of Done

- [ ] nove quality gates verdes
- [ ] a L19 tem teste com duas organizações e duas coletas em sequência
- [ ] a correção é demonstrada no banco real, e `EduardoNFraiz` volta a mostrar duas
      organizações vigentes
- [ ] `sprint-review.md` escrito, separando feito de não feito
- [ ] `aceitacao.md` percorrendo os critérios
- [ ] `licoes-aprendidas.md` atualizado
- [ ] **revisão independente** — declarada, nunca marcada como cumprida por quem implementa
