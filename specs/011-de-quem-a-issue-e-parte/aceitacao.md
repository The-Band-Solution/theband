# Aceitação — Feature 011: de quem cada issue é parte

**Avaliado em**: 2026-08-12 · **Branch**: `015-de-quem-a-issue-e-parte`
**Base**: os 13 critérios de sucesso da [spec](spec.md), um a
um, **com evidência**

**A suíte verde não é evidência de critério atendido** — é a L18. Cada linha abaixo aponta o teste, a
consulta ou a medida que sustenta o veredito.

| SC | O que exige | Veredito | Evidência |
|---|---|---|---|
| **SC-001** | as 1 630 issues com pai mostram o pai na linha | **atendido** | `issue_parent_test.exs` — "a issue com pai mostra número, título e conceito dele"; e a contagem no dado real: `count(distinct child_issue_id)` = **1 630** |
| **SC-002** | as 2 899 sem pai dizem isso em texto | **atendido** | teste "a issue sem pai diz isso em texto, e a célula não fica vazia" — assere `not part of anything`, e não a ausência de conteúdo |
| **SC-003** | tarefa sob US e tarefa sob épico com textos diferentes | **atendido** | teste "tarefa sob épico diz que viola, e o texto é diferente do de atendimento" — `refute texto(viola) == texto(em_ordem)` |
| **SC-004** | nenhum pai defeito chamado de "US ou épico" | **atendido** | a célula mostra `ConceptLabel.rotulo(pai.derived_concept)`; teste do conceito do pai, e no dado real são **12** vínculos com pai defeito |
| **SC-004a** | as 2 091 tarefas sem pai **sem** aviso na coluna | **atendido** | teste "a tarefa SEM pai não recebe aviso na célula, e o painel continua na tela" — `refute celula =~ "sro.rule07"` e `assert html =~ "Tasks with no user story"` |
| **SC-004b** | os 33 de defeito dizem que a relação não é nomeada | **atendido** | teste "filha promovida a defeito não é composição nem atendimento"; e a medida no dado real: **33** |
| **SC-005** | as 36 com mais de um pai dizem que há mais de um | **atendido** | teste "os dois aparecem, e a tela diz que há mais de um"; mais o caso misto — pai vigente + vínculo que acabou **não** dispara o plural |
| **SC-006** | o mesmo render duas vezes dá o mesmo resultado | **atendido** | teste "a mesma página desenhada duas vezes mostra a mesma coisa"; e `parents_test.exs` compara duas chamadas da consulta |
| **SC-007** | os 57 com pai fora mostram de qual repositório | **atendido** | testes "pai em outro repositório vem com o nome dele" e "pai no mesmo repositório não repete o nome" |
| **SC-008** | no máximo duas consultas, e o número não cresce | **atendido** | teste "doze consultas por render, e o número não cresce com o dado": **10 medidas antes** contra `main`, **12 depois**; 2 issues e 50 issues medem **igual** |
| **SC-009** | os casos distinguíveis com a cor removida | **atendido** | teste "os casos continuam distinguíveis por texto" — três textos, três distintos, com as tags removidas |
| **SC-010** | legível em 360 px | **não verificado** | `data-label="part of"` está no HTML e o teste alcança a célula por ele. **Ninguém olhou a tela.** Asserção em markup não é olhar — quinta vez que este item atravessa um sprint |
| **SC-011** | um tenant não alcança issue de outro | **atendido** | teste "repositório de outro tenant devolve não encontrado" — `flash["error"] =~ "not found"` e `refute ... "permission"` |

**12 de 13 atendidos. Um não verificado, e é o mesmo de sempre.**

## A invariante, conferida no dado real

```
atendimento  1 143
violação       293
composição     197
não nomeada     33
             ─────
              1 666   ← exatamente os vínculos vigentes
```

Nenhum vínculo cai fora das quatro relações, e nenhum é contado duas vezes. **É a mesma soma que
provou o erro da primeira medida** — a que confundiu 1 666 vínculos com 1 666 issues.

## O que não foi verificado, e por quê

| Item | Estado | Por quê |
|---|---|---|
| a tela em **360 px** | **não olhada** | precisa de navegador e de olho humano; a plataforma sobe com a chave mestra, que eu não peço nem recebo |
| a coluna **no dado real**, na tela | **não olhada** | idem — as contagens foram conferidas por SQL, e o caminho de exibição pela suíte no cenário com a forma do dado real |
| vínculo ausente **no dado real** | **impossível hoje** | nada no código marca vínculo de decomposição como ausente — é a #263, achada nesta feature. A tela sabe exibir; o dado nunca chega nesse estado |
| pai sem conceito **no dado real** | **zero casos** | toda issue está promovida hoje; vai existir na primeira coleta com tipo novo, e o teste monta o caso |

## Os três defeitos que esta feature achou fora dela

| # | O que é | Registro |
|---|---|---|
| 1 | `fetch_parent/2` escolhe um pai entre vários **sem ordem**, e esconde que há outro | [#261](https://github.com/The-Band-Solution/theband/issues/261) |
| 2 | filha promovida a defeito **não aparece** no detalhe do pai — 33 vínculos | [#262](https://github.com/The-Band-Solution/theband/issues/262) |
| 3 | vínculo de decomposição **nunca** é marcado como ausente | [#263](https://github.com/The-Band-Solution/theband/issues/263) |

Nenhum dos três é corrigido aqui: os três são de outra tela ou de outra fase. **Registrados com
número, porque registrar é o que distingue dívida de omissão.**
