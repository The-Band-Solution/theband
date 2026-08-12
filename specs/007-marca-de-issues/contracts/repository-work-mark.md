# Contrato — a marca de trabalho no repositório

Feature 007. Escrito **antes** da primeira função pública, como o princípio VII exige.

Duas funções novas, e nenhum módulo novo.

---

## `TheBand.WorkItems`

### `count_collected_by_repository(tenant, repository_ids) :: %{Ecto.UUID.t() => non_neg_integer()}`

Quantas issues **vigentes** cada repositório tem, numa consulta agrupada.

Existe porque a tela chama `count_collected/2` uma vez por repositório — **135 consultas** — e a
marca precisa do mesmo número. Ler duas vezes faria 270; agrupar faz 1.

**Repositório sem nenhuma issue não aparece no mapa.** Quem chama usa `Map.get(mapa, id, 0)` — e
o zero ali significa "nenhuma issue vigente", nunca "não sei". Distinguir os dois é papel de
`issues_collected_at`, não desta função.

**Vigente é `no_longer_observed_at` nulo.** Issue marcada como ausente não conta como trabalho
presente. A coluna de contagem da tela passa a usar esta mesma função, então as duas nunca
divergem — FR-010.

`repository_ids` vazio devolve `%{}` sem consultar.

---

## `TheBand.Ontology.SEON.CMPO`

### `mark_issues_collected(tenant, observed_repository_id, at) :: {:ok, map()} | {:error, :not_found}`

Registra que a fase de issues rodou para este repositório.

Chamada no **mesmo ponto** que grava o checkpoint da fase. Dois pontos diferentes é como a data
fica gravada para uns repositórios e não para outros, e aí a marca mente sobre coleta.

Idempotente: sobrescreve com a data da última coleta.

**Repositório excluído ou inacessível não recebe a data**, porque não foi consultado — e a
ausência dela é a informação.

### `list_observed(tenant, opts)` — ampliada

Passa a expor `issues_collected_at`. Ampliação de `select`, sem mudança de assinatura nem de
fronteira — a mesma feita na feature 006 para `description` e `collected_at`.

---

## O estado da marca — derivado, nunca gravado

A tela combina os dois dados em três valores:

| contagem | `issues_collected_at` | marca | texto |
|---|---|---|---|
| > 0 | qualquer | cheia | `N issues` |
| 0 | presente | vazia | `collected, no issues` |
| 0 | `nil` | desconhecida | `not collected yet` |

E o quarto caso, que não é estado da marca e sim do texto: repositório cujas issues são **todas**
não vigentes exibe **`no current work`** — houve trabalho e ele não está presente.

**Três canais, sempre** — é o design system, seção 1:

| canal | tem | não tem | não se sabe |
|---|---|---|---|
| forma | preenchida | vazia | tracejada |
| texto | `N issues` | `collected, no issues` | `not collected yet` |
| leitor de tela | idem, por extenso | idem | idem |

---

## O que este contrato deliberadamente **não** declara

| Ausente | Por quê |
|---|---|
| `has_work?/2` | booleano no lugar de três estados; apagaria "não se sabe" |
| `work_state/2` no domínio | é estado de exibição; decidir na tela é o lugar certo |
| `set_work_mark/3` | a marca é derivada; gravá-la é a ADR 0004 D7 |
| componente `<.work_mark>` | um chamador só — R1 da pesquisa |
| ordenação ou filtro | fora do escopo pela spec |
