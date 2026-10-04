defmodule TheBand.ReviewNetwork do
  @moduledoc """
  A rede de revisão de uma organização observada — feature 073, épico #1182.

  Leitura derivada da participação `qapo.stakeholder_performed_artifact_evaluation` sobre
  `cmpo.change_request`, entre pessoas de `eo.person`: quem revisou quem, numa janela. **Não** é
  colaboração, e Pull Request não é merge (FR-002, FR-005; regra `review.network.edge`).

  Só `defdelegate` (§7.1). Contrato em `specs/073-rede-de-revisao/contracts/review-network.md`.
  Cada função lê os parâmetros da base (`ReviewNetwork.Parameters`); nenhum valor de janela, k ou
  estado está escrito no código.

  - `read/4` — a **única** porta da leitura para quem consulta, recortada pelo alcance recalculado
    a cada chamada (FR-015);
  - `compute/3` — só o job chama;
  - `windows/0` — as janelas permitidas e a padrão, para a tela desenhar a escolha;
  - `subscribe/1` — o aviso de leitura pronta, só com ids;
  - `current_edges/2` — as arestas vigentes por janela, só com ids, para a análise de rede (076).

  Depende de: EO, CMPO, Quality, Changes, Tenants, KnowledgeBase, sempre pela API pública.
  """

  alias TheBand.ReviewNetwork.{Commands, Notices, Parameters, Queries, Reader}

  defdelegate read(tenant, user, organization_id, window), to: Reader
  defdelegate compute(tenant, organization, now), to: Commands
  defdelegate windows(), to: Parameters
  defdelegate subscribe(tenant), to: Notices

  # A entrada da rede de revisão da análise de rede (076, T028): só ids, sem alcance, para o
  # cálculo. Nenhuma tela a chama.
  defdelegate current_edges(tenant, organization_id), to: Queries
end
