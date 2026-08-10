defmodule TheBand.DataCase do
  @moduledoc """
  Base dos testes que tocam o banco.

  Traz `fixtures/0` para criar dois tenants povoáveis — as verificações de
  isolamento exigem os dois ao mesmo tempo, e um teste que cria só um não prova
  nada sobre vazamento.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

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

  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
