# Contrato — as telas da área Network analysis

A régua é o protótipo aprovado ([`prototipo/PROMPT.md`](../prototipo/PROMPT.md) §3), com as
divergências de [research.md R21](../research.md#r21--divergências-do-protótipo-aprovado-e-o-que-vale):
o código segue a spec e a base. Tudo que vai para a tela é em inglês (§11.1).

## Rotas

Todas `live`, no `live_session :autenticado` (`require_user`). Nenhuma outra rota da área (FR-053).

| rota | LiveView | o que mostra |
|---|---|---|
| `/network-analysis` | `NetworkAnalysisLive.Index` | a área (3.1): as duas arestas definidas, os seis cartões, a frase de não-avaliação; escolhe a organização; com uma só, `push_navigate` para ela |
| `/network-analysis/:organization_id` | `ReviewNetworkLive.Show` (073) | a rede de revisão da 073, **com o aviso dela** (US1, cen. 5) |
| `/network-analysis/:organization_id/graph` | `NetworkAnalysisLive.Graph` | US2 (contagens) e US3 (grafo ponderado, alternância para comunidades) |
| `/network-analysis/:organization_id/communities` | `NetworkAnalysisLive.Communities` | US4 |
| `/network-analysis/:organization_id/hubs` | `NetworkAnalysisLive.Hubs` | US5 |
| `/network-analysis/:organization_id/distance` | `NetworkAnalysisLive.Distance` | US6 e US7 |
| `/network-analysis/:organization_id/positions` | `NetworkAnalysisLive.Positions` | US8, lista por nome |
| `/network-analysis/:organization_id/people/:person_id` | `NetworkAnalysisLive.Profile` | US9 |
| `/organizations/:id/review-network` | `ReviewNetworkLive.Show`, ação `:legacy` | `push_navigate` para `~p"/network-analysis/#{org.id}?window=#{janela}"`, com o id validado (FR-003, A13) |

Parâmetros: `network`, `window`, `view`, normalizados por `NetworkAnalysis.selection/1`. A escolha
de rede e janela acompanha a navegação (3.0.3): os links entre as páginas levam os dois.

## Toda página da área

- `NetworkAnalysisLive.Shared.header/1`: título, a pergunta da página, os seletores, a linha da
  leitura (data, *derived*, janela, coleta mais nova), e o aviso de alcance parcial
  *"Names appear only for the people you reach. Measures are computed over the whole network. People
  outside your reach appear grouped, without names, and only in groups of at least 3."* (US1, cen. 5);
- `mount/3` não guarda alcance; `handle_params/3` chama `NetworkAnalysis.read/4` a cada navegação e a
  cada aviso de leitura pronta (A22);
- `assigns` guardam só a visão recortada (R6, item 4);
- `{:error, :not_found}` → a página *"not found"*, igual para os quatro casos (FR-014);
- `{:ausente, motivo}` → `<.absent reason=...>` com a frase do motivo; nunca 0, `—`, célula vazia;
- todo número com a marca `<.marca tipo={:derivado} />`, como a 073 (`review_network_live/show.ex`);
  ausência com `<.absent reason=...>` (§11.1, regras 1 e 2; FR-051);
- a frase *"Position in this network and window. It does not measure performance, importance or
  merit, and must not be used to evaluate a person."* ao lado de hubs e papéis (FR-047);
- a rede de designação diz em uma frase o que a aresta liga e que **não** diz quem designou nem quem
  executou (US2, cen. 5). Nenhum texto usa *collaboration* nem *delegation*.

**Emenda de 2026-10-04 (T019, T020)**, feita no mesmo commit da implementação:

- `NetworkAnalysisLive.Shared` expõe, além de `header/1`: `area_nav/1` (as seis páginas, na ordem
  de 3.0.1, com a rede e a janela em todo link, 3.0.3), `marca/1` (a mesma marca da 073),
  `page_path/3` (o caminho de uma página com a seleção), `link_label/1` (as frases das duas
  arestas) e `pages/0`. `page_path`, e não `path`: o nome colide com `Phoenix.VerifiedRoutes.path/3`;
- **página que ainda não existe** aparece na ordem, sem link, e nunca como link quebrado: as fatias
  são PRs empilhados (US1 só tem a rede de revisão; US2 traz *Graph*);
- os seis cartões de `/network-analysis` (3.1.3) descrevem as páginas e não têm link: a área não
  tem organização escolhida, e o link de cada página é por organização. A escolha da organização,
  logo acima, é o que leva à área dela;
- `{:error, :not_found}`, nos dois endereços da rede de revisão, volta a `/network-analysis` com
  *"Not found."*, igual para outro tenant, inexistente e id malformado (FR-014). A breadcrumb da
  página da 073 continua a dela (Q4 (a)).

## O grafo (FR-020 a FR-026)

Componente `GraphComponents.graph/1`, SVG inline. Restrições, todas testáveis no HTML entregue:

- nenhum `raw/1`, `<foreignObject>`, `data-*` com JSON, `<img src="data:">`;
- `style` só com número formatado no servidor; cor por classe da paleta;
- `href` só por `~p` e só para o perfil de alcançado;
- id de nó: `person_id` de alcançado; `outside-<n>` de agregado;
- hook `.NetworkGraph` co-localizado: só `transform`; nenhum `pushEvent`, nenhum `handleEvent`;
- destaque por `JS.add_class/remove_class`; **não existe** `handle_event` de destaque;
- `<title>` de agregado diz só quantas pessoas contém (3.7.3);
- `hidden sm:block` no SVG, lista empilhada `sm:hidden` com `data-label` (FR-025).

## O que estas telas não oferecem

Botão de exportar, `download`, `Content-Disposition`, *"copy as image"*, folha de impressão do
grafo, ordenação por coluna na lista de pessoas, nenhum evento que dispare cálculo.
