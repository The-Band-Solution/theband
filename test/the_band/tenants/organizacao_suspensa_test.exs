defmodule TheBand.Tenants.OrganizacaoSuspensaTest do
  @moduledoc """
  `tenants.status` passa a ser lido — achado **H3, parte A**, 2026-09-09.

  ## O que estava lá

  A coluna existia com `default: "active"`, era castável no changeset, e **nenhum
  código a lia**. Medido pelo papel Security: marcar um tenant como `"suspended"` e
  autenticar — as duas coisas funcionavam, e as telas abriam.

  Era uma coluna que **parecia** um controle: quem a marcasse acharia que suspendeu a
  organização, e não teria suspendido nada.

  ## As três portas, e por que as três precisam de teste

  Recusar quem entra não basta se quem já está dentro continua dentro. E o plug cobre a
  requisição HTTP enquanto a hook cobre o socket — a plataforma inteira é LiveView, e
  sem as duas a suspensão valeria na navegação e não na tela.

  ## A recusa é a mesma, e é isso que o segundo teste mede

  Motivo novo na recusa seria enumeração: diria a quem tenta que a conta existe e que o
  identificador está certo.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Repo
  alias TheBand.Tenants

  @senha "senha-bem-comprida-123"

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    {:ok, admin} = Tenants.set_password(tenant, admin.id, @senha)

    %{conn: conn, tenant: tenant, admin: admin}
  end

  defp suspender(tenant) do
    {:ok, suspenso} =
      tenant
      |> Tenants.Tenant.changeset(%{"status" => "suspended"})
      |> Repo.update()

    # A GUARDA DO CENÁRIO: sem ela, um `status` que não gravou faria todos os testes
    # abaixo passarem por a organização continuar ativa — verde afirmando o contrário.
    assert suspenso.status == "suspended"
    suspenso
  end

  describe "a porta da entrada" do
    test "organização suspensa não autentica", ctx do
      assert {:ok, _} = Tenants.authenticate(ctx.admin.email, @senha), """
      A conta autentica ANTES da suspensão. Sem esta asserção, o `refute` abaixo poderia
      passar por a senha estar errada.
      """

      suspender(ctx.tenant)

      assert {:error, :invalid_credentials} = Tenants.authenticate(ctx.admin.email, @senha)
    end

    test "e a recusa é IDÊNTICA à da senha errada — motivo novo seria enumeração", ctx do
      suspender(ctx.tenant)

      suspensa = Tenants.authenticate(ctx.admin.email, @senha)
      senha_errada = Tenants.authenticate(ctx.admin.email, "outra-senha-comprida-9")
      conta_inexistente = Tenants.authenticate("ninguem@example.test", @senha)

      assert suspensa == senha_errada
      assert suspensa == conta_inexistente

      assert suspensa == {:error, :invalid_credentials}, """
      Um motivo próprio para "organização suspensa" diria a quem tenta que a conta
      existe e que o identificador está certo. `auth.ex` tem um ponto único de recusa
      de propósito.
      """
    end

    test "não registra tentativa falha — a credencial pode estar correta", ctx do
      suspender(ctx.tenant)

      {:error, :invalid_credentials} = Tenants.authenticate(ctx.admin.email, @senha)

      {:ok, recarregada} = Tenants.fetch_user(ctx.admin.id)

      assert recarregada.failed_attempts == 0, """
      Gravar falha aqui afirmaria algo falso sobre a senha — ela pode estar perfeitamente
      correta, e é a organização que está suspensa. E deixaria a conta em espera
      crescente no dia em que a organização voltasse.
      """
    end
  end

  describe "a sessão já aberta" do
    test "o LiveView cai quando a organização é suspensa no meio", ctx do
      conn = log_in(ctx.conn, ctx.admin)

      assert {:ok, _live, _html} = live(conn, ~p"/people"), """
      A sessão funciona ANTES da suspensão — senão o teste abaixo mediria uma sessão
      que nunca valeu.
      """

      suspender(ctx.tenant)

      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/people"), """
      Recusar quem entra não basta: quem já estava dentro continuaria dentro, e
      suspender uma organização é ato que precisa valer agora.
      """
    end

    test "e a requisição HTTP também — o plug, e não só a hook", ctx do
      conn = log_in(ctx.conn, ctx.admin)

      suspender(ctx.tenant)

      # `/profile` passa pelo plug antes de qualquer LiveView.
      conn = get(conn, ~p"/profile")

      assert redirected_to(conn) == ~p"/sign-in"
    end
  end

  describe "a organização ativa continua funcionando — o par" do
    test "nada muda para quem não foi suspenso", ctx do
      assert ctx.tenant.status == "active"

      assert {:ok, _} = Tenants.authenticate(ctx.admin.email, @senha)

      assert {:ok, _live, _html} = live(log_in(ctx.conn, ctx.admin), ~p"/people"), """
      Sem este par, o conserto poderia ter trancado a plataforma inteira e a suíte
      ficaria verde afirmando segurança onde não há acesso nenhum.
      """
    end
  end
end
