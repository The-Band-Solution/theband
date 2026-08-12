# Contrato — o detalhe da pessoa

Feature 010. Escrito **antes** da primeira função pública, como o princípio VII exige.

**Cinco funções novas, duas fronteiras, nenhum módulo novo.** A composição acontece na borda de
apresentação, seguindo o precedente de `repository_live/show.ex`.

---

## `TheBand.Ontology.SEON.EO`

### `fetch_person(tenant, person_id) :: {:ok, map()} | {:error, :not_found}`

A pessoa com identidade e proveniência. Pessoa de outro tenant devolve **`:not_found`** — nunca "sem
permissão", porque confirmar existência já é vazamento (FR-015).

### `list_person_teams(tenant, person_id) :: [map()]`

As equipes que a origem declara para a pessoa, **uma consulta**, cada linha com:

| campo | o que é |
|---|---|
| `team_name`, `team_id` | a equipe |
| `organization_login` | **de qual organização** ela é — FR-007 |
| `platform_access_level` | o que a **ferramenta** declara: `MEMBER`, `MAINTAINER` |
| `observed_at`, `last_observed_at` | desde quando, e até quando foi visto |
| `no_longer_observed_at` | preenchido = **houve** vínculo e não está presente |
| `promoted?` | se a evidência virou vínculo da ontologia |

**`platform_access_level` não é papel**, e o contrato diz isso aqui porque é onde a confusão nasce:
quem lê o campo pode achar que `MAINTAINER` mapeia para algum papel da SRO. Não mapeia, e derivar seria
mapear por semelhança de nome.

### `count_roles(tenant) :: non_neg_integer()`

Quantos papéis o tenant cadastrou. Existe para a tela **explicar** a não promoção com base no dado, e
não em texto fixo:

| promovida? | papéis | a tela diz |
|---|---:|---|
| sim | — | o vínculo existe |
| não | **0** | não promovida **porque** não há papel cadastrado |
| não | > 0 | não promovida — e a causa **não** é a ausência de papel |

A terceira linha é impossível hoje — são zero papéis — e vai existir. Um texto fixo daria a explicação
errada com convicção no dia em que ela mudar.

---

## `TheBand.WorkItems`

### `count_assigned_to(tenant, person_id) :: non_neg_integer()`

Em quantas issues **vigentes** a pessoa está designada.

### `count_authored_by(tenant, person_id) :: non_neg_integer()`

Quantas issues **vigentes** a pessoa abriu.

**São duas funções, e não uma com parâmetro de papel.** O nome é onde a distinção sobrevive: uma
`count_issues_of_person/2` obrigaria quem chama a explicar qual sentido queria, e quem lê a descobrir.

**A soma das duas é proibida na tela** — FR-009. O contrato não oferece função que a produza.

### `repositories_of_person(tenant, person_id) :: [map()]`

Os repositórios em que a pessoa aparece, **agrupados numa consulta**, cada linha com a evidência que
sustenta o vínculo:

```text
%{observed_repository_id: _, assigned: non_neg_integer(), authored: non_neg_integer()}
```

**Duas contagens por repositório, nunca uma soma.** E o vínculo pessoa-repositório é **derivado**: a
origem nunca o declarou, e a tela precisa dizer isso (FR-010).

### `list_issues(tenant, opts)` — ampliada

`opts` aceita **duas** opções novas, distintas:

| opção | conjunto |
|---|---|
| `assigned_to: person_id` | issues em que ela está designada |
| `authored_by: person_id` | issues que ela abriu |

**Nunca uma opção `person_id:`** que sirva às duas — o nome carrega a distinção, e é a L34 aplicada
antes de doer.

A ordem estável continua sendo `observed_repository_id`, `number`, `id`: ordenar só por número daria
páginas que se sobrepõem, porque o número repete entre repositórios.

---

## A tela

`/people/:id`, com o identificador **interno**. Login não serve: é da origem, muda, e não é único entre
instâncias — a L25.

**Três estados de relação, três formas** — design system, seção 1:

| relação | forma | texto |
|---|---|---|
| equipe declarada pela origem | sólida | o nível de acesso, e a organização |
| repositório em que aparece | hachurada | de que evidência vem — designação, autoria, ou as duas |
| vínculo que saiu | tracejada | desde quando não é observado |

Cor **não** conta como canal, e cada forma tem rótulo de leitor de tela por extenso.

---

## O que este contrato deliberadamente **não** declara

| Ausente | Por quê |
|---|---|
| `count_issues_of_person/2` | produziria a soma que FR-009 proíbe |
| `person_profile/2` que devolva a página | conheceria duas ontologias e dissolveria a fronteira — princípio IX |
| `role_of(person)` | papel não é derivável de nível de acesso — princípio II |
| `promote_membership/2` | promover exige papel; é a #99 e a #100 |
| escrita de qualquer tipo | a feature só lê |
