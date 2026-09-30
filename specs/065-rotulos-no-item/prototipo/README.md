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
