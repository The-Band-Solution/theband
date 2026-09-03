# Fase 1 — Modelo de dados

Duas mudanças: **uma tabela nova** e **três colunas** numa existente.

## O conceito vem antes da tabela

O princípio I exige que o domínio seja organizado pelas ontologias. A composição
entre equipes **não tem conceito na EO hoje** — então ela nasce em
`priv/knowledge_base/ontology/seon/eo/modules/team_composition.yaml`, com a
relação declarada, e só depois vira tabela.

Fazer o contrário — tabela primeiro, conceito depois — produz exatamente o que a
issue #527 encontrou: estrutura que existe, conta, e não aparece onde alguém
procura.

## Tabela nova — composição entre equipes

Qual equipe faz parte de qual, desde quando, declarada por quem.

| campo | por que existe |
|---|---|
| `tenant_id` | princípio V — nenhuma consulta sem ele |
| `parte_id` | a equipe que faz parte |
| `todo_id` | a equipe que contém |
| `started_at` | desde quando a composição vale |
| `ended_at` | quando deixou de valer — **nulo enquanto vigente** |
| `declared_by_user_id` | quem declarou |
| `ended_by_user_id` | quem desfez |

**Índice parcial único** sobre `(tenant_id, parte_id, todo_id)` onde `ended_at`
é nulo: a mesma composição não pode vigorar duas vezes.

**Por que não `parent_team_id` em `eo_teams`**: uma coluna não carrega autor nem
data, o que a torna a versão booleana do relator — antipadrão declarado. E amarra
a uma composição por equipe.

**O que a tabela NÃO impede**: o ciclo. Índice não vê caminho; a recusa é da
aplicação (R3 do research).

## Colunas novas — o equívoco no vínculo

Em `eo_team_memberships`:

| campo | por que existe |
|---|---|
| `invalidado_em` | quando se reconheceu que o vínculo nunca vigeu |
| `invalidado_por_user_id` | quem reconheceu |
| `motivo_invalidacao` | **a razão** — é ela que distingue engano de saída no mesmo dia |

**Vigente passa a ser**: `ended_at` nulo **E** `invalidado_em` nulo. Toda consulta
de vínculo vigente carrega as duas condições, e esse é o custo declarado da
decisão 2 do plano.

**Por que não `ended_at = started_at`**: diria "durou zero" e perderia a razão.
Um vínculo que durou zero e um vínculo que nunca existiu são fatos diferentes
sobre a organização.

**Por que não apagar a linha**: o SC-003 exige que nenhum número de período
anterior mude. Uma linha apagada muda todos.

## O que NÃO muda

- **`eo_team_membership_evidence`** — a evidência observada continua como está. O
  FR-012 exige mostrar as duas afirmações quando discordarem, e isso é leitura,
  não estrutura;
- **a coleta** — nada no caminho de ingestão muda;
- **`eo_teams`** — nenhum campo novo. A origem (observada ou declarada) já é
  legível pela proveniência que `create_declared_team/3` grava.
