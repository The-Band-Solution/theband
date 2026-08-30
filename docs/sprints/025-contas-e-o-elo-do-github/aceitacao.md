# Sprint 025 — Registro de aceitação

**Avaliado em**: 2026-08-29, na `development` (PRs #611 e #612 mergeados), pelo papel
de product-owner com evidência executada. **Confirmado pela pessoa mantenedora em
2026-08-29** nas quatro decisões reservadas: os quatro vereditos como propostos; os
rótulos de situação classificados como classe HEEx-pendência (mantém #574 aceita);
retrabalho completo para a #598.

## Veredito por user story

| US | Issue | Veredito | Critério decisivo |
|---|---|---|---|
| 047/US1 — erros no catálogo | #573 | **NÃO ACEITA (segunda vez)** | O retrabalho fechou o contraexemplo do 024 e deixou o irmão dele: 5 recusas em literal chegando à tela POR TRÁS de chamada de função (`PatternValidator.explicar/1` — domínio fabricando frase de tela, contra a regra do próprio contrato — e `primeira_mensagem/1` do projects_live, que ainda descarta os msgids do Ecto que `errors.po` JÁ tem). Editar o catálogo não muda essas frases: AS1 falha na letra. A classe é finita (grep da forma: só esses 2 helpers) |
| 047/US2 — sistema no catálogo | #574 | **ACEITA com ressalvas** | As três causas da recusa do 024 fechadas com evidência (dgettext nos pontos, pendências refeitas com amostragem, FR-007 condicionado registrado). Ressalvas: `origem_rotulo/1` classificado pela decisão do papel como HEEx-pendência — entra nomeado nas pendências; a afirmação "razão do FR-007 vive nos comentários do HEEx" não se confirmou nos três pontos de "Checks" (lacuna de prova da afirmação, corrigida nas pendências) |
| 051/US1 — cadastrar nome+e-mail | #597 | **ACEITA com ressalvas** | 3/3 cenários com evidência; a mudança do teste da 045 é legítima (L71, razão no teste). Ressalvas: eventos de busca não apagam a temporária (diverge do moduledoc; ela não reaparece, mas persiste durante a busca); dois testes prometidos no contrato não existem (contagem de consultas L38 e de temporárias) — comportamento conferido por leitura, prova pendente |
| 051/US2 — associar o GitHub | #598 | **NÃO ACEITA** | 5 AS e 4 SC conformes; falham DOIS critérios de borda que spec (linhas 93-97), contrato e tasks exigem: o resultado da busca não mostra a ORGANIZAÇÃO (homônimos) e a OBSERVAÇÃO TERMINADA não é dita. O comentário no código ("organização não") contradiz o contrato SEM correção registrada — a regra "erro de contrato se corrige no mesmo commit, com a razão" não foi cumprida. Recusa estreita: o resto todo conforme |

## Fases derivadas

| Entregável | Tarefas | Materializa | Fase |
|---|---|---|---|
| D1 — migração das 9 frases + verificador v2 | #609 | #573, #574 | `sro.not_accepted_deliverable` |
| D2 — pendências refeitas + US3 alinhada | #610 | #574 | `sro.accepted_deliverable` |
| D3 — cadastro com temporária | #599, #600, #602 | #597 | `sro.accepted_deliverable` |
| D4 — o elo na área | #601, #603–#606 | #598 | `sro.not_accepted_deliverable` |

Tarefas com sucesso: #610, #599, #600, #602. Sem sucesso: #609, #601, #603–#606.
Entregável do sprint composto de **D2 e D3**. Retrabalho: 2 de 4 entregáveis.

## O retrabalho, nomeado (herança do sprint 026, primeira da fila)

1. **#573 (nova tarefa)**: a borda traduz o motivo — `PatternValidator` devolve
   tuplas e `humanizar/1` ganha as cláusulas que faltam; `primeira_mensagem/1` e o
   `motivo/1` da accounts_live passam pelo catálogo (os msgids do Ecto JÁ existem em
   `errors.po`). 5 frases + 2 helpers — migrar custa menos que enumerar. E a lição:
   caçar os IRMÃOS do contraexemplo pelo padrão da classe antes de entregar.
2. **#598 (nova tarefa)**: organização no resultado da busca (homônimos decidem pelo
   identificador COM contexto, como spec/contrato/tasks escreveram) e a marca de
   observação terminada no resultado.

## Processo (DoD do backlog 025)

As duas violações do 024 **não se repetiram**: revisão pedida a +1s da abertura nos
dois PRs, e ambos no board com Iteration e Status. Ressalvas: o pedido foi a pessoas
(o procedimento da casa pede a EQUIPE `the-band`); revisão registrada segue zero —
merges pelo autor ~50min após abertura, sob a autorização "pode fechar" da pessoa
mantenedora, registrada nesta sessão. Estado: *revisão não ocorreu, pedido
registrado* — o resíduo da família #89/#593/#594 continua acumulando; a saída
estrutural (PR aberto por identidade de agente) segue apontada e não decidida.
Issues na ordem certa: abertas durante a avaliação, fechadas APÓS este registro.
