defmodule TheBand.Tenants.ContaDesativadaTest do
  @moduledoc """
  A conta desativada — achado **H3, parte B**, 2026-09-09.

  ## O que não existia

  `users` tinha `email`, `name`, `role` e `tenant_id`. `tenants` tinha `status`;
  `users` não tinha nada equivalente. A tela de contas oferecia criar, reiniciar senha,
  associar e revogar elo — **não havia desativar**.

  O desligamento era **implícito**: quem administra reiniciava a senha e não entregava a
  temporária. Funcionava — `senha_changeset/3` gira o `session_token` —, e era frágil por
  três razões, todas medidas:

  1. **não estava escrito em lugar nenhum**, e dependia de quem administra saber;
  2. **era indistinguível de um reinício legítimo** no histórico e na tela: a conta
     desligada aparecia como `temporária pendente`, igual à recém-criada, e o ato de
     rotina para a segunda **reativava** a primeira;
  3. **para de funcionar no dia em que existir token** — o token não é a senha, e trocar
     a senha não o invalida.

  ## E o que ele NÃO é

  Não é `revoke_person/3`. Aquele significa *"não sabemos mais qual pessoa observada é
  esta conta"*; este, *"esta conta não entra mais"*. O H3 mediu que revogar o elo **não
  remove acesso**, e é o que torna a distinção prática.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Tenants
  alias TheBand.Tenants.User

  @senha "senha-bem-comprida-123"

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    {:ok, admin} = Tenants.set_password(tenant, admin.id, @senha)

    {:ok, alvo} =
      Tenants.create_user(tenant, %{
        "email" => "alvo-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    {:ok, alvo} = Tenants.set_password(tenant, alvo.id, @senha)

    %{conn: conn, tenant: tenant, admin: admin, alvo: alvo}
  end

  describe "a porta da entrada" do
    test "conta desativada não autentica, e a recusa é IDÊNTICA", ctx do
      assert {:ok, _} = Tenants.authenticate(ctx.alvo.email, @senha), """
      A conta autentica ANTES de ser desativada. Sem esta asserção, o teste abaixo poderia
      passar por a senha estar errada.
      """

      {:ok, desativada} = Tenants.disable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id)
      refute User.ativa?(desativada), "a guarda do cenário: a conta foi de facto desativada"

      recusa = Tenants.authenticate(ctx.alvo.email, @senha)
      senha_errada = Tenants.authenticate(ctx.alvo.email, "outra-senha-comprida-9")
      inexistente = Tenants.authenticate("ninguem@example.test", @senha)

      assert recusa == senha_errada
      assert recusa == inexistente

      assert recusa == {:error, :invalid_credentials}, """
      Motivo próprio para "conta desativada" diria a quem tenta que a conta existe e que o
      identificador está certo. `auth.ex` tem um ponto único de recusa de propósito.
      """
    end

    test "não registra tentativa falha — a credencial pode estar correta", ctx do
      {:ok, _} = Tenants.disable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id)
      {:error, :invalid_credentials} = Tenants.authenticate(ctx.alvo.email, @senha)

      {:ok, recarregada} = Tenants.fetch_user(ctx.alvo.id)

      assert recarregada.failed_attempts == 0, """
      A senha estava certa; é a conta que está desativada. Gravar falha afirmaria algo
      falso sobre a credencial, e deixaria a conta em espera crescente no dia em que fosse
      reativada.
      """
    end
  end

  describe "a sessão já aberta" do
    test "o LiveView cai, e a linha NÃO é apagada", ctx do
      conn = log_in(ctx.conn, ctx.alvo)

      assert {:ok, _live, _html} = live(conn, ~p"/people"),
             "a sessão funciona antes — senão o teste mediria uma sessão que nunca valeu"

      {:ok, _} = Tenants.disable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id)

      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/people")

      # A ASSERÇÃO QUE O SECURITY PEDIU EXPLICITAMENTE: marca, nunca `delete`.
      assert {:ok, ainda_la} = Tenants.fetch_user(ctx.alvo.id), """
      A linha tem de continuar em `users`. Histórico de acesso é dado de auditoria
      (SC-005 da 045), e é exactamente o que um incidente precisa reconstruir.
      """

      refute is_nil(ainda_la.disabled_at)

      assert ainda_la.disabled_by_user_id == ctx.admin.id,
             "sem autoria, a marca não responde quem"
    end

    test "e a requisição HTTP também — o plug, e não só a hook", ctx do
      conn = log_in(ctx.conn, ctx.alvo)
      {:ok, _} = Tenants.disable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id)

      assert redirected_to(get(conn, ~p"/profile")) == ~p"/sign-in"
    end
  end

  describe "as recusas do ato" do
    test "não se desativa a própria conta", ctx do
      assert {:error, :nao_pode_desativar_a_si} =
               Tenants.disable_user(ctx.tenant, ctx.admin.id, ctx.admin.id),
             """
             Desativar-se a si é ficar de fora sem ter a quem pedir de volta — e num tenant com
             uma administração só, isso tranca a organização inteira.
             """
    end

    test "não desativa conta de OUTRO tenant", ctx do
      {outro, admin_de_fora} = tenant_with_admin()

      assert {:error, :not_found} =
               Tenants.disable_user(ctx.tenant, admin_de_fora.id, ctx.admin.id),
             """
             O isolamento por tenant é o princípio V, e vale para os atos e não só para as
             leituras.
             """

      assert {:error, :not_found} = Tenants.disable_user(outro, ctx.alvo.id, admin_de_fora.id)
    end

    test "desativar duas vezes é recusado com motivo próprio", ctx do
      {:ok, _} = Tenants.disable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id)

      assert {:error, :ja_desativada} =
               Tenants.disable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id)
    end
  end

  describe "reativar" do
    test "devolve o acesso, e NÃO devolve a senha", ctx do
      {:ok, _} = Tenants.disable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id)
      {:ok, reativada} = Tenants.enable_user(ctx.tenant, ctx.alvo.id)

      assert User.ativa?(reativada)
      assert is_nil(reativada.disabled_by_user_id), "a marca sai inteira, e não pela metade"

      assert {:ok, _} = Tenants.authenticate(ctx.alvo.email, @senha), """
      A senha desta conta não foi tocada pela desativação, então reativar a devolve. O
      caso que importa é o outro: se a desativação tiver sido feita JUNTO de um reinício,
      a senha continua sendo a temporária que ninguém entregou — e é o teste seguinte.
      """
    end

    test "reativar depois de reiniciar a senha não devolve a senha antiga", ctx do
      {:ok, _temporaria} = Tenants.reset_password(ctx.tenant, ctx.alvo.id, ctx.admin.id)
      {:ok, _} = Tenants.disable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id)
      {:ok, _} = Tenants.enable_user(ctx.tenant, ctx.alvo.id)

      assert {:error, :invalid_credentials} = Tenants.authenticate(ctx.alvo.email, @senha), """
      Reativar é dizer "esta conta entra de novo", e não "esta conta lembra a senha".
      Juntar as duas coisas num ato só faria quem reativa devolver acesso com uma
      credencial que ele não escolheu.
      """
    end

    test "reativar conta ativa é recusado", ctx do
      assert {:error, :ja_ativa} = Tenants.enable_user(ctx.tenant, ctx.alvo.id)
    end
  end

  describe "a tela de contas" do
    test "o estado DESATIVADA é distinguível de temporária pendente", ctx do
      {:ok, _temporaria} = Tenants.reset_password(ctx.tenant, ctx.alvo.id, ctx.admin.id)

      {:ok, live, html} = live(log_in(ctx.conn, ctx.admin), ~p"/accounts")

      assert html =~ "temporária pendente", """
      A guarda do cenário: a conta está em temporária pendente ANTES de ser desativada,
      que é justamente o estado com que o desligamento se confundia.
      """

      html = render_click(live, "desativar", %{"id" => ctx.alvo.id})

      assert html =~ "desativada", "o estado novo aparece"

      # E O ACHADO DO PRODUCT OWNER: os dois estados deixam de ser o mesmo texto.
      [_antes, depois] = String.split(html, ctx.alvo.email, parts: 2)
      [linha, _] = String.split(depois, "</tr>", parts: 2)

      refute linha =~ "temporária pendente", """
      Era o achado: a conta desligada aparecia como `temporária pendente`, igual à
      recém-criada — e o ato de rotina para a segunda REATIVAVA a primeira.
      """
    end

    test "o botão de desativar não aparece na própria linha", ctx do
      {:ok, _live, html} = live(log_in(ctx.conn, ctx.admin), ~p"/accounts")

      [_antes, minha_linha] = String.split(html, ctx.admin.email, parts: 2)
      [minha_linha, _] = String.split(minha_linha, "</tr>", parts: 2)

      refute minha_linha =~ "Desativar", """
      A tela esconder não é a defesa — o domínio recusa igual, e há teste. É a cortesia
      de não oferecer um botão que sempre falha.
      """
    end

    test "conta desativada não oferece reiniciar senha, e oferece reativar", ctx do
      {:ok, live, _html} = live(log_in(ctx.conn, ctx.admin), ~p"/accounts")
      html = render_click(live, "desativar", %{"id" => ctx.alvo.id})

      [_antes, linha] = String.split(html, ctx.alvo.email, parts: 2)
      [linha, _] = String.split(linha, "</tr>", parts: 2)

      assert linha =~ "Reativar"

      refute linha =~ "Reset password", """
      Reiniciar a senha de uma conta desativada não a faz entrar, e oferecer o ato sugere
      que faz. É o mesmo par de estados que o achado do PO descreve, agora do outro lado.
      """
    end
  end
end
