defmodule TheBandWeb.Plataforma.OrganizacaoController do
  @moduledoc """
  As organizações, vistas pelo operador — spec 070, T040 e T056 (FR-003, FR-006, FR-007). Contrato
  em `specs/070-operador-da-plataforma/contracts/rotas-da-plataforma.md` e `suspensao.md`.

  Depende de: nenhuma ontologia. Chama só a fachada `TheBand.Platform`, que confere a autorização
  por dentro: ter passado por `require_operator` não basta (FR-014).

  ## As leituras de `tenants` em cada `POST` (U1, U3)

  - **sucesso**: uma, a de `Tenants.get_by_slug/1` dentro do ato, e o `302` não lê na mesma
    requisição;
  - **recusa do ato**: duas, a do ato e a do resumo, lido **depois** dele para re-renderizar;
  - **confirmação diferente**: uma, só a do resumo, porque o ato não é chamado.

  O controller nunca lê a organização **antes** do ato: entrega o `:slug` da rota.

  A interface fala inglês (AGENTS.md §11.1): as frases daqui são as da tela 5c do protótipo, e não
  devem ser traduzidas de volta.
  """
  use TheBandWeb, :controller

  alias TheBand.Platform
  alias TheBand.Platform.SuspensionReasons
  alias TheBandWeb.Plataforma.{OperatorScope, SessaoDoOperador, TelasHTML}

  plug :put_view, html: TelasHTML

  @doc "GET /platform/organizations"
  def index(conn, _params) do
    case Platform.listar_organizacoes(sessao(conn)) do
      {:ok, organizacoes} ->
        render(conn, :organizacoes, operador: operador(conn), organizacoes: organizacoes)

      {:error, :nao_autorizado} ->
        perdeu_o_papel(conn)
    end
  end

  @doc "GET /platform/organizations/:slug"
  def show(conn, %{"slug" => slug}),
    do: pagina(conn, slug, 200, nil, %{}, Phoenix.Flash.get(conn.assigns.flash, :info))

  @doc "POST /platform/organizations/:slug/suspension"
  def suspension(conn, params), do: ato(conn, params, :suspender)

  @doc "POST /platform/organizations/:slug/reactivation"
  def reactivation(conn, params), do: ato(conn, params, :reativar)

  defp ato(conn, %{"slug" => slug} = params, ato) do
    valores = Map.take(params, ["reason", "note", "confirm_slug"])

    # A confirmação é conferida ANTES do ato, comparação exata: diferente ou ausente, o ato não é
    # chamado e nenhum evento sai, porque não houve tentativa.
    if params["confirm_slug"] == slug do
      atributos = %{reason: texto(params["reason"]), note: texto(params["note"])}

      case executar(ato, sessao(conn), slug, atributos) do
        {:ok, _episodio} ->
          conn
          |> put_flash(:info, sucesso(ato))
          |> redirect(to: ~p"/platform/organizations/#{slug}")

        {:error, :nao_autorizado} ->
          perdeu_o_papel(conn)

        # Slug errado, e não perda do papel: o cookie fica (U2).
        {:error, :not_found} ->
          OperatorScope.nao_encontrado(conn)

        {:error, motivo} ->
          pagina(conn, slug, 422, {ato, motivo}, valores, nil)
      end
    else
      pagina(conn, slug, 422, {ato, :confirmacao}, valores, nil)
    end
  end

  defp executar(:suspender, sessao, slug, attrs), do: Platform.suspender(sessao, slug, attrs)
  defp executar(:reativar, sessao, slug, attrs), do: Platform.reativar(sessao, slug, attrs)

  # A página da organização, lida DEPOIS do ato quando ele recusou (U3). Slug inexistente é o
  # `404`, e ele vence a recusa da confirmação (U4).
  defp pagina(conn, slug, status, recusa, valores, sucesso) do
    case Platform.organizacao(sessao(conn), slug) do
      {:ok, %{resumo: resumo, episodios: episodios}} ->
        conn
        |> put_status(status)
        |> render(:organizacao,
          operador: operador(conn),
          resumo: resumo,
          episodios: episodios,
          recusa: recusa && frase(recusa, resumo, episodios),
          valores: valores,
          sucesso: sucesso
        )

      {:error, :not_found} ->
        OperatorScope.nao_encontrado(conn)

      {:error, :nao_autorizado} ->
        perdeu_o_papel(conn)
    end
  end

  # A concessão ou a sessão caiu entre o plug e o ato: o cookie sai, e a resposta é o `404`.
  defp perdeu_o_papel(conn),
    do: conn |> SessaoDoOperador.soltar() |> OperatorScope.nao_encontrado()

  defp sessao(conn), do: conn.assigns.current_operator_session
  defp operador(conn), do: conn.assigns.current_operator

  defp texto(valor) when is_binary(valor), do: valor
  defp texto(_), do: nil

  # Pelo catálogo, porque vai ao flash (gate da feature 047). O msgid é em português, como no resto
  # da casa, e a tradução `en` é a frase da tela.
  defp sucesso(:suspender),
    do: dgettext("sistema", "Suspensa. Toda sessão foi encerrada e todo token de API, revogado.")

  defp sucesso(:reativar), do: dgettext("sistema", "Reativada. Nenhuma sessão nem token voltou.")

  # As frases de recusa da tela 5c: {título, resto}.
  defp frase({ato, :confirmacao}, resumo, _),
    do:
      {"#{nao(ato)} The confirmation did not match.",
       "Type #{resumo.slug} exactly. Nothing changed."}

  defp frase({:suspender, :ja_suspensa}, resumo, episodios) do
    aberto = Enum.find(episodios, &is_nil(&1.reactivated_at))

    desde =
      if aberto,
        do:
          ", since #{Calendar.strftime(aberto.suspended_at, "%Y-%m-%d %H:%M UTC")}" <>
            if(aberto.suspended_by_operator,
              do: " by #{aberto.suspended_by_operator.name}",
              else: ""
            ),
        else: ""

    {"Not suspended. #{resumo.name} is already suspended#{desde}.",
     "Nothing changed. The page now shows the reactivate form."}
  end

  defp frase({:reativar, :nao_suspensa}, resumo, _),
    do:
      {"Not reactivated. #{resumo.name} is not suspended.",
       "Nothing changed. The page now shows the suspend form."}

  # Fora do protótipo: só alcançável com o trigger de T044a desligado.
  defp frase({:reativar, :sem_episodio_aberto}, resumo, _),
    do:
      {"Not reactivated. No open suspension was found for #{resumo.name}.",
       "Nothing changed. Tell whoever runs the server."}

  defp frase({ato, :vocabulario_nao_declarado}, _, _),
    do:
      {"#{nao(ato)} The list of reasons is not available",
       "in this installation's knowledge base, so no reason can be recorded. Nothing changed. " <>
         "Tell whoever runs the server."}

  defp frase({ato, %Ecto.Changeset{} = changeset}, _, _) do
    campo_da_razao = if ato == :suspender, do: :suspend_reason, else: :reactivate_reason

    if Keyword.has_key?(changeset.errors, campo_da_razao) do
      {"#{nao(ato)} Choose a reason from the list.", "Nothing changed."}
    else
      razao = Ecto.Changeset.get_field(changeset, campo_da_razao)

      {"#{nao(ato)} A note is required for this reason",
       "(#{SuspensionReasons.rotulo(razao)}). #{porque(ato)} Nothing changed."}
    end
  end

  defp nao(:suspender), do: "Not suspended."
  defp nao(:reativar), do: "Not reactivated."

  defp porque(:suspender), do: "Write what was seen and why it calls for suspension."
  defp porque(:reativar), do: "Write why the organisation can come back."
end
