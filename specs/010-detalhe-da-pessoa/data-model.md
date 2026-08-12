# Modelo de dados — Feature 010

**Nenhuma coluna nova, nenhuma tabela nova, nenhuma migração.** A feature só **lê**.

---

## O que ela lê, e o que cada coisa significa

| tabela | o que a página tira dela | natureza |
|---|---|---|
| `eo_people` | identidade e proveniência: nome, tipo de conta, origem, identificador, datas | **observado** |
| `eo_team_membership_evidence` | equipe, nível de acesso da plataforma, período, e **se foi promovida** | **observado**, com a promoção como fato próprio |
| `eo_teams`, `eo_organizations` | o nome da equipe e de qual organização ela é | observado |
| `eo_organizational_roles` | **quantos papéis existem** — sustenta a explicação da não promoção | observado |
| `issue_assignees` | em que issues a pessoa foi **designada** | observado |
| `collected_issues.author_person_id` | que issues a pessoa **abriu** | observado |
| os repositórios das issues acima | em que repositórios ela **aparece** | **derivado** |

---

## A distinção que a página existe para mostrar

```text
evidência de vínculo          →  a origem declarou
promoted_membership_id nulo   →  a plataforma NÃO promoveu
zero papéis cadastrados       →  e este é o motivo, hoje
```

Medido em 2026-08-12: **88 evidências, 0 promovidas, 0 papéis**.

**A promoção é um fato do dado, não uma inferência da tela.** `promoted_membership_id` diz se houve; a
contagem de papéis diz se a causa é a ausência de papel. As duas leituras juntas evitam a frase que
envelhece — o caso "há papéis e ainda não promoveu" existe no desenho antes de existir no dado.

---

## O que **não** é o que parece

| parece | é |
|---|---|
| `platform_access_level: "MAINTAINER"` | permissão **na ferramenta** — não é `sro.scrum_master`, nem papel nenhum |
| pessoa listada num repositório | **derivado** de designação ou autoria; a origem nunca declarou esse vínculo |
| `no_longer_observed_at` preenchido | **houve** vínculo e ele não está presente — diferente de nunca ter havido |
| contagem de issues da pessoa | **duas** contagens: designada e autora. A soma não corresponde a nada |

---

## Os três conjuntos de "issues da pessoa"

| conjunto | tamanho no dado real | usado? |
|---|---:|---|
| designadas | 4 232 designações, em 59 pessoas | **sim** |
| abertas por ela | 4 241 autorias, em 44 pessoas | **sim** |
| a união das duas | — | **não**, e é proibido por FR-009 |

A união é a que parece natural e não significa nada: quem abre uma issue não necessariamente trabalha
nela, e quem trabalha nela raramente é quem abriu.

---

## As 288 issues sem autor

`author_person_id` nulo em **288** das 4 521 issues. A origem não devolveu autor — conta apagada, ou
issue criada por integração.

**Elas não pertencem a pessoa nenhuma**, e por isso não aparecem em página de pessoa. Não é omissão: é
o que o dado diz, e as telas de trabalho já as contam por repositório.

---

## O que a feature **não** cria

| Não criado | Por quê |
|---|---|
| vínculo promovido | exige papel, que é a #99 e a #100 |
| papel derivado de nível de acesso | mapear por semelhança de nome — princípio II |
| coluna com "repositórios da pessoa" | é derivado; materializar seria a ADR 0004 D7 |
| contagem gravada por pessoa | envelheceria a cada coleta, em silêncio |
