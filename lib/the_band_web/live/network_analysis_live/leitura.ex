defmodule TheBandWeb.NetworkAnalysisLive.Leitura do
  @moduledoc """
  O que toda página de análise da área faz para ler — feature 076, T037 (`contracts/tela.md`,
  *Toda página da área*).

  Cinco páginas (Graph, Communities, Hubs, Distance, Positions) leem a mesma visão da mesma forma:
  `NetworkAnalysis.read/4` a cada `handle_params` e a cada aviso de leitura pronta, com o alcance
  de **agora** (A22), e o mesmo *"not found"* para os quatro casos (FR-014). Na terceira cópia, a
  função mora aqui (`AGENTS.md` §7.7, regra dos três); cada página continua dona do que mostra.

  Não guarda alcance, não filtra, não decide nada: a visão chega recortada.

  Depende de: nenhuma ontologia.
  """
  use TheBandWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [put_flash: 3, push_navigate: 2]

  use Gettext, backend: TheBandWeb.Gettext

  alias TheBand.NetworkAnalysis
  alias TheBand.Ontology.SEON.EO

  @doc "Lê a visão da organização na seleção, e põe `organizacao`, `selecao` e `visao`."
  @spec ler(Phoenix.LiveView.Socket.t(), term(), map()) :: Phoenix.LiveView.Socket.t()
  def ler(socket, id, selecao) do
    %{current_tenant: tenant, current_user: user} = socket.assigns

    case NetworkAnalysis.read(tenant, user, id, selecao) do
      # O mesmo texto para outro tenant, inexistente e id malformado (FR-014; §11.1).
      {:error, :not_found} ->
        socket
        |> put_flash(:error, dgettext("errors", "Not found."))
        |> push_navigate(to: ~p"/network-analysis")

      {:ausente, motivo} ->
        socket |> com_organizacao(id) |> assign(selecao: selecao, visao: {:ausente, motivo})

      {:ok, visao} ->
        socket |> com_organizacao(id) |> assign(selecao: selecao, visao: visao)
    end
  end

  # A organização já foi conferida por `read/4` (id e tenant): aqui só se busca o nome.
  defp com_organizacao(socket, id) do
    {:ok, organizacao} = EO.fetch_organization(socket.assigns.current_tenant, id)
    assign(socket, organization_id: organizacao.id, organizacao: organizacao)
  end

  @doc "A leitura que vai para o cabeçalho: só quando há leitura a mostrar (3.0.5)."
  @spec para_o_cabecalho(term()) :: map() | nil
  def para_o_cabecalho({:ausente, _}), do: nil
  def para_o_cabecalho(visao), do: visao

  @doc """
  A frase de por que não há leitura a mostrar (R23). Frases da tela, em inglês: não traduzir de
  volta.
  """
  @spec motivo_da_ausencia(atom(), String.t()) :: String.t()
  def motivo_da_ausencia(:not_computed, "review"),
    do:
      "not calculated: the review network of this organisation has no reading for this window " <>
        "yet, or the analysis has not run since"

  def motivo_da_ausencia(:not_computed, _rede),
    do: "not calculated: the platform has not computed this reading yet"

  # E4 da revisão semântica do PR #1383: a leitura da 073 não sabe das contas declaradas
  # vigentes, e a conta declarada seria nó aqui e não na rede de designação.
  def motivo_da_ausencia(:review_reading_outdated, _rede),
    do:
      "not shown: the review network reading was calculated before the latest change to the " <>
        "accounts declared as the organisation's, so it does not know about it; it is " <>
        "recalculated at the next synchronization of this organisation"

  def motivo_da_ausencia(:stale, _rede),
    do: "not shown: this reading is older than the longest window, and was not recalculated"

  @doc "A frase da rede sem aresta na janela."
  @spec sem_aresta(String.t()) :: String.t()
  def sem_aresta("assignment"), do: "no assignment between people in this window"
  def sem_aresta("review"), do: "no review between people in this window"
end
