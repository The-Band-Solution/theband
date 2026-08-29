defmodule TheBand.ProfilesTest do
  @moduledoc """
  A guarda de `request/3` — feature 048, contrato `estado-da-chave.md`.

  A violação primeiro (L03): sem chave NENHUMA, o pedido é recusado ANTES de
  enfileirar — nenhum job nasce condenado. Antes desta guarda o job entrava na
  fila e falhava no worker, deixando a tela em "pendente" para sempre.
  """
  use TheBand.DataCase, async: false
  use Oban.Testing, repo: TheBand.Repo

  import Mox
  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.AI
  alias TheBand.Profiles

  setup :verify_on_exit!

  setup do
    # Mesma razão do ai_test: a chave do ambiente é do processo, e `:nenhuma` só
    # existe de verdade sem ela.
    anterior = System.get_env("API_KEY")
    System.delete_env("API_KEY")

    on_exit(fn ->
      # Restauração SIMÉTRICA: sem isto, um put_env dentro de teste vaza para a
      # suíte inteira quando `anterior` é nil — foi o flake que derrubou o CI do
      # #596 e deixou o do #594 verde por sorte de seed (2026-08-29).
      if anterior, do: System.put_env("API_KEY", anterior), else: System.delete_env("API_KEY")
    end)

    {tenant, user} = tenant_with_admin()
    %{tenant: tenant, user: user}
  end

  test "a violação: sem chave nenhuma, recusa ANTES de enfileirar", ctx do
    assert {:error, :sem_chave} = Profiles.request(ctx.tenant, Ecto.UUID.generate())
    assert [] = all_enqueued(worker: TheBand.Profiles.GenerateWorker)
  end

  test "a chave do ambiente basta para o caminho da pessoa — é como o dev roda", ctx do
    System.put_env("API_KEY", "sk-do-ambiente")
    on_exit(fn -> System.delete_env("API_KEY") end)

    assert {:ok, _job} = Profiles.request(ctx.tenant, Ecto.UUID.generate(), ctx.user.id)
    assert [_] = all_enqueued(worker: TheBand.Profiles.GenerateWorker)
  end

  test "a credencial do tenant também enfileira", ctx do
    expect(TheBand.LLMHTTPMock, :verify, fn _secret, _opts -> {:ok, ["gpt-5.4"]} end)

    {:ok, _} =
      AI.put(ctx.tenant, %{"secret" => "sk-uma-chave-de-teste-bem-longa-1234"}, ctx.user.id)

    assert {:ok, _job} = Profiles.request(ctx.tenant, Ecto.UUID.generate(), ctx.user.id)
  end
end
