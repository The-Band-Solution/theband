defmodule TheBand.SuspensaoFixtures do
  @moduledoc """
  O que os testes de suspensão da spec 070 precisam montar: uma organização povoada (contas com
  sessão aberta e tokens) e uma sessão de operador. Pelos caminhos reais de `Tenants` e de
  `Platform.Sessions`.
  """
  alias TheBand.Platform.Sessions
  alias TheBand.Tenants
  alias TheBand.Tenants.Sessions, as: SessoesDasOrganizacoes

  @doc "Uma organização com duas contas, cada uma com sessão aberta, e um token de API."
  def organizacao_povoada do
    tenant = TheBand.DataCase.tenant_fixture()
    admin = TheBand.DataCase.user_fixture(tenant)

    {:ok, outra} =
      Tenants.create_user(tenant, %{
        "email" => "m-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    sessoes =
      for conta <- [admin, outra] do
        {:ok, {sessao, _}} = SessoesDasOrganizacoes.abrir(conta)
        sessao
      end

    {:ok, token, _} = Tenants.create_api_token(tenant, admin, %{label: "painel"}, admin)
    %{tenant: tenant, admin: admin, sessoes: sessoes, token: token}
  end

  @doc "Uma sessão de operador pronta, aberta pelo caminho real."
  def sessao_de_operador do
    {op, _} = TheBand.OperadorFixtures.operador_pronto()
    {:ok, {sessao, _}} = Sessions.abrir(op)
    {op, sessao}
  end

  @doc "Procura `%TheBand.Tenants.Tenant{}` em qualquer profundidade do termo (D1-d)."
  def tem_tenant?(%TheBand.Tenants.Tenant{}), do: true

  def tem_tenant?(%_{} = struct),
    do: struct |> Map.from_struct() |> Map.values() |> Enum.any?(&tem_tenant?/1)

  def tem_tenant?(%{} = mapa), do: mapa |> Map.values() |> Enum.any?(&tem_tenant?/1)
  def tem_tenant?(lista) when is_list(lista), do: Enum.any?(lista, &tem_tenant?/1)

  def tem_tenant?(tupla) when is_tuple(tupla),
    do: tupla |> Tuple.to_list() |> Enum.any?(&tem_tenant?/1)

  def tem_tenant?(_), do: false
end
