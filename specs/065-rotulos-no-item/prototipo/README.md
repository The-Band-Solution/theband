# O protótipo do campo de rótulos no detalhe da issue

[`issue-detail-labels.html`](issue-detail-labels.html) — abrir no navegador. Uma tela, separada
pela faixa `screen 1 · /work/issues/:id · card "As the source describes it"`, e a seção final
`Decisions and open questions`. Tudo visível ao carregar; o único controle é *View in
greyscale*, que aplica tons de cinza à página para conferir a SC-003.

Desenhado em **2026-09-29**, a pedido do Product Owner, para corrigir o **defeito D1** da feature
065 (`docs/sprints/032-rotulos-no-item/aceitacao.md`, seção D1, item 1 de *O que falta*), que
recusou a **065/US1** ([#904](https://github.com/The-Band-Solution/theband/issues/904)): o
detalhe mostra só os rótulos do campo, em `badge-ghost`, sem origem e sem o derivado do título.

Publicado em **<https://claude.ai/artifact/EuS2pDSjnvpKuUiQJ4sKSj>**; **a cópia aqui é a que
vale** — o endereço pode mudar, a spec não pode depender dele.

Herda, sem mudar nada, os três protótipos aprovados da 065 em 2026-09-13 (listados no topo da
`spec.md`), em especial a coluna de `/work` (`cd7d0245…`): mesmas marcas, mesmas cores, mesmos
textos de `title`. Nenhum dos três cobria este campo.

A estrutura seção a seção — **a régua do QA** — está na seção 3 do [`PROMPT.md`](PROMPT.md).

**Aprovado em 2026-09-29 pela pessoa mantenedora** — D1–D3 e Q1–Q3, todas pela recomendação do Design.

## O dado que a tela mostra, e de onde veio

Consulta **só de leitura** (`BEGIN READ ONLY … ROLLBACK`) ao `the_band_dev`, em 2026-09-29, via
`docker exec the_band_postgres psql`. Nada foi escrito.

| caso | issue | rótulos do campo (vigentes) | prefixo declarado | conceito vigente |
|---|---|---|---|---|
| defeito | `leds-conectafapes/plataformas-project#461` | `feature`, `otto-bot` | `[Devops]` | development task |
| (a) só do campo | `leds-conectafapes/autherix#13` | `authz`, `documentation`, `feat`, `planning`, `sot` | nenhum | development task |
| (b) campo + título | `leds-conectafapes/conectafapes-project#2212` | `backend` | `[Back-end]` | development task |
| (c) nenhum | `leds-conectafapes/conectafapes-project#956` | nenhum | `[Portal ADM]` — **não** declarado | atomic user story |

Contagens: 5 629 issues; 4 294 sem rótulo no campo; no máximo 6 rótulos de campo numa issue;
371 títulos começam com `[Devops]`; 0 rótulos marcados como não mais observados.

**Divergência com a evidência do D1**: a aceitação cita uma issue `[Devops] …` com rótulo
`backend`. No banco de desenvolvimento **não há** nenhuma (0 linhas) — a evidência veio do
`cenario_real/1` da sonda do papel. O protótipo usa a #461 (`[Devops]` com `feature`,
`otto-bot`), que mostra o mesmo defeito com dado real.

Autor, responsáveis e quadros aparecem como *unchanged*: não mudam, e não se publica nome de
pessoa real que não seja necessário.

## As decisões de desenho — *Decided 2026-09-29*, pela pessoa mantenedora

| # | decisão | a razão |
|---|---|---|
| **D1** | O campo usa o componente, as marcas e os textos de `title` da listagem aprovada, sem mudança — inclusive o azul hachurado para derivado | a mesma etiqueta não pode ler de dois jeitos em duas telas; o componente `<.rotulos>` já existe |
| **D2** | Todos os rótulos aparecem; sem o corte 3 + `+N` | o corte é da linha; o `+N` da listagem é link para esta página com a promessa de que todos estão aqui |
| **D3** | Ordem: campo primeiro, depois título; o campo fica onde está, entre *assignees* e *milestone* | a ordem de `Rotulos.de/2` (FR-012); nada mais se move |

## As perguntas que estavam abertas — *Decided 2026-09-29*, pela pessoa mantenedora, todas em **(a)**

| # | pergunta | opções | recomendação |
|---|---|---|---|
| **Q1** — *Decided (a)* | Escrever a origem ao lado de cada grupo de marcas, ou só o `title`, como na listagem? | (a) uma linha escrita por origem; (b) só marca + `title` | **(a)** — `title` não chega a teclado, telefone nem à captura em cinza, e a SC-003 se mede na captura |
| **Q2** — *Decided (a)* | O derivado pode ficar sob o cartão *As the source describes it*? | (a) sim, no mesmo campo, com a linha escrita; (b) mover o derivado para o cartão *Promotion*; (c) renomear o cartão | **(a)** — o título é o que a origem descreve; separar quebraria o teste independente da US1 |
| **Q3** — *Decided (a)* | Quanto a ausência diz? | (a) *none on the label field at the source, and no declared prefix in the title*; (b) também nomear o colchete que não qualificou; (c) só *no label* | **(a)** — diz de quem é cada metade da ausência e não pede regra nova |

## Fora do escopo desta correção

- **Normalização de caixa dos prefixos** (as 47 variantes, como `[DevOps]`, que hoje não derivam; item 3 do *O que falta* do D1) **não entra na #904**. Decisão da pessoa mantenedora em 2026-09-29: virou a feature [#1023](https://github.com/The-Band-Solution/theband/issues/1023). O protótipo mantém a comparação sensível a caixa, a do catálogo.

## Premissas que a spec carrega até serem contestadas

- Nenhuma medida nova: rótulo e origem já existem na base e em `Rotulos.de/2`.
- A pasta chama-se `prototipo/`, no padrão da casa (`.claude/agents/design.md`, 060, 066), e não
  `prototipos/`.

---

# O protótipo da LINHA divergente em `/work` — 065/US2 emendada (#905)

[`divergences-row.html`](divergences-row.html) — abrir no navegador. Faixas `screen 1 · /work ·
table "Issues" · divergent rows` e `screen 1 · /work · card "divergences"`, seção de origem das
frases por tipo, e `Decisions and open questions`. Botão *View in greyscale* para a SC-003.

Desenhado em **2026-09-30**, para o **defeito D2** de `docs/sprints/032-rotulos-no-item/aceitacao.md`
(AC1(b), AC3, SC-008 e teste independente reprovados), sobre a US2, a FR-014 e a SC-008 emendadas
em 2026-09-30. Publicado em **<https://claude.ai/artifact/Bkv3vSduKwE1y4sgBea8tW>**; **a cópia
aqui é a que vale**. **Aprovado em 2026-09-30 pela pessoa mantenedora** — D1–D4 e Q1–Q3, todas pela recomendação do Design.

**Qual é a "tela de divergências".** Não existe tela própria: `list_divergences/2` só alimenta a
contagem do cartão `divergences` em `/work` (`work_item_live/index.ex`, `length(@divergencias)`).
A divergência aparece **por linha** na tabela *Issues* de `/work` (e na do detalhe do
repositório, `repository_live/show.ex:369`), como uma linha âmbar sob `promoted to` com
`ConceptLabel.divergencia/1`. Qual lado foi seguido só aparece no cartão, por tipo
(`divergencia_mudou_conceito?/1`). O protótipo vale para as **duas** tabelas.

## O dado, e de onde veio

Consulta **só de leitura** (`BEGIN READ ONLY … ROLLBACK`, via `docker exec the_band_postgres
psql` no `the_band_dev`), 2026-09-30. Uma tentativa de `CREATE TEMP VIEW` foi recusada pelo
próprio `READ ONLY`; nada foi escrito.

| fato | valor |
|---|---|
| promoções vigentes | 5 629 |
| divergências vigentes | **711** (a aceitação de 2026-09-29 media 512: o número cresceu com a coleta) |
| tipos de divergência presentes | só `user_story_without_parts`; os outros quatro: 0 linhas |
| `issue_type` das 711 | `Feature` em todas |
| divergentes sem rótulo do campo | 382 (329 com rótulo; máximo 4 rótulos) |
| `declared_concept` preenchido nas 711 | **0** — embora a regra `github_issue_type_routing.yaml` mande registrá-lo |

| caso | issue | tipo | partes | conceito | rótulos |
|---|---|---|---:|---|---|
| com rótulo, 3 + `+N` | `leds-conectafapes/edite-project#6` | Feature | 0 | atomic user story | `dashboard`, `editais`, `feature`, `mensagens` |
| campo + título | `leds-conectafapes/conectafapes-project#2280` | Feature | 0 | atomic user story | `backend` (campo), `Back-end` (título) |
| sem rótulo | `leds-conectafapes/agentes-project#13` | Feature | 0 | atomic user story | nenhum (`[FEATURE]` é prefixo de tipo, não vira rótulo) |
| outro tipo | **`example`** — Epic sem sub-issues | Epic | 0 | atomic user story (estrutura) | nenhum |

A quarta linha é fictícia e marcada `example`: o banco não tem divergência de outro tipo, e ela
mostra a frase quando o lado seguido é a estrutura.

## Decisões

| # | decisão | estado |
|---|---|---|
| **D1** | Tipo declarado (alegação) e conceito derivado (veredito) lado a lado; a linha diz que divergem; o rótulo não é lado | *Decided 2026-09-30*, pessoa mantenedora |
| **D2** | Rótulos como contexto, com origem; sem rótulo, `no label` — atendido pela coluna `labels` aprovada, sem mudança | *Decided 2026-09-30*, pessoa mantenedora |
| **D3** | Cada linha diz em palavras qual lado foi seguido; `user_story_without_parts` → declarado ("concept kept") | *Decided 2026-09-30*, pessoa mantenedora |
| **D4** | O bloco fica dentro de `promoted to`; rótulo nunca entra nele; lado seguido com sublinhado sólido, o outro pontilhado; o vazio do cartão passa a "Declared type and structure agree"; "labelled epic" vira "typed Epic" | *Decided 2026-09-30*, pessoa mantenedora (proposta do Design) |

## As perguntas que estavam abertas — *Decided 2026-09-30*, pela pessoa mantenedora, todas em **(a)**

| # | pergunta | opções | recomendação |
|---|---|---|---|
| **Q1** — *Decided (a)* | A linha leva um "why" que nomeia a estrutura? | (a) sim, uma linha por tipo; (b) não | **(a)** — em `user_story_without_parts` o tipo `Feature` já leva a *atomic user story*; sem o porquê, a linha parece contradição que não existe |
| **Q2** — *Decided (a)* | Onde fica o bloco? | (a) na célula `promoted to`; (b) linha inteira sob a linha; (c) coluna nova | **(a)** — oito colunas, componente de tabela inalterado; (c) seria coluna vazia em 4 918 de 5 629 linhas |
| **Q3** — *Decided (a)*; o `declared_concept` vazio vira bug próprio, aberto pelo Product Owner | A alegação é o tipo como escrito (`issue_type`), porque `declared_concept` nunca é gravado | (a) mostrar o tipo agora e registrar a falta do `declared_concept` como defeito; (b) esperar o registro | **(a)** — o tipo escrito é observado e é a alegação do time; gravar o conceito é outro conserto |

## Premissas

- Nenhuma medida nova: `issue_type`, `derived_concept`, `divergence_kind`, `divergence_reason`
  e `divergencia_mudou_conceito?/1` já existem. O lado seguido sai do mesmo predicado do cartão.
- `label_vs_structure` não é desenhado: existe no `ConceptLabel` e nunca é produzido.
