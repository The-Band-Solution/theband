defmodule TheBand.RotacaoTest do
  @moduledoc """
  A rotação da chave mestra recifra **todo** campo cifrado — issue #1052.

  Antes, `mix the_band.rotate_key` recifrava só `tool_credentials`, e a credencial do provedor de
  IA ficava ilegível depois de uma rotação. O primeiro teste é a guarda que pega o próximo campo
  cifrado esquecido. O segundo roda a rotação de verdade: troca as chaves do `Vault`, recifra e
  confere que as duas credenciais continuam legíveis só com a chave nova.

  `async: false`, porque o `Vault` é global e o teste o reinicia com outras chaves.
  """
  use TheBand.DataCase, async: false

  import Mox
  import TheBand.ProfileRunFixtures, only: [tenant_com_credencial: 1]

  alias TheBand.Rotacao
  alias TheBand.Sources.{ConnectedTool, ToolCredential}

  setup :verify_on_exit!

  test "todo campo cifrado de schema da aplicação está na lista da rotação" do
    {:ok, modulos} = :application.get_key(:the_band, :modules)

    cifrados =
      for m <- modulos,
          Code.ensure_loaded?(m),
          function_exported?(m, :__schema__, 1),
          m.__schema__(:source),
          campo <- m.__schema__(:fields),
          m.__schema__(:type, campo) == TheBand.Encrypted.Binary,
          into: MapSet.new(),
          do: {m.__schema__(:source), to_string(campo)}

    assert MapSet.size(cifrados) >= 2, "a enumeração não achou os campos cifrados que existem"

    assert MapSet.difference(cifrados, MapSet.new(Rotacao.campos_cifrados())) == MapSet.new(), """
    Campo cifrado fora da rotação. Depois de rotacionar a chave mestra, ele ficaria ilegível.
    Acrescente-o a `TheBand.Rotacao.campos_cifrados/0`.
    """
  end

  describe "a rotação de verdade" do
    setup do
      original = Application.get_env(:the_band, TheBand.Vault)

      on_exit(fn ->
        Application.put_env(:the_band, TheBand.Vault, original)
        reiniciar_vault()
      end)

      %{original: original}
    end

    test "recifra as credenciais das ferramentas E a do provedor de IA", %{original: original} do
      {tenant, _admin} = TheBandWeb.ConnCase.tenant_with_admin()
      _ = credencial_de_ferramenta(tenant)
      _ = tenant_com_credencial(tenant)

      antiga = Keyword.fetch!(original, :master_key)
      nova = Base.encode64(:crypto.strong_rand_bytes(32))

      trocar_chaves(original, master_key: nova, previous_key: antiga)

      assert {:ok, contagens} = Rotacao.recifrar(false)
      assert contagens["tool_credentials"] >= 1
      assert contagens["ai_provider_credentials"] >= 1

      # Só a chave nova: é o estado depois de remover a anterior do ambiente.
      trocar_chaves(original, master_key: nova, previous_key: nil)

      for {tabela, coluna} <- Rotacao.campos_cifrados() do
        %{rows: rows} = Repo.query!("SELECT #{coluna} FROM #{tabela}")
        assert rows != []

        for [cifrado] <- rows do
          assert {:ok, plano} = TheBand.Vault.decrypt(cifrado)
          assert is_binary(plano), "#{tabela}.#{coluna} ficou ilegível depois da rotação"
        end
      end
    end

    test "com um registro ilegível, nada é gravado", %{original: original} do
      {tenant, _admin} = TheBandWeb.ConnCase.tenant_with_admin()
      _ = credencial_de_ferramenta(tenant)
      %{rows: [[antes]]} = Repo.query!("SELECT secret FROM tool_credentials LIMIT 1")

      # A chave anterior errada: os registros cifrados com a original não abrem.
      trocar_chaves(original,
        master_key: Base.encode64(:crypto.strong_rand_bytes(32)),
        previous_key: Base.encode64(:crypto.strong_rand_bytes(32))
      )

      assert {:error, {:ilegiveis, %{"tool_credentials" => n}}} = Rotacao.recifrar(false)
      assert n >= 1
      assert %{rows: [[^antes]]} = Repo.query!("SELECT secret FROM tool_credentials LIMIT 1")
    end
  end

  defp trocar_chaves(original, chaves) do
    Application.put_env(:the_band, TheBand.Vault, Keyword.merge(original, chaves))
    reiniciar_vault()
  end

  defp reiniciar_vault do
    :ok = Supervisor.terminate_child(TheBand.Supervisor, TheBand.Vault)
    {:ok, _} = Supervisor.restart_child(TheBand.Supervisor, TheBand.Vault)
  end

  defp credencial_de_ferramenta(tenant) do
    {:ok, tool} =
      %ConnectedTool{}
      |> ConnectedTool.changeset(%{
        tenant_id: tenant.id,
        tool_type: "github",
        instance_url: "https://github.com",
        organization_login: "acme-#{System.unique_integer([:positive])}"
      })
      |> Repo.insert()

    {:ok, cred} =
      %ToolCredential{}
      |> ToolCredential.changeset(%{
        tenant_id: tenant.id,
        connected_tool_id: tool.id,
        label: "teste",
        secret: "token-de-teste",
        owner_login: "dono-#{System.unique_integer([:positive])}",
        last_four: "este",
        validated_at: DateTime.utc_now(:second)
      })
      |> Repo.insert()

    cred
  end
end
