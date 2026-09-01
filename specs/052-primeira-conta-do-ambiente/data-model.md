# Data Model — A primeira conta nasce do ambiente

## Nenhuma entidade nova, nenhuma migração

Esta é a conclusão do desenho, e não uma omissão. A feature cria registros nas
duas tabelas que já existem desde a primeira migração do projeto, e não
acrescenta coluna, índice ou tabela.

Vale dizer o que isso significa: **não há `mix ecto.gen.migration` nesta
feature**. Se durante a implementação alguém sentir necessidade de uma migração,
o desenho mudou e o plano precisa ser revisto antes do código.

## As entidades que a feature usa

### `tenants` — a organização cliente

| campo | origem nesta feature | validação que já existe |
|---|---|---|
| `name` | valor do ambiente | obrigatório |
| `slug` | valor do ambiente | obrigatório; `^[a-z0-9-]+$`; **único** |
| `status` | não informado — usa o padrão `"active"` | — |

O `unique_index(:tenants, [:slug])` é metade da garantia do FR-005.

### `users` — a pessoa com marca de administração

| campo | origem nesta feature | validação que já existe |
|---|---|---|
| `email` | valor do ambiente | obrigatório; **único** |
| `name` | valor do ambiente, se houver | — |
| `role` | fixo em `"admin"` | precisa estar entre os papéis conhecidos |
| `tenant_id` | a organização criada ou encontrada | obrigatório |
| `password_hash` | derivado da senha do ambiente | mínimo de 12 caracteres, hash no changeset |

O `unique_index(:users, [:email])` é a outra metade da garantia do FR-005.

## O ato de criação

Organização e conta nascem **numa transação** (FR-004). Se a segunda falhar, a
primeira não sobra.

Isso importa mais do que parece. Uma organização sem administrador não é apenas
inútil: ela ocupa o slug. A subida seguinte encontraria o slug tomado, tentaria
criar a conta dentro dela, e — dependendo de como o erro fosse tratado —
poderia ficar presa nesse estado a cada boot, sem que nenhuma tela soubesse
nomear o que havia acontecido.

## A decisão de criar, e o que ela consulta

A pergunta é **"existe alguma pessoa com marca de administração?"**, e não
"existe esta pessoa" (FR-002).

A diferença é observável: trocar o e-mail na variável, numa plataforma que já
tem administrador, **não** cria uma segunda conta. Quem quer uma segunda usa
`/accounts`, onde fica registrado quem criou quem.

A consulta é uma só, e no caso comum — plataforma já instalada — é tudo o que a
feature faz por boot.

## Organização que já existe, conta que não (FR-011)

Um banco restaurado pode ter organizações e nenhum administrador. Nesse caso a
organização com aquele slug é **encontrada**, não criada, e a conta nasce dentro
dela.

Sem isso, a criação tentaria um slug já ocupado e falharia — deixando uma
instalação restaurada sem caminho de entrada, que é exatamente o problema que
esta feature existe para eliminar.

## Estados possíveis ao fim de uma subida

| estado | quando | o que a plataforma faz |
|---|---|---|
| criada | não havia administrador, os quatro valores presentes e válidos | diz o e-mail e a organização, e sobe |
| já existe | havia administrador | diz que não havia o que fazer, e sobe |
| faltando | algum valor ausente | **nomeia** os ausentes, e sobe |
| recusada | valor presente reprovado pelas regras que já valem | diz qual regra recusou, e sobe |

Os quatro terminam com a plataforma no ar. Nenhum derruba o contêiner — é o que
distingue esta feature de `DATABASE_URL`, cuja ausência derruba porque ali subir
seria pior que não subir.
