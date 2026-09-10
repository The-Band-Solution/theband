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

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants
  alias TheBand.Tenants.Access
  alias TheBand.Tenants.User

  @senha "senha-bem-comprida-123"

  # A razão é obrigatória desde o protótipo de 2026-09-10: o ato gravava quem e quando, e
  # nenhuma razão. As cláusulas vêm de `access.account_lifecycle`, na base de conhecimento.
  @razao_de_saida %{"reason" => "left_the_organisation"}
  @razao_de_volta %{"reason" => "returned_to_the_organisation"}

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

      {:ok, desativada} =
        Tenants.disable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id, @razao_de_saida)

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
      {:ok, _} = Tenants.disable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id, @razao_de_saida)
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

      {:ok, _} = Tenants.disable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id, @razao_de_saida)

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
      {:ok, _} = Tenants.disable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id, @razao_de_saida)

      assert redirected_to(get(conn, ~p"/profile")) == ~p"/sign-in"
    end
  end

  describe "as recusas do ato" do
    test "não se desativa a própria conta", ctx do
      assert {:error, :nao_pode_desativar_a_si} =
               Tenants.disable_user(ctx.tenant, ctx.admin.id, ctx.admin.id, @razao_de_saida),
             """
             Desativar-se a si é ficar de fora sem ter a quem pedir de volta — e num tenant com
             uma administração só, isso tranca a organização inteira.
             """
    end

    test "não desativa conta de OUTRO tenant", ctx do
      {outro, admin_de_fora} = tenant_with_admin()

      assert {:error, :not_found} =
               Tenants.disable_user(ctx.tenant, admin_de_fora.id, ctx.admin.id, @razao_de_saida),
             """
             O isolamento por tenant é o princípio V, e vale para os atos e não só para as
             leituras.
             """

      assert {:error, :not_found} =
               Tenants.disable_user(outro, ctx.alvo.id, admin_de_fora.id, @razao_de_saida)
    end

    test "desativar duas vezes é recusado com motivo próprio", ctx do
      {:ok, _} = Tenants.disable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id, @razao_de_saida)

      assert {:error, :ja_desativada} =
               Tenants.disable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id, @razao_de_saida)
    end
  end

  describe "reativar" do
    test "devolve o acesso, e NÃO devolve a senha", ctx do
      {:ok, _} = Tenants.disable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id, @razao_de_saida)

      {:ok, reativada} =
        Tenants.enable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id, @razao_de_volta)

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
      {:ok, _} = Tenants.disable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id, @razao_de_saida)
      {:ok, _} = Tenants.enable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id, @razao_de_volta)

      assert {:error, :invalid_credentials} = Tenants.authenticate(ctx.alvo.email, @senha), """
      Reativar é dizer "esta conta entra de novo", e não "esta conta lembra a senha".
      Juntar as duas coisas num ato só faria quem reativa devolver acesso com uma
      credencial que ele não escolheu.
      """
    end

    test "reativar conta ativa é recusado", ctx do
      assert {:error, :ja_ativa} =
               Tenants.enable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id, @razao_de_volta)
    end
  end

  describe "a tela de contas" do
    test "as duas colunas existem, e o desligamento não usa o texto da temporária", ctx do
      {:ok, _temporaria} = Tenants.reset_password(ctx.tenant, ctx.alvo.id, ctx.admin.id)

      {:ok, live, html} = live(log_in(ctx.conn, ctx.admin), ~p"/accounts")

      assert html =~ "Sign-in credential" and html =~ ">Account<", """
      Duas colunas para dois fatos: `Account` responde *pode entrar?*, `Sign-in credential`
      responde *entraria com o quê?*. Eram uma célula só, e uma célula só é o que fez um
      desligamento parecer um primeiro dia.
      """

      assert html =~ "temporary · from a reset", """
      A guarda do cenário: a temporária de um REINÍCIO se distingue em palavras da de
      criação. Sem esta asserção, a asserção de baixo poderia passar por a coluna estar
      vazia.
      """

      html = desativar_pela_tela(live, ctx.alvo.id)
      linha = linha_de(html, ctx.alvo.email)

      assert linha =~ "disabled", "o estado da conta aparece na coluna da conta"

      # O ACHADO: os dois estados deixam de ser o mesmo texto. E a credencial continua
      # dizendo qual é — desativar não a apaga.
      refute linha =~ "temporary · from creation", """
      Era o achado: a conta desligada aparecia como `temporária pendente`, igual à
      recém-criada — e o ato de rotina para a segunda REATIVAVA a primeira.
      """

      assert linha =~ "temporary · from a reset", """
      A credencial fica, e a coluna dela continua dizendo qual é. O que muda é a resposta a
      *pode entrar?* — e é por isso que são duas colunas.
      """
    end

    test "desativar EXIGE razão, e a razão fica escrita na linha", ctx do
      {:ok, live, _html} = live(log_in(ctx.conn, ctx.admin), ~p"/accounts")

      formulario = render_click(live, "abrir_desativacao", %{"id" => ctx.alvo.id})

      assert formulario =~ "left_the_organisation" and formulario =~ "suspected_compromise", """
      As cláusulas vêm de `access.account_lifecycle`, na base de conhecimento — e não de
      uma lista escrita no template.
      """

      html =
        desativar_pela_tela(live, ctx.alvo.id, "suspected_compromise", "dois países numa hora")

      linha = linha_de(html, ctx.alvo.email)
      assert linha =~ "Suspected compromise", "a razão declarada aparece com o rótulo da base"
      assert html =~ "dois países numa hora", "e a nota escrita aparece no histórico"
    end

    test "a nota é obrigatória para suspeita de comprometimento", ctx do
      {:ok, live, _html} = live(log_in(ctx.conn, ctx.admin), ~p"/accounts")
      render_click(live, "abrir_desativacao", %{"id" => ctx.alvo.id})

      html =
        render_submit(live, "desativar", %{"reason" => "suspected_compromise", "note" => "   "})

      assert html =~ "obrigat" or html =~ "required", """
      Espaço em branco não é nota. Sem a normalização, `validate_required` aceitaria `"   "`
      e a obrigatoriedade seria decorativa.
      """

      alvo = Enum.find(Tenants.list_users(ctx.tenant), &(&1.id == ctx.alvo.id))

      assert alvo.disabled_at == nil,
             "e a conta NÃO foi desativada: a recusa é recusa, não aviso"
    end

    test "a recusa FICA na tela: reiniciar senha na conta desativada", ctx do
      {:ok, live, _html} = live(log_in(ctx.conn, ctx.admin), ~p"/accounts")
      html = desativar_pela_tela(live, ctx.alvo.id)
      linha = linha_de(html, ctx.alvo.email)

      assert linha =~ "Reset password", """
      O botão FICA — inerte, com a razão ao lado. Botão que desaparece faz quem procura
      concluir que a plataforma não sabe fazer aquilo, e foi o que produziu o desligamento
      improvisado. A versão anterior desta tela o escondia, e o protótipo recusou.
      """

      assert linha =~ "Reset is unavailable while the account is disabled", """
      A razão é a metade que importa: nomeia a ORDEM — reativar primeiro, e reativar não
      devolve a senha.
      """

      assert linha =~ "disabled", "e a linha oferece a reativação no lugar"
      assert linha =~ "Reactivate"
    end

    test "a recusa FICA na tela: desativar a própria conta", ctx do
      {:ok, _live, html} = live(log_in(ctx.conn, ctx.admin), ~p"/accounts")
      minha_linha = linha_de(html, ctx.admin.email)

      assert minha_linha =~ "Disable", """
      A tela esconder era ausência muda. O botão fica, inerte, e diz a razão da plataforma —
      que também recusa, e há teste disso acima.
      """

      assert minha_linha =~ "ask another administrator", """
      E a razão nomeia o remédio: pedir a outra pessoa que administra. A recusa sem remédio
      só informa que não deu.
      """
    end
  end

  describe "o episódio, na tela" do
    test "reativar fecha o episódio e NÃO apaga a desativação", ctx do
      {:ok, live, _html} = live(log_in(ctx.conn, ctx.admin), ~p"/accounts")
      desativar_pela_tela(live, ctx.alvo.id, "left_the_organisation", "último dia foi 8 Sep")

      render_click(live, "abrir_reativacao", %{"id" => ctx.alvo.id})
      html = render_submit(live, "reativar", %{"reason" => "returned_to_the_organisation"})

      assert html =~ "access history", "a linha do histórico existe"

      assert html =~ "Left the organisation", """
      A DESATIVAÇÃO CONTINUA NO REGISTRO. Era o defeito: `reativar_changeset/1` fazia
      `disabled_at: nil, disabled_by_user_id: nil` — um `delete` escrito como `update`, e
      depois dele ninguém tinha desativado aquela conta nunca.
      """

      assert html =~ "Returned to the organisation", "e o fechamento também tem razão"
      assert html =~ "último dia foi 8 Sep", "e a nota da abertura sobrevive ao fechamento"
    end

    test "o equívoco é dito, e para de contar como desligamento", ctx do
      {:ok, live, _html} = live(log_in(ctx.conn, ctx.admin), ~p"/accounts")
      desativar_pela_tela(live, ctx.alvo.id)

      render_click(live, "abrir_reativacao", %{"id" => ctx.alvo.id})
      html = render_submit(live, "reativar", %{"reason" => "disabled_by_mistake"})

      assert html =~ "mistake", "o episódio é MARCADO equívoco"
      assert html =~ "not counted as a shutdown", "e a tela diz o que a marca faz"

      assert html =~ "Left the organisation", """
      E continua visível. Equívoco é dito, não removido — a forma de
      `TeamMembership.invalidated_at`.
      """
    end

    test "a investigação encerrada só é oferecida contra uma suspeita", ctx do
      {:ok, live, _html} = live(log_in(ctx.conn, ctx.admin), ~p"/accounts")
      desativar_pela_tela(live, ctx.alvo.id, "left_the_organisation")

      formulario = render_click(live, "abrir_reativacao", %{"id" => ctx.alvo.id})

      refute formulario =~ "investigation_closed_no_compromise", """
      Oferecê-la sempre faria a plataforma sugerir que houve investigação onde não houve.
      """

      render_click(live, "abrir_reativacao", %{"id" => ctx.alvo.id})
      render_submit(live, "reativar", %{"reason" => "returned_to_the_organisation"})

      desativar_pela_tela(
        live,
        ctx.alvo.id,
        "suspected_compromise",
        "três entradas de dois países"
      )

      formulario = render_click(live, "abrir_reativacao", %{"id" => ctx.alvo.id})

      assert formulario =~ "investigation_closed_no_compromise", """
      Contra a suspeita, ela é a resposta àquela razão, e pertence ao lado dela.
      """
    end

    test "duas desativações caem no registro, e o par de colunas cabia uma", ctx do
      {:ok, live, _html} = live(log_in(ctx.conn, ctx.admin), ~p"/accounts")

      desativar_pela_tela(live, ctx.alvo.id, "suspected_compromise", "o primeiro episódio")
      render_click(live, "abrir_reativacao", %{"id" => ctx.alvo.id})
      render_submit(live, "reativar", %{"reason" => "investigation_closed_no_compromise"})

      desativar_pela_tela(live, ctx.alvo.id, "left_the_organisation", "o segundo episódio")

      resumo =
        Tenants.historico_de_acesso(ctx.tenant, [ctx.alvo.id])
        |> Map.fetch!(ctx.alvo.id)

      assert resumo.aberto.disable_reason == "left_the_organisation"
      assert resumo.ultimo_fechado.disable_reason == "suspected_compromise"

      assert resumo.desligamentos == 2, """
      Os dois contam: nenhum foi equívoco. Em `users.disabled_at` a primeira teria sido
      SOBRESCRITA pela segunda, e a contagem não teria de onde sair.
      """
    end
  end

  describe "o que desativar NÃO toca" do
    setup ctx do
      pessoa = pessoa_observada(ctx.tenant, "alvo#{System.unique_integer([:positive])}")
      ligada = elo_de_identidade(ctx.tenant, ctx.alvo, pessoa)

      {:ok, _} =
        Access.grant(
          ctx.tenant,
          ctx.alvo.id,
          :organization,
          organization_fixture(ctx.tenant).id,
          ctx.admin
        )

      Map.merge(ctx, %{pessoa: pessoa, alvo: ligada})
    end

    test "a pessoa, o elo e os escopos ficam — e os escopos ficam INERTES", ctx do
      antes = %{
        pessoas: length(EO.list_people(ctx.tenant)),
        escopos: Tenants.concessoes_vigentes_por_conta(ctx.tenant, [ctx.alvo.id])
      }

      assert antes.pessoas > 0 and antes.escopos[ctx.alvo.id] == 1, """
      A guarda do cenário: há pessoa coletada e há UMA concessão vigente ANTES. Sem esta
      asserção, as comparações abaixo passariam contra zero — o verde falso que a casa
      chama de sucesso silencioso.
      """

      {:ok, _} = Tenants.disable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id, @razao_de_saida)

      depois = %{
        pessoas: length(EO.list_people(ctx.tenant)),
        escopos: Tenants.concessoes_vigentes_por_conta(ctx.tenant, [ctx.alvo.id])
      }

      assert depois.pessoas == antes.pessoas, """
      O ROSTER NÃO MUDA. Desativar uma conta é afirmação sobre entrar, e não sobre o
      passado: quem trabalhou aqui em julho continua contando em julho.
      """

      assert depois.escopos == antes.escopos, """
      OS ESCOPOS FICAM, e ficam INERTES — nada foi revogado. É o que faz a reativação
      devolver exatamente o que havia, em vez de adivinhar o que restaurar. Juntar as duas
      coisas seria o erro que a FR-012f já separou.
      """

      recarregada = Enum.find(Tenants.list_users(ctx.tenant), &(&1.id == ctx.alvo.id))

      assert recarregada.person_id == ctx.pessoa.id and is_nil(recarregada.person_revoked_at),
             "O ELO FICA: a conta continua sendo aquela pessoa no registro."

      assert recarregada.password_hash == ctx.alvo.password_hash, """
      A SENHA NÃO MUDA. Desativar e reiniciar são decisões diferentes, e juntá-las num ato
      só é exatamente o desligamento improvisado que esta feature existe para substituir.
      """
    end

    test "revogar o elo NÃO é o único ato oferecido a quem desliga", ctx do
      {:ok, _live, html} = live(log_in(ctx.conn, ctx.admin), ~p"/accounts")

      assert html =~ "Removing someone&#39;s access" or html =~ "Removing someone's access", """
      O procedimento está NA TELA, e não só em documento: `desligar-alguem.md` existe
      porque o ato que funcionava não estava escrito, e quem administra faz o que a
      interface oferece.
      """

      assert html =~ "Disable account", "o ato que desliga é oferecido, e nomeado"

      assert html =~ "Does not remove access", """
      E o texto do *revoke* diz que ele NÃO remove acesso — a terceira recusa do Product
      Owner. O H3 mediu: com o elo revogado, entrar por e-mail continua funcionando e as
      telas da organização continuam abrindo.
      """

      linha = linha_de(html, ctx.alvo.email)

      assert linha =~ "Disable", """
      O teste que REPROVA se revogar o elo voltar a ser o único ato na linha de quem
      desliga. Era o estado anterior à v0.7.0, e é o que produziu o desligamento por
      reinício de senha.
      """
    end
  end

  defp pessoa_observada(tenant, login) do
    {:ok, pessoa} =
      EO.upsert_person_from_source(tenant, %{
        login: login,
        name: String.capitalize(login),
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "U_#{login}",
        collected_at: DateTime.utc_now(:second)
      })

    pessoa
  end

  # ── O caminho da tela, num lugar só ──
  #
  # Abrir o formulário e submeter, e não um `render_click("desativar")`: o ato passou a
  # exigir razão, e um atalho no teste testaria um caminho que a tela não tem.
  defp desativar_pela_tela(live, user_id, reason \\ "left_the_organisation", note \\ nil) do
    render_click(live, "abrir_desativacao", %{"id" => user_id})
    render_submit(live, "desativar", %{"reason" => reason, "note" => note || ""})
  end

  # A linha DA TABELA, e não a primeira ocorrência do e-mail no documento: o menu do
  # cabeçalho também mostra o e-mail de quem está logada, e partir dali devolvia o topo da
  # página inteira. A asserção passava por acidente ou falhava por acidente — as duas
  # coisas piores que falhar por razão.
  defp linha_de(html, email) do
    html
    |> String.split("<tr")
    # O primeiro pedaço é TUDO o que vem antes da primeira linha — cabeçalho, menu e as
    # seções acima da tabela. É onde o e-mail de quem está logada aparece no menu, e
    # encontrá-lo ali devolvia a página inteira: a asserção de `Disable` passava pelo
    # cartão *Disable account*, e a da razão falhava por a linha nunca ter sido lida.
    |> Enum.drop(1)
    |> Enum.find(&String.contains?(&1, email))
    |> case do
      nil -> flunk("nenhuma linha da tabela contém #{email}")
      linha -> linha
    end
  end
end
