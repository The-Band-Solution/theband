# Quickstart — provar que o papel existe, e que nada foi apagado

**Feature** `021-papeis-e-alocacao`

Duas provas, e a segunda é a que importa: esta feature grava dado novo, e o risco não é ela
falhar — é ela **apagar** o que já existia.

---

## 1. Os treze gates

```bash
mix gates
echo $?     # 0, e o veredito é este número
```

Nunca com `| tail` — o corte esconde a falha.

## 2. A prova automatizada

### O catálogo

```bash
mix test test/the_band/ontology/seon/eo/papeis_test.exs
```

| Caso | Espera |
|---|---|
| cadastrar `developer` | aparece na lista |
| cadastrar o mesmo código de novo | recusa, dizendo que existe |
| renomear | o **código permanece** |
| remover papel com vínculo | `{:error, {:in_use, n}}`, com o número |
| pedir as sugestões | quatro voltam, e **`count_roles/1` continua zero** |

O último é a SC-004: a plataforma sugere e não cadastra.

### A alocação

```bash
mix test test/the_band/ontology/seon/eo/alocacao_test.exs
```

| Caso | Espera |
|---|---|
| alocar com evidência | vínculo criado, e a evidência aponta para ele |
| alocar o mesmo papel de novo, vigente | `{:error, :already_allocated}` |
| alocar **outro** papel na mesma equipe | **permitido** — Developer e Scrum Master |
| alocar sem `started_at` | grava nulo, e a tela dirá que não se sabe |
| fim antes do início | `{:error, :period_inverted}` |
| encerrar | `ended_at` gravado, e a contagem de vínculos **não cai** |
| encerrar duas vezes | `{:error, :already_ended}`, e a data da primeira permanece |

### A garantia que a feature existe para não quebrar

```bash
mix test test/the_band/ontology/seon/eo/coleta_nao_apaga_declaracao_test.exs
```

| Caso | Espera |
|---|---|
| alocar, e a coleta deixar de ver a pessoa na equipe | a evidência é marcada; **o vínculo continua vigente** |
| a mesma situação, contagem de `eo_team_memberships` | **igual antes e depois** |
| a evidência volta a ser observada | o vínculo nunca soube, e continua igual |

**A asserção é a contagem, e não a existência de uma linha.** "O vínculo existe" passaria mesmo
se a coleta tivesse apagado outro.

### A tela

```bash
mix test test/the_band_web/live/papel_declarado_test.exs
```

| Caso | Espera |
|---|---|
| pessoa com evidência e sem papel | a tela diz **observada** e **pendente** |
| pessoa alocada | a tela diz **declarado**, por quem e quando |
| evidência marcada, vínculo vigente | as duas coisas aparecem, e a frase de que a origem não mostra mais |
| qualquer estado | `refute html =~ "MAINTAINER"` no bloco de papéis — SC-006 |

O último é o teste que uma feature de cadastro costuma não ter: ele afirma uma **ausência**.

---

## 3. A conferência no dado real

Depois de cadastrar um papel e alocar uma pessoa:

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
select (select count(*) from eo_organizational_roles)   as papeis,
       (select count(*) from eo_team_memberships)        as vinculos,
       (select count(*) from eo_team_membership_evidence) as evidencias;"
```

| Antes | Depois de uma alocação |
|---|---|
| `0 \| 0 \| 101` | `1 \| 1 \| 101` |

**As evidências continuam 101.** Se esse número mudar, a feature apagou o que a coleta produziu —
e é o único resultado que reprova sozinho.

### E a conferência de tela — olho humano

`/people/<id>` de alguém alocado: os dois blocos aparecem, e é possível dizer, **lendo**, qual
veio da origem e qual alguém digitou. Se for preciso adivinhar, a US3 não foi entregue.
