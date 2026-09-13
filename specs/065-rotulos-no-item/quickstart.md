# Quickstart — provar que a 065 funciona

**Data**: 2026-09-13 · Detalhes em [data-model.md](data-model.md) e [research.md](research.md).

Cada cenário diz o que deve acontecer **e** o que deve falhar. Cenário só com caminho feliz
não distingue funcionando de não-olhando.

## Pré-requisitos

```bash
docker compose up -d postgres
mix deps.get && mix ecto.migrate   # nenhuma migração nova nesta feature
```

---

## 1. O rótulo do campo aparece na listagem

Abrir `/work`, aba de issues.

**Esperado**: cada linha com rótulo mostra os nomes, com a marca de **observado** (sólido).

**E o que deve FALHAR** — sem isto o cenário não prova nada:

```sql
update issue_labels set no_longer_observed_at = now()
 where collected_issue_id = (select id from collected_issues limit 1);
```

**Esperado**: aquela linha passa a mostrar **ausência escrita**, não célula vazia. Desfaça
depois.

## 2. O prefixo do título vira rótulo — e só os declarados

```sql
select title from collected_issues where title like '[Devops]%' limit 1;   -- vira rótulo
select title from collected_issues where title like '[Portal ADM]%' limit 1; -- NÃO vira
```

**Esperado**: a linha do `[Devops]` mostra `Devops` com a marca de **derivado** (hachura); a
do `[Portal ADM]` **não** mostra rótulo vindo do título.

O segundo é o teste que importa. Aceitar qualquer colchete transformaria erro de digitação em
caracterização, e ele é o que prova que a lista declarada está sendo respeitada.

## 3. As duas origens convivem, sem se juntar

Abrir a issue cujo título começa com `[Back-end] Permitir importação de subrubricas`.

**Esperado**: **dois** rótulos — `backend` sólido e `Back-end` hachurado. Não um.

Se aparecer só um, a implementação deduplicou, e a FR-008 foi quebrada.

## 4. O rótulo NÃO vira conceito

```sql
-- num item classificado como tarefa
insert into issue_labels (id, tenant_id, collected_issue_id, name, inserted_at, updated_at)
values (gen_random_uuid(), $tenant, $issue, 'bug', now(), now());
```

**Esperado**: o tipo derivado **continua tarefa**.

É a regra que esta feature poderia quebrar — um campo de rótulo ao lado do conceito é
exatamente a situação em que alguém, meses depois, "melhora" a classificação lendo o rótulo.

## 5. A listagem não faz uma consulta por linha

```bash
mix test test/the_band/work_items/rotulos_test.exs --only custo
```

**Esperado**: o número de consultas de uma listagem de 100 itens é **igual** ao de uma de 10.

**E o que deve FALHAR**: trocar a junção agregada por carregamento associado faz o teste
acusar 101 consultas.

## 6. A ordem é estável

Carregar a mesma listagem duas vezes.

**Esperado**: a mesma ordem de rótulos nas duas.

**E o que deve FALHAR**: retirar o `ORDER BY` de dentro do agregado. O teste pode passar
algumas vezes — é o ponto: sem a ordenação declarada, a instabilidade é intermitente, e é
assim que ela escapa.

## 7. Duas issues com o mesmo número são distinguíveis

```sql
select number, count(*) from collected_issues group by 1 having count(*) > 1 limit 3;
```

Abrir a listagem filtrando por um desses números.

**Esperado**: cada linha nomeia **seu repositório**, e dá para dizer quais são quais sem abrir
nenhuma.

## 8. A tela é a aprovada

Comparar a tela com o protótipo — <https://claude.ai/code/artifact/e52ca895-fa21-40b2-bbbc-bab0b4a711b0>.

**Esperado**: item a item. Divergência do protótipo é **defeito**, não melhoria, e a mudança
volta ao protótipo antes do código (FR-015).

## 9. O gate

```bash
mix gates ; echo "saída: $?"
```

**Esperado**: `saída: 0`. **Não leia o texto do fim** — qualquer comando depois substitui o
código que vale.

---

## O que este guia NÃO prova

- **que os rótulos significam alguma coisa** — a feature os mostra, e deliberadamente não os
  interpreta;
- **que a lista de prefixos está completa** — ela é a declarada hoje, e acrescentar é decisão
  de quem administra;
- **que a tela de hierarquia melhorou** — ela está fora do escopo, e continua sem rótulos.
