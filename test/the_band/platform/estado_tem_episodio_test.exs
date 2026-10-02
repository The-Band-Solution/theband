defmodule TheBand.Platform.EstadoTemEpisodioTest do
  @moduledoc """
  O banco recusa estado sem episódio — spec 070, T044a (`data-model.md` §4a; D1-a, E1, G2, G3, G4).

  O sandbox nunca faz `COMMIT`, e o trigger adiado nunca dispararia. Cada caso força a conferência
  com `SET CONSTRAINTS ALL IMMEDIATE` no fim, que é o `COMMIT` visto de dentro do sandbox. **Por
  `ALL`, e não pelo nome** (G3): pelo nome, com o trigger removido, o comando falharia com
  `constraint … does not exist`, que também é `Postgrex.Error`, e o caso de recusa ficaria verde sem
  a defesa. Por isso a asserção é sobre `postgres.constraint`.
  """
  use TheBand.DataCase, async: true

  import TheBand.OperadorFixtures

  alias TheBand.Platform.Suspension
  alias TheBand.Tenants
  alias TheBand.Tenants.Tenant

  @migracao TheBand.Repo.Migrations.EstadoTemEpisodio
  @arquivo "priv/repo/migrations/20261002140100_estado_tem_episodio.exs"

  defp conferir!, do: Repo.query!("SET CONSTRAINTS ALL IMMEDIATE")

  defp recusado(fun) do
    erro =
      assert_raise Postgrex.Error, fn ->
        Repo.transaction(fn ->
          fun.()
          conferir!()
        end)
      end

    assert erro.postgres.constraint == "tenant_estado_tem_episodio"
  end

  defp passa(fun) do
    assert {:ok, _} =
             Repo.transaction(fn ->
               fun.()
               conferir!()
             end)
  end

  defp suspender_estado(t),
    do: Repo.update_all(from(x in Tenant, where: x.id == ^t.id), set: [status: "suspended"])

  defp reativar_estado(t),
    do: Repo.update_all(from(x in Tenant, where: x.id == ^t.id), set: [status: "active"])

  defp abrir_episodio(t, op) do
    Repo.insert!(%Suspension{
      tenant_id: t.id,
      suspended_at: DateTime.utc_now(:second),
      suspended_by_operator_id: op.id,
      suspend_reason: "contract_ended"
    })
  end

  setup do
    {op, _} = operador_pronto()
    %{op: op, tenant: tenant_fixture()}
  end

  test "suspender o estado por update_all, sem episódio, é recusado no COMMIT", %{tenant: t} do
    recusado(fn -> suspender_estado(t) end)
  end

  test "abrir um episódio numa organização ativa é recusado", %{tenant: t, op: op} do
    recusado(fn -> abrir_episodio(t, op) end)
  end

  test "reativar o estado por update_all, com o episódio aberto, é recusado", %{tenant: t, op: op} do
    passa(fn ->
      suspender_estado(t)
      abrir_episodio(t, op)
    end)

    recusado(fn -> reativar_estado(t) end)
  end

  test "a sequência legítima, estado antes do episódio na mesma transação, passa", %{
    tenant: t,
    op: op
  } do
    passa(fn ->
      suspender_estado(t)
      abrir_episodio(t, op)
    end)
  end

  test "create_tenant de uma organização ativa passa (E1)" do
    passa(fn ->
      {:ok, _} =
        Tenants.create_tenant(%{
          "name" => "Nova",
          "slug" => "nova-#{System.unique_integer([:positive])}"
        })
    end)
  end

  test "o INSERT de uma organização já suspensa, sem episódio, é recusado (T1)" do
    recusado(fn ->
      Repo.insert!(%Tenant{
        name: "Já suspensa",
        slug: "ja-#{System.unique_integer([:positive])}",
        status: "suspended"
      })
    end)
  end

  test "G2: uma tabela temporária tenant_suspensions com linha aberta não faz passar", %{
    tenant: t
  } do
    recusado(fn ->
      Repo.query!(
        "CREATE TEMP TABLE tenant_suspensions (tenant_id uuid, reactivated_at timestamp)"
      )

      Repo.query!("INSERT INTO pg_temp.tenant_suspensions VALUES ($1, NULL)", [
        Ecto.UUID.dump!(t.id)
      ])

      suspender_estado(t)
    end)
  end

  test "G4: o up começa pelo LOCK TABLE, antes da conferência das contagens" do
    fonte = File.read!(@arquivo)
    [corpo_do_up] = Regex.run(~r/def up do\n(.*?)\n  end/s, fonte, capture: :all_but_first)

    primeiro =
      corpo_do_up
      |> String.split("\n")
      |> Enum.reject(&(String.trim(&1) == "" or String.starts_with?(String.trim(&1), "#")))
      |> hd()

    assert primeiro =~
             ~s[execute("LOCK TABLE tenants, tenant_suspensions IN SHARE ROW EXCLUSIVE MODE")]
  end

  test "a conferência do up levanta, com as contagens, quando há organização suspensa sem episódio",
       %{tenant: t} do
    unless Code.ensure_loaded?(@migracao), do: Code.require_file(@arquivo)

    assert :ok = @migracao.conferir_contagens!(Repo)
    suspender_estado(t)

    erro = assert_raise RuntimeError, fn -> @migracao.conferir_contagens!(Repo) end
    assert erro.message =~ ~r/^1 organização\(ões\) suspensa\(s\) sem episódio aberto e 0 ativa/
  end
end
