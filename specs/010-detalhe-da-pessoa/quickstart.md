# Quickstart — Feature 010: o detalhe da pessoa

Nove verificações. Os números vêm do banco de desenvolvimento, medidos em 2026-08-12: **75 pessoas,
12 equipes, 88 evidências de vínculo, 0 vínculos, 0 papéis, 4 232 designações, 4 241 autorias, 288
issues sem autor**.

## Pré-requisitos

```bash
docker compose up -d
export THE_BAND_MASTER_KEY=...
mix phx.server            # localhost:4000/people
```

---

## V1 — Toda pessoa é alcançável por clique

Abrir `/people` e clicar num nome.

**Esperado**: a página da pessoa abre. **As 75** têm de abrir — é o SC-001.

**O que NÃO pode**: nome sem link, que é o estado de hoje.

---

## V2 — Designação e autoria aparecem separadas, e a soma NUNCA

```bash
mix test test/the_band_web/live/person_detail_test.exs -o "soma"
```

**Esperado**: para uma pessoa com 12 designações e 7 autorias, a página mostra **12** e **7**.

**O que NÃO pode aparecer**: **19**. O teste procura o número proibido, como o `refute html =~ ">39<"`
da feature 006 — e aquele achou um defeito real que eu havia introduzido.

---

## V3 — A não promoção é explicada, com o motivo vindo do dado

Abrir a página de qualquer pessoa com equipe.

**Esperado hoje**: a equipe aparece com o nível de acesso, e a página diz que **a plataforma não
promoveu o vínculo porque não há papel cadastrado**.

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
select count(*) filter (where promoted_membership_id is null) as nao_promovidas,
       (select count(*) from eo_organizational_roles) as papeis
  from eo_team_membership_evidence;"
```

**Esperado**: `88 | 0`.

**A verificação que importa é a outra**: cadastre um papel à mão e recarregue. A frase **precisa
mudar** — a causa deixou de ser a ausência de papel. Texto fixo passaria a mentir aqui, e é o R4.

---

## V4 — Nível de acesso não é chamado de papel

```bash
mix test test/the_band_web/live/person_detail_test.exs -o "papel"
```

**Esperado**: nenhum texto da página usa a palavra *role* ao lado de `MEMBER` ou `MAINTAINER`.

**Por que a verificação existe**: `MAINTAINER` é permissão da ferramenta; `sro.scrum_master` é papel do
processo. Mapear um no outro é mapear por semelhança de nome, e contamina toda medida derivada.

---

## V5 — O repositório aparece como derivado, com a evidência

Abrir a página de uma pessoa com issues.

**Esperado**: cada repositório com a marca **hachurada** e o texto dizendo de que evidência vem —
designação, autoria, ou as duas, com os dois números.

**O que NÃO pode**: repositório com marca sólida. A origem nunca declarou que a pessoa trabalha nele.

---

## V6 — Vínculo que saiu aparece, com a data

```bash
mix test test/the_band_web/live/person_detail_test.exs -o "ausente"
```

**Esperado**: evidência com `no_longer_observed_at` preenchido aparece **tracejada**, com a data, e o
texto dizendo que houve vínculo e ele não está presente.

**As duas falhas típicas**: omitir — e aí a pessoa parece nunca ter estado na equipe —, ou mostrar como
atual, e aí a tela afirma um vínculo que acabou.

---

## V7 — As ausências são nomeadas

```bash
mix test test/the_band_web/live/person_detail_test.exs -o "ausência"
```

**Esperado**: pessoa sem designação e sem autoria tem **as duas** ausências nomeadas — nunca `0` sozinho.

Hoje **não existe** pessoa sem nada: as 75 têm evidência de equipe. O teste monta o caso.

---

## V8 — A página não consulta por linha

Com o log do servidor, ao abrir a página de uma pessoa com muitas issues:

```bash
grep -c "SELECT" /tmp/the_band_server.log
```

**Esperado**: um número que **não cresce** com a quantidade de issues, equipes ou repositórios da
pessoa — é o SC-009.

**Falha típica**: uma consulta por repositório para contar as issues dele. A feature 007 nasceu com 135
consultas por render exatamente assim.

---

## V9 — A página funciona no telefone

Abrir `/people/:id` em 360 px.

**Esperado**: as três seções empilham, as tabelas viram cartões com `data-label`, e as formas da
evidência continuam legíveis.

**E a verificação que remove a cor**: com as classes de cor retiradas, observado, derivado e ausente
continuam distinguíveis por forma e texto.

---

## Os dez gates

```bash
mix gates
```

**Esperado**: `10 gates verdes`, e **código de saída zero** — que desde a correção do #229 é o veredito
de verdade.
