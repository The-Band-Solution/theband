# Quickstart — provar que o vínculo ausente chega ao dado

**Feature** `012-vinculo-que-sumiu-na-origem`

Duas provas, e elas são diferentes: a **automatizada** monta o caso e roda sem rede; a **do dado
real** exige a chave mestra e a origem respondendo, e é da pessoa mantenedora.

---

## 1. Antes de qualquer coisa: os dez gates

```bash
mix gates
echo $?     # 0, e o veredito é este número
```

`mix gates` é a definição única dos gates. **Nunca rode com `| tail`** — o corte esconde a falha.

---

## 2. A prova automatizada

```bash
mix test test/the_band/work_items_test.exs
mix test test/the_band/ingestion/github_work_items_test.exs
```

O que os testes montam, e cada um responde um cenário da spec:

| Caso | Espera |
|---|---|
| coleta em que o pai deixou de declarar uma parte | aquele vínculo marcado, **e nenhum outro** |
| a mesma coleta, os vínculos que continuam | vigentes, com `last_observed_at` novo |
| a origem volta a declarar | vigente de novo, `observed_at` **inalterado** |
| duas coletas sem mudança | nenhuma data muda na segunda |
| repositório com falha transitória | **zero** vínculos marcados |
| repositório inacessível ou excluído | **zero**, e ele nem é coletado |
| vínculo com pai em `A` e filha em `B`, e só `B` coletado | **não** marcado |
| dois tenants | nenhum vínculo do outro tenant é tocado |

**Sem mock de módulo de domínio.** Só a borda HTTP do GitHub é fingida; o estado é montado pelo
caminho real — gravar issue, gravar vínculo, coletar de novo.

---

## 3. A prova no dado real — **precisa da pessoa mantenedora**

Exige a chave mestra e o token, que **não entram no chat nem no repositório**.

```bash
export THE_BAND_MASTER_KEY=...   # no seu terminal
mix phx.server                   # e disparar a sincronização em /syncs
```

### Antes de sincronizar — o retrato de hoje

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
select count(*) as total,
       count(*) filter (where no_longer_observed_at is not null) as ausentes
  from decomposition_links;"
```

Esperado hoje: `1666|0`.

### Quais deveriam sair da vigência

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
with ult as (select observed_repository_id, max(last_observed_at) ultima
               from collected_issues group by 1)
select sr.name, count(*)
  from decomposition_links dl
  join collected_issues p on p.id = dl.parent_issue_id
  join observed_repositories r on r.id = p.observed_repository_id
  join cmpo_source_repositories sr on sr.id = r.source_repository_id
  join ult on ult.observed_repository_id = p.observed_repository_id
 where dl.last_observed_at < ult.ultima - interval '1 minute'
 group by 1 order by 2 desc;"
```

Esperado hoje: `eo_lib|29`, `theband|15`, `ResearchDomain|8`.

### Depois de sincronizar — as três conferências

| # | O que conferir | Como |
|---|---|---|
| 1 | os que a origem largou saíram da vigência | a primeira consulta deixa de devolver `0` na segunda coluna |
| 2 | **só** eles | no `theband`, os 157 revistos continuam vigentes e os 15 não |
| 3 | nenhum repositório não coletado foi tocado | contagem de marcados em repositório inacessível é **zero** |

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
select count(*) filter (where dl.no_longer_observed_at is not null) as marcados_em_inacessivel
  from decomposition_links dl
  join collected_issues p on p.id = dl.parent_issue_id
  join observed_repositories r on r.id = p.observed_repository_id
 where r.inaccessible_since is not null;"
```

Esperado: `0`, em qualquer execução.

### E a conferência de tela — **olho humano, e não há substituto**

`/work/repositories/<id>` de `eo_lib`: a coluna `part of` das 29 issues passa a dizer, em texto,
*"absent: this link existed and is not present now"*.

**Asserção em HTML não substitui olhar.** Quatro telas já estão declaradas como não conferidas em
`docs/sprints/RETOMAR.md`, e esta entra na mesma regra: enquanto ninguém olhar, o item é pendente —
nunca cumprido.

---

## 4. Dependência declarada

A conferência de tela exige a feature 011 incorporada — [PR #264](https://github.com/The-Band-Solution/theband/pull/264),
aberto e aguardando revisão. **A parte de coleta e os testes automatizados não dependem dele.**
