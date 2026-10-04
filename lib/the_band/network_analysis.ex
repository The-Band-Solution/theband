defmodule TheBand.NetworkAnalysis do
  @moduledoc """
  A análise de rede de uma organização observada — feature 076, épico #1309.

  Duas redes — **revisão** (a da 073) e **designação** (autor da issue → responsável vigente) —,
  em três janelas, com a análise inteira da referência. Nenhuma das duas é colaboração nem
  delegação (A1 da revisão semântica 2), e posição na rede não é desempenho (FR-047).

  Só `defdelegate` (§7.1). Contrato em `specs/076-analise-de-rede/contracts/network-analysis.md`.
  Ninguém fora do módulo toca `NetworkAnalysis.Schemas.Reading` nem a tabela
  `network_analysis_readings`.

  - `read/4` — a **única** porta da leitura para quem consulta, recortada pelo alcance
    recalculado a cada chamada (FR-013, FR-015);
  - `selection/1` — os parâmetros do endereço, por texto exato, sem criar átomo (A12);
  - `options/0` — as listas fechadas para a tela desenhar os seletores;
  - `compute/3` — só o job chama;
  - `subscribe/1` — o aviso de leitura pronta, só com ids.

  Depende de: Tenants, EO, CMPO, WorkItems, ReviewNetwork, KnowledgeBase, sempre pela API pública.
  """

  alias TheBand.NetworkAnalysis.{Commands, Notices, Reader}

  defdelegate read(tenant, user, organization_id, selection), to: Reader
  defdelegate selection(params), to: Reader
  defdelegate options(), to: Reader
  defdelegate compute(tenant, organization, now), to: Commands
  defdelegate subscribe(tenant), to: Notices
end
