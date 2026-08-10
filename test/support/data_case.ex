defmodule TheBand.DataCase do
  @moduledoc """
  Base dos testes que tocam o banco.

  Traz `fixtures/0` para criar dois tenants povoáveis — as verificações de
  isolamento exigem os dois ao mesmo tempo, e um teste que cria só um não prova
  nada sobre vazamento.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias TheBand.Ontology.SEON.EO

  using do
    quote do
      import Ecto.Changeset
      import Ecto.Query
      import TheBand.DataCase

      alias TheBand.Repo
    end
  end

  setup tags do
    pid = Sandbox.start_owner!(TheBand.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
    :ok
  end

  @doc "Cria um tenant com slug único."
  def tenant_fixture(slug \\ nil) do
    slug = slug || "org-#{System.unique_integer([:positive])}"
    {:ok, tenant} = TheBand.Tenants.create_tenant(%{"name" => "Org #{slug}", "slug" => slug})
    tenant
  end

  @doc "Atributos mínimos de uma entidade observada, com proveniência completa."
  def source_attrs(external_id, extra \\ %{}) do
    Map.merge(
      %{
        source_system: "github",
        source_instance: "https://github.com",
        external_id: external_id,
        collected_at: DateTime.utc_now(:second)
      },
      extra
    )
  end

  @doc """
  Uma organização observada, para os testes que precisam de uma equipe.

  Existe porque equipe organizacional **exige** organização desde a feature 002: a
  restrição do banco recusa a linha sem ela. Antes disso os testes criavam equipe
  solta, e passar a exigir a organização é o que se quer — o helper evita repetir
  quatro linhas em cada um.
  """
  def organization_fixture(tenant, login \\ nil) do
    login = login || "org-#{System.unique_integer([:positive])}"

    {:ok, organization} =
      EO.upsert_organization_from_source(
        tenant,
        source_attrs("O_#{login}", %{name: login, login: login})
      )

    organization
  end

  @doc """
  Uma equipe organizacional já ligada a uma organização.

  Passe `organization: org` para reusar uma; sem isso, cria a sua.
  """
  def team_fixture(tenant, external_id, extra \\ %{}) do
    {organization, extra} =
      Map.pop_lazy(extra, :organization, fn -> organization_fixture(tenant) end)

    {:ok, team} =
      EO.upsert_team_from_source(
        tenant,
        source_attrs(
          external_id,
          Map.merge(%{name: "Time #{external_id}", organization_id: organization.id}, extra)
        )
      )

    team
  end

  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
