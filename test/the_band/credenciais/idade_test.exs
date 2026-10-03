defmodule TheBand.Credenciais.IdadeTest do
  @moduledoc """
  A idade da credencial — 064/T017 e T019, FR-016, FR-018 e FR-019.

  ## O que este arquivo protege

  **Sem data, a idade é desconhecida, e nunca "no prazo".** É a violação que o arquivo existe
  para pegar, e não o caminho feliz: um `nil` lido como juventude esconderia justamente a
  credencial de que ninguém sabe nada.

  **Trocar a chave zera a contagem, e regravar a mesma não.** Sem a data da troca, a cobrança
  seguinte não sabe se a anterior foi atendida.

  O Mox substitui **só** a borda HTTP do provedor.
  """
  use TheBand.DataCase, async: false

  import Mox
  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.AI
  alias TheBand.AI.ProviderCredential
  alias TheBand.Credenciais.Idade
  alias TheBand.Repo
  alias TheBand.Sources.ToolCredential

  setup :verify_on_exit!

  @agora ~U[2026-10-03 12:00:00Z]
  @ontem ~U[2026-10-02 12:00:00Z]
  @quatro_meses_atras ~U[2026-06-03 12:00:00Z]

  @chave "sk-uma-chave-de-teste-com-mais-de-vinte-caracteres-9876"
  @outra_chave "sk-outra-chave-de-teste-com-mais-de-vinte-caracteres-5432"

  describe "estado/2 — T017" do
    test "credencial de ferramenta de quatro meses está vencida; a de ontem, no prazo" do
      assert Idade.estado(%ToolCredential{validated_at: @quatro_meses_atras}, @agora) == :vencida
      assert Idade.estado(%ToolCredential{validated_at: @ontem}, @agora) == :no_prazo
    end

    test "chave de modelo de quatro meses está vencida; a de ontem, no prazo" do
      assert Idade.estado(%ProviderCredential{secret_set_at: @quatro_meses_atras}, @agora) ==
               :vencida

      assert Idade.estado(%ProviderCredential{secret_set_at: @ontem}, @agora) == :no_prazo
    end

    test "sem data, a idade é desconhecida — e NÃO está no prazo" do
      for credencial <- [%ToolCredential{validated_at: nil}, %ProviderCredential{}] do
        estado = Idade.estado(credencial, @agora)

        assert estado == :idade_desconhecida
        # A afirmação que importa: ausência de data não é prova de juventude (FR-019).
        refute estado == :no_prazo
        assert Idade.em_uso_desde(credencial) == nil
      end
    end

    test "o prazo é de três meses de calendário, e passar dele é estrito" do
      assert Idade.limite_em_meses() == 3
      desde = ~U[2026-09-04 10:00:00Z]

      assert Idade.estado(%ToolCredential{validated_at: desde}, ~U[2026-12-04 10:00:00Z]) ==
               :no_prazo

      assert Idade.estado(%ToolCredential{validated_at: desde}, ~U[2026-12-04 10:00:01Z]) ==
               :vencida
    end

    test "chave de modelo anterior à data da troca conta da validação" do
      credencial = %ProviderCredential{secret_set_at: nil, validated_at: @quatro_meses_atras}

      assert Idade.em_uso_desde(credencial) == @quatro_meses_atras
      assert Idade.estado(credencial, @agora) == :vencida
    end
  end

  describe "a troca da chave do modelo — T019" do
    setup do
      # A chave do ambiente é do processo; sem tirá-la, o teste dependeria do `.env` de quem
      # rodou. Restauração simétrica, como em `ai_test.exs`.
      anterior = System.get_env("API_KEY")
      System.delete_env("API_KEY")

      on_exit(fn ->
        if anterior, do: System.put_env("API_KEY", anterior), else: System.delete_env("API_KEY")
      end)

      {tenant, user} = tenant_with_admin()
      %{tenant: tenant, user: user}
    end

    defp aceita(vezes) do
      expect(TheBand.LLMHTTPMock, :verify, vezes, fn _secret, _opts -> {:ok, ["gpt-5.4-mini"]} end)
    end

    # Envelhece a credencial gravada: é a única forma de ter uma de quatro meses sem esperar.
    defp envelhecer(tenant) do
      {1, _} =
        Repo.update_all(
          from(c in ProviderCredential, where: c.tenant_id == ^tenant.id),
          set: [secret_set_at: @quatro_meses_atras, validated_at: @quatro_meses_atras]
        )

      {:ok, cred} = AI.fetch(tenant)
      cred
    end

    test "a primeira gravação registra quando o segredo passou a valer", ctx do
      aceita(1)
      {:ok, cred} = AI.put(ctx.tenant, %{"secret" => @chave}, ctx.user.id)

      assert %DateTime{} = cred.secret_set_at
      assert cred.previous_secret_set_at == nil
      assert Idade.estado(cred, DateTime.utc_now(:second)) == :no_prazo
    end

    test "credencial vencida, troca, e o estado volta a no prazo — com a data anterior guardada",
         ctx do
      aceita(2)
      {:ok, _} = AI.put(ctx.tenant, %{"secret" => @chave}, ctx.user.id)
      vencida = envelhecer(ctx.tenant)
      assert Idade.estado(vencida, DateTime.utc_now(:second)) == :vencida

      {:ok, _} = AI.put(ctx.tenant, %{"secret" => @outra_chave}, ctx.user.id)
      {:ok, trocada} = AI.fetch(ctx.tenant)

      assert Idade.estado(trocada, DateTime.utc_now(:second)) == :no_prazo
      assert DateTime.compare(trocada.secret_set_at, @quatro_meses_atras) == :gt
      # "A data anterior não é perdida" (T019).
      assert trocada.previous_secret_set_at == @quatro_meses_atras
    end

    test "regravar a mesma chave não é troca, e a contagem não zera", ctx do
      aceita(2)
      {:ok, _} = AI.put(ctx.tenant, %{"secret" => @chave}, ctx.user.id)
      _vencida = envelhecer(ctx.tenant)

      {:ok, _} = AI.put(ctx.tenant, %{"secret" => @chave}, ctx.user.id)
      {:ok, regravada} = AI.fetch(ctx.tenant)

      assert Idade.estado(regravada, DateTime.utc_now(:second)) == :vencida
      assert regravada.secret_set_at == @quatro_meses_atras
      assert regravada.previous_secret_set_at == nil
    end

    test "as datas da troca não vêm de quem chama", ctx do
      aceita(2)
      {:ok, _} = AI.put(ctx.tenant, %{"secret" => @chave}, ctx.user.id)
      _vencida = envelhecer(ctx.tenant)

      # Uma data recente forjada esconderia a credencial vencida (achado 2 da avaliação).
      forjado = %{
        "secret" => @chave,
        "secret_set_at" => DateTime.to_iso8601(@agora),
        "previous_secret_set_at" => DateTime.to_iso8601(@agora)
      }

      {:ok, _} = AI.put(ctx.tenant, forjado, ctx.user.id)
      {:ok, regravada} = AI.fetch(ctx.tenant)

      assert regravada.secret_set_at == @quatro_meses_atras
      assert regravada.previous_secret_set_at == nil
      assert Idade.estado(regravada, DateTime.utc_now(:second)) == :vencida

      # `put/3` monta os próprios atributos, então a prova de cima não alcança outro chamador.
      # O changeset é que não pode aceitá-las: quem o usar direto também não as forja.
      changeset = ProviderCredential.changeset(%ProviderCredential{}, forjado)
      refute Map.has_key?(changeset.changes, :secret_set_at)
      refute Map.has_key?(changeset.changes, :previous_secret_set_at)
    end

    test "linha anterior à migração, trocada, guarda a validação como data anterior", ctx do
      aceita(2)
      {:ok, _} = AI.put(ctx.tenant, %{"secret" => @chave}, ctx.user.id)

      {1, _} =
        Repo.update_all(
          from(c in ProviderCredential, where: c.tenant_id == ^ctx.tenant.id),
          set: [secret_set_at: nil, validated_at: @quatro_meses_atras]
        )

      {:ok, _} = AI.put(ctx.tenant, %{"secret" => @outra_chave}, ctx.user.id)
      {:ok, trocada} = AI.fetch(ctx.tenant)

      assert trocada.previous_secret_set_at == @quatro_meses_atras
      assert Idade.estado(trocada, DateTime.utc_now(:second)) == :no_prazo
    end
  end
end
