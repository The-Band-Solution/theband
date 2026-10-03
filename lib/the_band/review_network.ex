defmodule TheBand.ReviewNetwork do
  @moduledoc """
  A rede de revisão de uma organização observada — feature 073, épico #1182.

  Leitura derivada da participação `qapo.stakeholder_performed_artifact_evaluation` sobre
  `cmpo.change_request`, entre pessoas de `eo.person`: quem revisou quem, numa janela. **Não** é
  colaboração, e Pull Request não é merge (FR-002, FR-005).

  Só `defdelegate` (§7.1). Contrato em `specs/073-rede-de-revisao/contracts/review-network.md`.

  **Estado em 2026-10-03**: só `compute/3` está ligado, e ele levanta até a base declarar os
  parâmetros (`ReviewNetwork.Parameters`, T013). `read/4`, `windows/0` e `subscribe/1` entram com a
  T017, quando a base existir; as funções internas que eles chamarão (`Reader.read/5`,
  `Commands.compute/4`) já estão escritas e provadas com os parâmetros como argumento.

  Depende de: EO, CMPO, Quality, Changes, Tenants, KnowledgeBase, sempre pela API pública.
  """

  alias TheBand.ReviewNetwork.Commands

  defdelegate compute(tenant, organization, now), to: Commands
end
