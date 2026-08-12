# Quickstart — verificar a feature 011

Doze verificações. As que dizem **no dado real** exigem o banco de desenvolvimento com a coleta já
feita; as outras rodam pela suíte.

```bash
mix gates          # a definição única dos dez gates; o veredito é o código de saída
```

---

## V1 — a coluna aparece, e o pai é o pai

**Como**: abrir `/work/repositories/:id` de um repositório com issues decompostas.

**Esperado**: cada issue com pai mostra `#número` e o título do pai. **1 630** issues estão nesse caso
no dado real.

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
with vig as (select distinct on (collected_issue_id) collected_issue_id, derived_concept
  from issue_promotions order by collected_issue_id, inserted_at desc)
select count(distinct l.child_issue_id)
  from decomposition_links l
  join collected_issues c on c.id = l.child_issue_id and c.no_longer_observed_at is null
 where l.no_longer_observed_at is null;"
# esperado: 1630
```

## V2 — as 2 899 sem pai dizem isso

**Esperado**: texto na célula, nunca vazio. **SC-002.**

**Falha típica**: `<td></td>`. O teste procura o texto, e não a ausência dele.

## V3 — atendimento e composição têm textos diferentes

**Como**: numa lista com uma tarefa sob user story e uma user story sob épico.

**Esperado**: `attends` numa, `composes` na outra. **SC-003.**

## V4 — as 293 dizem que violam

**Esperado**: tarefa sob épico traz o aviso citando `sro.rule07`, e o texto é **diferente** do de
atendimento em ordem.

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
with vig as (select distinct on (collected_issue_id) collected_issue_id, derived_concept
  from issue_promotions order by collected_issue_id, inserted_at desc)
select count(*) from decomposition_links l
  join collected_issues ci on ci.id = l.child_issue_id and ci.no_longer_observed_at is null
  join vig vf on vf.collected_issue_id = ci.id
  join vig vp on vp.collected_issue_id = l.parent_issue_id
 where l.no_longer_observed_at is null
   and vf.derived_concept = 'sro.intended_scrum_development_task'
   and vp.derived_concept = 'sro.epic';"
# esperado: 293
```

## V5 — as 2 091 tarefas sem pai **não** trazem aviso na coluna

**Esperado**: a célula diz apenas que a issue não é parte de nada. O aviso de `task_without_parent`
continua no painel acima da tabela, com a contagem. **SC-004a.**

**Por que é verificação e não detalhe**: chamar o axioma com pai nulo é o caminho óbvio, e encheria
2 091 das 2 899 células — afogando as 293.

## V6 — os 33 vínculos de defeito não são chamados de composição

**Esperado**: `part of — the ontology network does not name this relation`. **SC-004b.**

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
with vig as (select distinct on (collected_issue_id) collected_issue_id, derived_concept
  from issue_promotions order by collected_issue_id, inserted_at desc)
select count(*) from decomposition_links l
  join collected_issues ci on ci.id = l.child_issue_id and ci.no_longer_observed_at is null
  join vig vf on vf.collected_issue_id = ci.id
 where l.no_longer_observed_at is null and vf.derived_concept = 'osdef.defect';"
# esperado: 33
```

## V7 — as 36 com mais de um pai dizem que há mais de um

**Esperado**: todos os pais listados, e o texto dizendo que há mais de um. **SC-005.**

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
select count(*) from (
  select child_issue_id from decomposition_links
   where no_longer_observed_at is null
   group by child_issue_id having count(*) > 1) t;"
# esperado: 36
```

## V8 — o mesmo render duas vezes dá o mesmo resultado

**Como**: renderizar a mesma página duas vezes e comparar o HTML da coluna.

**Esperado**: **idêntico**. **SC-006** — e é o que `limit: 1` sem `order_by` não garante.

## V9 — os 57 com pai em outro repositório dizem qual

**Esperado**: o nome do repositório do pai ao lado do número. Pai no **mesmo** repositório **não**
repete o nome. **SC-007.**

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
select count(*) from decomposition_links l
  join collected_issues ci on ci.id = l.child_issue_id
  join collected_issues pi on pi.id = l.parent_issue_id
 where l.no_longer_observed_at is null
   and ci.observed_repository_id <> pi.observed_repository_id;"
# esperado: 57
```

## V10 — duas consultas, e o número não cresce

**Como**: contar as consultas do render com a coluna e sem ela; depois comparar uma página de 3
issues com uma de 50.

**Esperado**: a diferença é **exatamente duas**, e as duas páginas fazem o **mesmo** número.
**SC-008.**

**Por que assim**: "um número que não cresce" não é asserção — é a **L38**, e a feature 010 pagou por
ela com um teste que esperava 8 numa tela que faz 24.

## V11 — a cor removida, e os casos ainda distinguíveis

**Como**: com o CSS de cor desligado — ou lendo o HTML sem classe de cor —, comparar as quatro
relações.

**Esperado**: as quatro continuam distinguíveis por **texto**. **SC-009**, e é a gramática da
evidência: `docs/design-system.md` exige texto e rótulo de leitor de tela, cor nunca sozinha.

## V12 — 360 px, e olhado

**Como**: abrir a tela em 360 px de largura, **no navegador**.

**Esperado**: a tabela vira cartão, a coluna aparece com o rótulo, e o texto do pai não estoura.
**SC-010.**

**Este é o item que atravessou três sprints sem olho humano.** Asserção em markup não substitui
olhar, e o `data-label` estar no HTML não prova que caiba na tela.

---

## Os dois casos que o dado ainda não tem

| Caso | Quantos hoje | Como verificar |
|---|---:|---|
| vínculo que deixou de ser observado (FR-011) | **0** | o teste marca `no_longer_observed_at` e exige tracejado com a data |
| pai sem conceito (FR-007) | **0** | o teste cria pai sem promoção e exige `the parent has no concept` |

Os dois vão existir: o primeiro na primeira coleta que perca um vínculo, o segundo na primeira que
traga tipo novo. **Verificar antes de existir é o que impede a tela de inventar quando existirem.**
