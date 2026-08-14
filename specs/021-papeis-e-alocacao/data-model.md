# Data model — os papéis, e quem os desempenha

**Feature** `021-papeis-e-alocacao` · **Data**: 2026-08-14

A feature **não cria tabela**. Ela dá módulo a uma que existe, acrescenta uma coluna e um
índice, e usa uma distinção que já está no banco e nunca teve consumidor.

---

## O que já existe, e está vazio

| Tabela | Estado | O que ela é |
|---|---|---|
| `eo_organizational_roles` | 0 linhas, schema pronto | o **catálogo**: o que a organização reconhece |
| `eo_team_memberships` | 0 linhas, **sem schema** | o **vínculo**: quem desempenha o quê, onde, quando |
| `eo_team_membership_evidence` | 101 linhas, `promoted_membership_id` nulo | a **observação**: quem a origem mostrou na equipe |

`eo_team_memberships` já tem `organizational_role_id` `NOT NULL`, `started_at` e `ended_at`.

---

## O que entra

### `eo_team_memberships.declared_by_user_id`

| | |
|---|---|
| Tipo | uuid, referência a `users` |
| Nulo | **sim** — vínculo importado ou de origem futura não teria autor |
| Índice | não; a pergunta "o que fulano declarou" não é frequente |

**Por que existe.** Declaração sem autor é indistinguível de observação — e a distinção é a
feature inteira. É a FR-011.

**Por que nulo é permitido.** Hoje toda alocação tem autor humano, e a tela exige. Proibir nulo
fecharia a porta para um vínculo que venha a ser derivado de outra coisa, e obrigaria a inventar
um usuário-sistema — que é pior: um autor falso mente mais do que um autor ausente.

### Índice parcial de vigência

```
UNIQUE (tenant_id, person_id, team_id, organizational_role_id) WHERE ended_at IS NULL
```

**O que ele impede**: a mesma pessoa alocada duas vezes ao **mesmo** papel na mesma equipe, ao
mesmo tempo.

**O que ele permite, de propósito**: dois papéis diferentes na mesma equipe — Developer e Scrum
Master é comum em Scrum —, e o mesmo papel duas vezes com períodos distintos, que é o histórico
de quem saiu e voltou.

**Parcial, e não único simples.** O único simples proibiria o histórico, e apagar a linha antiga
para permitir a nova seria apagar dado.

---

## O que muda de significado

### `eo_team_membership_evidence.promoted_membership_id`

**Hoje**: nulo nas 101, sem consumidor.

**Passa a ser**: o vínculo que aquela evidência originou. `nil` significa **papel pendente**, e
é o que a tela já diz.

**O que ele não é**: uma marca de que a evidência virou outra coisa. As duas continuam
existindo, e a evidência continua sendo atualizada pela coleta.

---

## O que **não** muda, e é a garantia da feature

| Situação | O que acontece com o vínculo |
|---|---|
| a coleta não vê mais a pessoa na equipe | **nada** — a evidência é marcada, o vínculo continua |
| a evidência é marcada e depois volta | nada; o vínculo nunca soube |
| alguém encerra a alocação | `ended_at` recebe data, e a linha **permanece** |
| o papel é renomeado | o vínculo aponta por id; o código não muda |

**A coleta nunca escreve em `eo_team_memberships`.** Se um dia escrever, será outra feature, com
outra decisão — e a coluna de autor é o que tornará as duas distinguíveis.

---

## Invariantes que os testes têm de afirmar

1. **Nenhuma evidência é apagada por causa de uma alocação** — as 101 continuam depois de
   qualquer número delas.
2. **`mark_evidence_no_longer_observed/3` não muda nenhuma linha de `eo_team_memberships`.**
3. **Encerrar alocação não reduz a contagem de vínculos** — muda `ended_at`.
4. **Remover papel com vínculo apontando para ele é recusado**, e a recusa diz quantos são.
5. **Com zero papéis cadastrados, a tela sugere quatro e a contagem continua zero.**
6. **Nenhuma tela renderiza `MAINTAINER` ou `MEMBER` no lugar onde mostra papel.**
