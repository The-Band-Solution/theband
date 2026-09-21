# #397 e #507 — o que falta em cada uma

**Aberto em**: 2026-09-13 · **Origem**: auditoria do papel de Product Owner, registrada em
[`issues-abertas-sem-motivo.md`](issues-abertas-sem-motivo.md)

As duas foram as únicas, entre 34 issues abertas, que chegaram perto de poder ser fechadas.
Nenhuma das duas fecha, e o item que falta em cada é pequeno e específico.

---

## #397 — a equipe composta por equipes

**O que já está entregue**: a composição muitos-para-muitos, a recusa de ciclo nomeando o
caminho, a leitura com `:escopo`, e a tela com cartões de subequipe.

**O que falta**: o **rollup das competências**.

`lib/the_band/teams/team_skills.ex:276-281` chama `EO.team_members_at/3` **sem** `:escopo`, e
`lib/the_band_web/live/teams_live/show.ex:4204` faz o mesmo.

**A consequência é uma tela que se contradiz**: numa equipe composta, o cabeçalho conta a
equipe inteira — diretos mais subequipes — e a matriz de competências conta **só os diretos**.
Os dois números aparecem no mesmo scroll.

Isso é pior que um número ausente. Quem vê "18 pessoas" no topo e conta 11 na matriz conclui
que a matriz está incompleta, ou que sete pessoas não têm competência declarada — e as duas
leituras estão erradas.

**Severidade**: média. Não corrompe dado; corrompe a leitura, e só em equipe composta.

---

## #507 — o painel da equipe

**O que já está entregue**: as duas medidas calculáveis, com teste —
`test/the_band/medidas_da_equipe_test.exs:226` e `:372`.

**O que falta**: a terceira medida, a **não calculável**, nunca chegou à tela. Zero ocorrências
de `rework` em `lib/the_band_web/live/teams_live/show.ex`.

**Contra o que isso vai**: a decisão de 2026-09-01 diz que medidas não calculáveis aparecem
**"não como zero, e não omitidas"** — a ausência é escrita, com o motivo. Omitir foi
exatamente o que aconteceu.

**Por que importa mais do que parece**: é a regra da casa sobre ausência declarada, quebrada
na tela que a inventou. Uma medida omitida não se distingue de uma medida que ninguém pensou
em ter.

**Severidade**: média. É princípio XI — sinal nunca silenciado — aplicado a si mesmo.

---

## O que estas duas têm em comum

As duas falham do **mesmo jeito**: a tela mostra um número que parece completo e não é, sem
dizer que não é. Não são defeitos de cálculo — são defeitos de **declaração**.

E as duas foram encontradas por auditoria, não por uso. Ninguém reclamou; o número errado não
grita.

## O que NÃO fazer com elas

**Não fechar.** As duas seguem abertas até o item que falta existir, e a auditoria diz
qual é.

**Não juntar numa spec.** São de features diferentes, e o que as une é a forma da falha, não o
escopo. Uma spec "consertar declarações de ausência" atravessaria dois subsistemas por
semelhança — que é o antipadrão que o princípio VIII recusa.
