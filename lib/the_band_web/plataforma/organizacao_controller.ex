defmodule TheBandWeb.Plataforma.OrganizacaoController do
  @moduledoc """
  As organizações, vistas pelo operador — spec 070, T040 (FR-007). Contrato em
  `specs/070-operador-da-plataforma/contracts/rotas-da-plataforma.md` e `suspensao.md`.

  Depende de: nenhuma ontologia. Chama só a fachada `TheBand.Platform`, que confere a autorização
  por dentro: ter passado por `require_operator` não basta (FR-014).
  """
  use TheBandWeb, :controller

  alias TheBand.Platform
  alias TheBandWeb.Plataforma.{OperatorScope, SessaoDoOperador, TelasHTML}

  plug :put_view, html: TelasHTML

  @doc "GET /platform/organizations"
  def index(conn, _params) do
    case Platform.listar_organizacoes(conn.assigns.current_operator_session) do
      {:ok, organizacoes} ->
        render(conn, :organizacoes,
          operador: conn.assigns.current_operator,
          organizacoes: organizacoes
        )

      # A concessão caiu entre o plug e a leitura: o cookie sai, e a resposta é o `404` de sempre.
      {:error, :nao_autorizado} ->
        conn |> SessaoDoOperador.soltar() |> OperatorScope.nao_encontrado()
    end
  end
end
