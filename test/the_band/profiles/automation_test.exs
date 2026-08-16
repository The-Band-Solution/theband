defmodule TheBand.Profiles.AutomationTest do
  @moduledoc """
  Ligar e desligar a geração automática — feature 027, T012.

  ## O que este arquivo protege

  **A automação nunca é um estado sem dono.** Todo ato tem autor e data, e os dois lados são
  guardados: "quem desligou" é a pergunta que aparece quando os perfis param de aparecer.

  **Nasce desligada.** Organização sem evento não está ligada — é o que faz um deploy não
  passar a escrever texto sobre ninguém, sem depender de migração que preencha coluna.
  """
  use TheBand.DataCase, async: false

  import Mox
  import TheBand.ProfileRunFixtures
  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0, tenant_with_admin: 1]

  alias TheBand.Profiles.Automation

  setup :verify_on_exit!

  setup do
    {tenant, admin} = tenant_with_admin()
    %{tenant: tenant, admin: admin}
  end

  describe "o estado inicial" do
    test "organização que nunca ligou não está ligada, e a resposta diz isso", ctx do
      refute Automation.enabled?(ctx.tenant)
      assert Automation.state(ctx.tenant) == :never_enabled
    end

    test "nunca ligada e desligada são respostas diferentes", ctx do
      tenant_com_credencial(ctx.tenant)
      {:ok, _} = Automation.enable(ctx.tenant, ctx.admin)
      {:ok, _} = Automation.disable(ctx.tenant, ctx.admin)

      assert {:disabled, %{by: autor}} = Automation.state(ctx.tenant)

      assert autor.id == ctx.admin.id,
             """
             O estado desligado perdeu o autor.

             É a pergunta que aparece quando os perfis param de aparecer, e um booleano a
             apagaria — que é o desenho que a issue #178 corrigiu em `connected_tools`.
             """
    end
  end

  describe "ligar" do
    test "grava o ato com autor e dispara a primeira rodada na hora", ctx do
      tenant_com_credencial(ctx.tenant)

      assert {:ok, %{event: evento, run: run}} = Automation.enable(ctx.tenant, ctx.admin)

      assert evento.actor_user_id == ctx.admin.id
      assert evento.occurred_at
      assert run.trigger == "manual"
      assert run.requested_by_user_id == ctx.admin.id
      assert Automation.enabled?(ctx.tenant)
    end

    test "sem credencial da organização não liga, e não grava evento", ctx do
      assert {:error, :no_credential} = Automation.enable(ctx.tenant, ctx.admin)

      assert Automation.state(ctx.tenant) == :never_enabled,
             """
             Um evento foi gravado para uma organização que não pode rodar.

             Ligar sem credencial prometeria uma execução que a `FR-011` proíbe: a rodada não
             pode cair na chave do processo, porque a conta de uma organização pagaria a outra.
             """
    end

    test "ligar o que já está ligado não grava um segundo ato", ctx do
      tenant_com_credencial(ctx.tenant)
      {:ok, _} = Automation.enable(ctx.tenant, ctx.admin)

      assert {:error, :already_enabled} = Automation.enable(ctx.tenant, ctx.admin)
      assert length(Automation.history(ctx.tenant)) == 1
    end
  end

  describe "desligar" do
    test "desligar o que está desligado não grava nada", ctx do
      assert {:error, :not_enabled} = Automation.disable(ctx.tenant, ctx.admin)
      assert Automation.history(ctx.tenant) == []
    end

    test "desligar acrescenta um ato, e não apaga o anterior", ctx do
      tenant_com_credencial(ctx.tenant)
      {:ok, _} = Automation.enable(ctx.tenant, ctx.admin)
      {:ok, _} = Automation.disable(ctx.tenant, ctx.admin)

      historico = Automation.history(ctx.tenant)

      assert length(historico) == 2
      assert Enum.map(historico, & &1.event) == ["disabled", "enabled"]
      refute Automation.enabled?(ctx.tenant)
    end
  end

  describe "isolamento entre organizações" do
    test "ligar uma não liga a outra", ctx do
      {outro, _} = tenant_with_admin("outro")
      tenant_com_credencial(ctx.tenant)
      {:ok, _} = Automation.enable(ctx.tenant, ctx.admin)

      refute Automation.enabled?(outro)
      assert Automation.state(outro) == :never_enabled
      assert Automation.enabled_tenants() |> Enum.map(& &1.id) == [ctx.tenant.id]
    end
  end
end
