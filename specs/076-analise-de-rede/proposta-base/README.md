# Proposta de base de conhecimento — 076, análise de rede

**Status**: proposta, 2026-10-03. **Não** está em `priv/knowledge_base/`: fica aqui até a
pessoa mantenedora decidir D1–D3 da [revisão semântica](../revisao-semantica.md) e a avaliação de
segurança ser incorporada. Formato e processo são os da 073 (`specs/073-rede-de-revisao/proposta-base/`).

> Este documento não reproduz nomes nem logins de pessoas do relatório de referência. A única
> conta citada é a da organização (`LEDS`), que não é pessoa.

## 1. O que vai para onde quando aprovado

| Arquivo | Destino | Id |
|---|---|---|
| `information_needs/network_structure.yaml` | `information_needs/` | `network.structure` |
| `rules/assignment_network_edge.yaml` | `rules/` | `assignment.network.edge` — a aresta de designação, com `equivalence`, `justification`, `limitations` e a categoria UFO |
| `rules/network_analysis_parameters.yaml` | `rules/` | `network.analysis.parameters` — algoritmos, sementes, amostras, tamanhos de lista, layout |
| `rules/network_position_role.yaml` | `rules/` | `network.position_role` — percentil, mínimo de pessoas, cortes e rótulos do papel |
| `rules/review_network_parameters.yaml` | **substitui** `rules/review_network_parameters.yaml` | `review.network.parameters` — só retira a recusa do papel por percentil; `version` não sobe, nenhum valor muda |
| `measurements/assignment_network_issues_count.yaml` | `measurements/` | `assignment.network.issues.count` |
| `measurements/assignment_network_excluded_count.yaml` | `measurements/` | `assignment.network.excluded.count` |
| `measurements/assignment_network_edge_weight_count.yaml` | `measurements/` | `assignment.network.edge_weight.count` |
| `measurements/assignment_network_people_without_edges_count.yaml` | `measurements/` | `assignment.network.people_without_edges.count` |
| `measurements/network_components_count.yaml` | `measurements/` | `network.components.count` |
| `measurements/network_degree_count.yaml` | `measurements/` | `network.degree.count` |
| `measurements/network_degree_centrality_ratio.yaml` | `measurements/` | `network.degree_centrality.ratio` |
| `measurements/network_betweenness_ratio.yaml` | `measurements/` | `network.betweenness.ratio` |
| `measurements/network_closeness_ratio.yaml` | `measurements/` | `network.closeness.ratio` |
| `measurements/network_person_distance_mean.yaml` | `measurements/` | `network.person_distance.mean` |
| `measurements/network_eigenvector_score.yaml` | `measurements/` | `network.eigenvector.score` |
| `measurements/network_position_percentile_percentage.yaml` | `measurements/` | `network.position_percentile.percentage` |
| `measurements/network_communities_count.yaml` | `measurements/` | `network.communities.count` |
| `measurements/network_modularity_score.yaml` | `measurements/` | `network.modularity.score` |
| `measurements/network_community_internal_degree_count.yaml` | `measurements/` | `network.community_internal_degree.count` |
| `measurements/network_average_distance_mean.yaml` | `measurements/` | `network.average_distance.mean` |
| `measurements/network_diameter_count.yaml` | `measurements/` | `network.diameter.count` |
| `measurements/network_global_efficiency_ratio.yaml` | `measurements/` | `network.global_efficiency.ratio` |
| `measurements/network_clustering_ratio.yaml` | `measurements/` | `network.clustering.ratio` |
| `measurements/network_small_world_sigma_score.yaml` | `measurements/` | `network.small_world_sigma.score` |

As medidas `network.*` valem para as duas redes (`review` e `assignment`); as `assignment.network.*`
são o que a rede de designação precisa e a de revisão já tem na 073
(`review.network.reviews.count`, `review.network.excluded.count`,
`review.network.people_without_activity.count`, `review.network.reviews_given.count` e
`reviews_received`).

## 2. Cada análise da referência, e o que muda

| Análise da referência | Vira | O defeito corrigido |
|---|---|---|
| grafo "de colaboração", autor → assignee (`:53-80`) | `assignment.network.edge`, "designação" | não é colaboração nem delegação (S1); laço e erro de linha contados (`:71`, `:76`); bot e conta da organização fora |
| grau (`:87`) | `network.degree.count`, `network.degree_centrality.ratio` | par recíproco contado uma vez; "colabora com N" não é dito |
| intermediação (`:90`) | `network.betweenness.ratio` | sem direção (S4); faixas 0,3/0,1 recusadas |
| proximidade (`:94`) | `network.closeness.ratio` + `network.person_distance.mean` | 1/c não vira distância (`:318`) |
| autovetor (`:98-117`) | `network.eigenvector.score` | por componente, A + I, ausente se não converge; sem 0,01 e sem o grau como reserva; faixas 0,5/0,2 recusadas |
| distância média (`:139-149`) | `network.average_distance.mean` | média sobre pares, com a fração de pares que se alcançam; sem `inf` |
| diâmetro (`:152-162`) | `network.diameter.count` | "entre quem se alcança" |
| eficiência global (`:165`) | `network.global_efficiency.ratio` | lida contra os aleatórios; faixas 0,4/0,7 recusadas |
| clustering (`:184`) | `network.clustering.ratio` | grau < 2 indefinido, e não 0 (S5) |
| σ (`:173-231`) | `network.small_world_sigma.score` | os cinco defeitos (S11) |
| comunidades e modularidade (`:233-256`, `:404`) | `network.communities.count`, `network.modularity.score` | com peso, desempate declarado; Q contra Q_rand; faixas citadas com fonte (S10) |
| "membros mais centrais" (`:413-436`) | `network.community_internal_degree.count` | pessoas distintas, e não grau dirigido |
| componentes (`:277-282`) | `network.components.count` | um critério só, o fraco |
| papel na rede (`:485-510`) | `network.position_role` + `network.position_percentile.percentage` | posto médio; mínimo de 10; cortes com razão; rótulos posicionais (S6, S7) |
| perfil "atribui / recebe" (`:489-528`) | `network.degree.count` (saída e entrada) + `assignment.network.edge_weight.count` | pares com pessoa fora do alcance agregados |
| grafos ponderado e de comunidades, HTML interativo (`:537-820`) | spec FR-020 a FR-026; `network.analysis.parameters.layout` | layout no servidor, semente fixa, mesmas posições nas duas vistas; sem GEXF nem HTML exportado (FR-053) |

## 3. Como foi validado

Ver a [revisão semântica](../revisao-semantica.md), seção 4: `mix knowledge.validate` na cópia
com a proposta deu `EXIT=0` (172 artefatos), `mix knowledge.graph` deu `EXIT=0`, e a validação foi
vista reprovando (`EXIT=1`) com a necessidade trocada por uma inexistente e um campo fora do
schema. Depois de a `version` de `review.network.parameters` voltar a 1, a cópia foi validada de
novo: `EXIT=0`.

## 4. O que não foi verificado

- a forma das três regras, porque `derivation_rule` não tem schema;
- nenhum número contra o banco;
- perguntas de competência, que dependem da D1.
