# Research — os papéis, e quem os desempenha

**Feature** `021-papeis-e-alocacao` · **Data**: 2026-08-14

Quatro decisões, e três delas saíram de ler o que já existe no repositório.

---

## R1 — Quanto do modelo já existe

**Decisão**: nenhuma migração nova para papel e vínculo. **Uma** para o autor da declaração.

**O que foi medido**, lendo o schema e o banco em 2026-08-14:

| O quê | Estado |
|---|---|
| tabela `eo_organizational_roles` | **existe**, com `code` e `name`, índice único por `(tenant_id, code)` — **0 linhas** |
| schema `OrganizationalRole` | **existe**, com changeset |
| tabela `eo_team_memberships` | **existe**, com `organizational_role_id` `NOT NULL`, `started_at` e `ended_at` — **0 linhas** |
| schema `TeamMembership` | **não existe** — a tabela nunca ganhou módulo |
| `eo_team_membership_evidence.promoted_membership_id` | **existe** e está nulo nas 101 |

**O que falta no banco**: quem declarou. A FR-011 exige registrar o autor, e nenhuma das duas
tabelas tem coluna para isso.

**Alternativas consideradas**:

| Alternativa | Por que não |
|---|---|
| guardar o autor num campo de texto livre | perde o vínculo com `users`, e a pergunta "o que fulano declarou" vira busca por string |
| não guardar o autor | a FR-011 existe porque declaração sem autor é indistinguível de observação — que é o defeito que a US3 inteira combate |

---

## R2 — A distinção entre declarado e observado, e onde ela vive

**Decisão**: a distinção é **estrutural**, não de rótulo. Evidência e vínculo continuam sendo
duas tabelas, e a tela lê as duas.

**Fundamento**: já é assim, e é por isso que as 101 evidências existem. `record_team_membership_evidence/2`
grava o que a origem mostrou; `eo_team_memberships` guardaria o que alguém afirmou. A feature
não cria a distinção — ela **usa** a que já está no modelo e que nunca teve consumidor.

**O que a US3 acrescenta**: a tela passa a mostrar as duas, com a origem de cada uma visível.
Hoje `PeopleLive.Show` mostra a evidência e diz que o papel está pendente. Passa a mostrar
também o vínculo, dizendo que ele foi **declarado, por quem e quando**.

**Alternativa considerada e recusada**: uma coluna `origem` na mesma tabela, com valores
`observado` e `declarado`. Isso é o **booleano no lugar do relator** — o antipadrão da §7.7. As
duas coisas têm campos diferentes: evidência tem `platform_access_level` e
`no_longer_observed_at`; vínculo tem papel, período e autor. Uma tabela só teria metade das
colunas nulas em metade das linhas.

---

## R3 — O que acontece com o vínculo quando a evidência acaba

**Decisão**: **nada**. O vínculo continua vigente, e a tela diz que a evidência acabou.

**Fundamento, e é o defeito que a análise achou**: `mark_evidence_no_longer_observed/3` marca a
evidência que a coleta não reviu. Se ela marcasse o vínculo junto — ou o apagasse —, uma coleta
apagaria uma **declaração humana**, e a plataforma perderia o que nenhuma origem forneceu.

A regra é a mesma da feature 012 vista de outro ângulo: a coleta marca o que **ela** observa. O
vínculo não é observado; é afirmado.

**O que a tela precisa dizer**, e é a FR-014: *"a participação que originou este papel não
aparece mais na origem"*. O papel continua; a base dele mudou de estado, e quem lê decide.

**Alternativa considerada**: encerrar o vínculo automaticamente, gravando `ended_at`. Recusada —
seria a plataforma afirmando que a pessoa **deixou o papel**, e o que ela sabe é que a origem
parou de mostrar a participação. São coisas diferentes, e a segunda não implica a primeira.

---

## R4 — Papel sugerido, e não cadastrado

**Decisão**: a tela oferece os quatro papéis que a ontologia nomeia como sugestão de
preenchimento. **Nenhum é gravado sem alguém mandar.**

**Fundamento**: `eo.organizational_role` está definido como *"papel social **reconhecido pela
organização**"*. Cadastrar automaticamente faria a plataforma reconhecer no lugar dela — e
produziria quatro papéis que talvez nenhuma equipe use.

Os quatro vêm de `priv/knowledge_base/ontology/continuum/sro/modules/scrum_stakeholders.yaml`:
`sro.product_owner_role`, `sro.scrum_master_role`, `sro.developer_role`, `sro.client_role`.

**Alternativas consideradas**:

| Alternativa | Por que não |
|---|---|
| criar os quatro numa migração de seed | a organização passaria a "reconhecer" papéis que nunca declarou, e a SC-004 mede justamente o contrário |
| não sugerir nada | quem abre a tela vazia não sabe o que a plataforma espera, e a ontologia já tem a resposta |

---

## R5 — A multiplicidade, e o que a chave impede

**Decisão**: mais de um papel por pessoa por equipe é permitido; o **mesmo** papel duas vezes
com período vigente, não.

**Fundamento**: acumular Developer e Scrum Master é comum em Scrum e não é anomalia. Recusar
produziria uma plataforma incapaz de descrever times reais.

O que a unicidade impede é a duplicata sem sentido: a mesma pessoa alocada duas vezes ao mesmo
papel na mesma equipe, ao mesmo tempo. Um índice parcial — `ended_at IS NULL` — é o que expressa
"vigente" sem inventar coluna de estado.

**E o histórico continua**: a pessoa que foi Developer, saiu, e voltou tem **duas** linhas, com
períodos distintos. É o que `started_at`/`ended_at` existem para permitir, e apagar a primeira
seria apagar dado.

---

## O que não precisou de pesquisa

- **A tela de papéis é nova**, e usa o componente de tabela da feature 017/020. Nenhuma decisão;
- **o escopo de tenant** segue o padrão do módulo: toda leitura recebe `%Tenant{}`, e id de
  outro tenant devolve não encontrado;
- **o perfil administrador** já é exigido em `/tools`, e o plug existe.
