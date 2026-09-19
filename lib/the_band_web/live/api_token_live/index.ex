defmodule TheBandWeb.ApiTokenLive.Index do
  @moduledoc """
  `/api-tokens` — a credencial que abre a API pública (feature 061, US1 e US3).

  **A tela é exatamente a do protótipo aprovado** em 2026-09-18
  (`specs/061-api-publica/prototipo/`), e a régua da seção 3 do `PROMPT.md` é o critério de
  aceite. Divergência é defeito, não melhoria de implementação.

  ## Os quatro momentos que só se decidem vendo

  1. **o valor em claro, uma vez** — vive no `assign` daquele render, e some ao navegar. Não
     é gravado, não volta por `handle_params`, não volta pelo histórico;
  2. **a máscara** — dezesseis bullets de largura fixa mais os quatro últimos. **Não** é o
     `ToolCredential.masked/1` da casa, que usa quatro: reusá-lo contradiria FR-007, porque
     o comprimento revelaria o do valor;
  3. **o alcance vigente da conta dona**, dentro do formulário — para que a consequência seja
     visível **antes** de ser reclamada, e não quando o painel de terceiro esvaziar;
  4. **a confirmação nomeando o rótulo** — revogar o errado interrompe a integração de um
     terceiro que não está na sala.

  ## O que esta tela recusa, e por que a recusa é escrita

  Autoatendimento, editar, ver o que a integração leu, reativar, dar escopo ao token, e rever
  o valor. Cada uma aparece **como texto**, e não como controle ausente: quem procura um botão
  que não existe precisa saber se ele não existe ainda ou se ele não existe de propósito.

  ## Nenhum prazo é constante aqui

  90, 30 e 14 dias vêm de `api.access.thresholds`. A tela imprime o que a base declara.
  """

  use TheBandWeb, :live_view

  alias TheBand.Tenants
  alias TheBandWeb.ApiTokenLive.View

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "API tokens",
       valor_em_claro: nil,
       rotulo_criado: nil,
       criado_em: nil,
       confirmando: nil,
       erro: nil,
       dono_id: nil
     )
     |> carregar()}
  end

  # O valor em claro NÃO sobrevive a navegação nenhuma — R3.8. `handle_params` roda em todo
  # patch, e limpar aqui é o que garante que o painel não volte pelo botão de voltar.
  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, valor_em_claro: nil)}
  end

  defp carregar(socket) do
    tenant = socket.assigns.current_tenant
    contas = Tenants.list_users(tenant)

    linhas =
      tenant
      |> Tenants.list_api_tokens()
      |> Enum.map(&enriquecer(&1, tenant, contas))

    dono_id = socket.assigns[:dono_id] || conta_padrao(contas, socket)

    socket
    |> assign(
      contas: contas,
      linhas: linhas,
      dono_id: dono_id,
      alcance_previsto: alcance_de(tenant, contas, dono_id),
      contagens: contar(linhas),
      prazos: prazos(),
      aviso_dias: elem(Tenants.api_token_threshold("token_expiry_warning"), 0)
    )
  end

  defp conta_padrao(contas, socket) do
    atual = socket.assigns[:current_user]
    if atual && Enum.any?(contas, &(&1.id == atual.id)), do: atual.id, else: conta_id(contas)
  end

  defp conta_id([primeira | _]), do: primeira.id
  defp conta_id(_), do: nil

  # Os prazos vêm da base, e a tela imprime o que a base declara — R6.5.
  defp prazos do
    {maximo, _} = Tenants.api_token_threshold("token_lifetime")
    [{maximo, "#{maximo} days — the declared maximum"}, {30, "30 days"}, {7, "7 days"}]
  end

  defp enriquecer(%{token: token, estado: estado}, tenant, contas) do
    dono = Enum.find(contas, &(&1.id == token.user_id))

    %{
      token: token,
      estado: estado,
      dono: dono,
      criador: Enum.find(contas, &(&1.id == token.created_by_user_id)),
      revogador: Enum.find(contas, &(&1.id == token.revoked_by_user_id)),
      alcance: dono && alcance(tenant, dono),
      # **Duas marcas na mesma célula, nunca somadas** — R2.17. Um token ativo cuja conta
      # dona está desativada continua ativo E tem toda chamada recusada, e uma afirmação não
      # resume a outra.
      # `disabled_at`, e não um campo `status`: o desligamento desta casa é um instante com
      # autor, e não um enum. Ver `access.account_lifecycle`.
      recusado_por_conta?: not is_nil(dono) and not is_nil(dono.disabled_at)
    }
  end

  defp alcance_de(_tenant, _contas, nil), do: nil

  defp alcance_de(tenant, contas, dono_id) do
    case Enum.find(contas, &(&1.id == dono_id)) do
      nil -> nil
      conta -> alcance(tenant, conta)
    end
  end

  # As duas origens ficam SEPARADAS — R2.4. Somá-las num total ("3 scopes") juntaria o que a
  # pessoa é com o que alguém concedeu a ela, e são coisas diferentes.
  defp alcance(tenant, conta) do
    escopos = Tenants.scopes(tenant, conta)
    {derivados, concedidos} = Enum.split_with(escopos, &(&1.origin != :granted))

    %{
      derivados: Enum.map(derivados, & &1.target_name) |> Enum.reject(&is_nil/1),
      concedidos: Enum.map(concedidos, & &1.target_name) |> Enum.reject(&is_nil/1),
      sem_pessoa?: escopos == [],
      admin?: conta.role == "admin"
    }
  end

  # As contagens NÃO se somam, e a nota diz isso — R2.18. Um token ativo cuja conta está
  # desativada aparece em `active` e mesmo assim é recusado.
  defp contar(linhas) do
    %{
      todos: length(linhas),
      ativos: Enum.count(linhas, &(&1.estado == :ativo)),
      expirados: Enum.count(linhas, &(&1.estado == :expirado)),
      revogados: Enum.count(linhas, &(&1.estado == :revogado)),
      recusados: Enum.count(linhas, & &1.recusado_por_conta?)
    }
  end

  @impl true
  def handle_event("escolher_dono", %{"user_id" => id}, socket) do
    {:noreply, socket |> assign(dono_id: id) |> carregar()}
  end

  def handle_event("criar", %{"label" => rotulo} = params, socket) do
    tenant = socket.assigns.current_tenant
    dono = Enum.find(socket.assigns.contas, &(&1.id == socket.assigns.dono_id))

    attrs = %{label: rotulo, expires_in_days: inteiro(params["expires_in_days"])}

    case Tenants.create_api_token(tenant, dono, attrs, socket.assigns.current_user) do
      {:ok, token, valor} ->
        {:noreply,
         socket
         |> assign(
           valor_em_claro: valor,
           rotulo_criado: token.label,
           criado_em: token.inserted_at,
           erro: nil
         )
         |> carregar()}

      {:error, changeset} ->
        {:noreply, assign(socket, erro: motivo(changeset), valor_em_claro: nil)}
    end
  end

  def handle_event("confirmar_revogacao", %{"id" => id}, socket) do
    {:noreply,
     assign(socket, confirmando: Enum.find(socket.assigns.linhas, &(&1.token.id == id)))}
  end

  def handle_event("cancelar", _params, socket), do: {:noreply, assign(socket, confirmando: nil)}

  def handle_event("revogar", %{"id" => id}, socket) do
    case Tenants.revoke_api_token(socket.assigns.current_tenant, id, socket.assigns.current_user) do
      {:ok, _} ->
        {:noreply, socket |> assign(confirmando: nil, valor_em_claro: nil) |> carregar()}

      {:error, :not_found} ->
        {:noreply,
         assign(socket,
           erro:
             dgettext(
               "errors",
               "This token no longer exists — it may have been revoked in another session."
             ),
           confirmando: nil
         )}
    end
  end

  # O painel some por ação de quem lê, e não só por navegação — R3.8.
  def handle_event("dispensar_valor", _params, socket) do
    {:noreply, assign(socket, valor_em_claro: nil)}
  end

  defp inteiro(nil), do: nil
  defp inteiro(""), do: nil

  defp inteiro(texto) when is_binary(texto) do
    case Integer.parse(texto) do
      {n, _} -> n
      :error -> nil
    end
  end

  # A recusa NOMEIA o campo e diz por que ele importa. "The token could not be created"
  # manda quem lê procurar em toda a tela o que está errado.
  defp motivo(%Ecto.Changeset{errors: errors}) do
    if Keyword.has_key?(errors, :label) do
      dgettext(
        "errors",
        "The label is required — a token without one is a token nobody knows to revoke."
      )
    else
      dgettext("errors", "The token could not be created.")
    end
  end

  # ------------------------------------------------------------------ o render

  @impl true
  def render(assigns), do: View.pagina(assigns)
end
