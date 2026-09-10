defmodule TheBand.Tenants.EventosDeAcessoTest do
  @moduledoc """
  Os eventos de acesso — achado **H4**, 2026-09-09.

  ## O que este arquivo mede, e o que ele deliberadamente NÃO mede

  A **L69** desta base diz que defeito dentro de `Logger.info` é invisível a teste, porque
  o nível é configuração. Então a divisão aqui é a mesma do conserto:

  - **a decisão continua no retorno**, e é sobre ela que a maior parte deste arquivo
    afirma. `authenticate/2` devolve `{:error, :invalid_credentials}` e
    `{:error, {:throttled, s}}`; `disable_user/3` devolve `{:ok, _}` ou o motivo. Nada
    disso depende de log;
  - **o log é asserido em UM caso**, e só nele: o número de tentativas falhas apagadas
    pelo sucesso. Ali o log **é** a única evidência que existe — o campo é zerado no mesmo
    instante —, e não asserir seria deixar sem prova a linha que dá severidade ao achado.

  ## O ponto que dá a severidade

  `registrar_sucesso/1` grava `failed_attempts: 0`. Esse campo era o **único** rastro de
  tentativa falha, e é contador de estado, não histórico:

  > **Uma campanha de adivinhação de senha que dá certo apagava a própria evidência.**
  """
  use TheBand.DataCase, async: false

  import ExUnit.CaptureLog

  alias TheBand.Tenants

  # A razão é obrigatória desde o protótipo de 2026-09-10: o ato gravava quem e quando, e
  # nenhuma razão. As cláusulas vêm de `access.account_lifecycle`, na base de conhecimento.
  @razao_de_saida %{"reason" => "left_the_organisation"}
  @razao_de_volta %{"reason" => "returned_to_the_organisation"}

  @senha "senha-bem-comprida-123"

  setup do
    tenant = tenant_fixture()
    admin = user_fixture(tenant)
    {:ok, admin} = Tenants.set_password(tenant, admin.id, @senha)

    {:ok, alvo} =
      Tenants.create_user(tenant, %{
        "email" => "alvo-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    {:ok, alvo} = Tenants.set_password(tenant, alvo.id, @senha)
    %{tenant: tenant, admin: admin, alvo: alvo}
  end

  describe "o rastro que o sucesso apagava" do
    test "o número de tentativas falhas apagadas é registrado ANTES de as apagar", ctx do
      # DUAS tentativas erradas, e o número não é arbitrário: `@tentativas_livres` é 3, e
      # a terceira falha já faz a quarta tentativa esperar. Com três, o sucesso deste teste
      # vinha `{:error, {:throttled, 2}}` — e o teste mediria a espera, não o rastro.
      for _ <- 1..2 do
        {:error, :invalid_credentials} = Tenants.authenticate(ctx.alvo.email, "errada-comprida-1")
      end

      {:ok, antes} = Tenants.fetch_user(ctx.alvo.id)

      assert antes.failed_attempts == 2, """
      A guarda do cenário: as duas falhas foram de facto contadas. Sem isto, o teste
      abaixo mediria um sucesso sobre zero falhas — que é o caso normal, e não o que este
      arquivo existe para provar.
      """

      log = capture_log(fn -> {:ok, _} = Tenants.authenticate(ctx.alvo.email, @senha) end)

      assert log =~ "falhas_apagadas=2", """
      É a única evidência que sobra. `registrar_sucesso/1` zera `failed_attempts` no mesmo
      instante, e o campo é contador de estado — não histórico.

      Sem esta linha, uma campanha de adivinhação que dá certo apaga a própria evidência,
      e ninguém consegue responder depois se houve campanha.
      """

      {:ok, depois} = Tenants.fetch_user(ctx.alvo.id)

      assert depois.failed_attempts == 0, """
      E o comportamento NÃO mudou: o sucesso continua zerando o contador. O registro é
      acréscimo, e não substituição — se `AccessEvents` fosse removido inteiro, a
      plataforma se comportaria igual e perderia só a capacidade de responder
      "isto já aconteceu?".
      """
    end
  end

  describe "a recusa distingue o motivo NO LOG, e não na resposta" do
    test "a resposta é idêntica; o motivo interno difere", ctx do
      {:ok, _} = Tenants.disable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id, @razao_de_saida)

      log = capture_log(fn -> Tenants.authenticate(ctx.alvo.email, @senha) end)

      assert log =~ "motivo=:conta_desativada", """
      Na resposta HTTP a recusa é única (FR-002) — motivo distinto ali seria enumeração. É
      no log que ele serve, e é lá que ele está.
      """

      # E A ASSERÇÃO QUE IMPORTA, que não é sobre o log: a resposta continua indistinta.
      assert Tenants.authenticate(ctx.alvo.email, @senha) ==
               Tenants.authenticate(ctx.alvo.email, "outra-senha-comprida-9")
    end
  end

  describe "os atos administrativos" do
    test "desativar e reativar deixam registro com quem sofreu o ato", ctx do
      log =
        capture_log(fn ->
          {:ok, _} = Tenants.disable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id, @razao_de_saida)
          {:ok, _} = Tenants.enable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id, @razao_de_volta)
        end)

      assert log =~ "ato=:conta_desativada"
      assert log =~ "ato=:conta_reativada"

      assert log =~ ctx.alvo.id, """
      Sem quem sofreu o ato, o registro diz que "uma conta foi desativada" e não qual —
      inútil para reconstruir um incidente.
      """
    end
  end

  describe "as duas que existiam escritas e nunca eram chamadas" do
    # RECUSA DO PAPEL PRODUCT OWNER na avaliação da v0.7.0, e ela estava certa:
    # `painel_recusado/4` e `espera_acionada/3` tinham `@doc`, `@spec` e **zero call
    # sites**. É pior que a ausência — quem faz `grep` conclui que está registrado, e o
    # corpo do PR reforçava a leitura errada.
    #
    # Estes dois testes existem para que elas não voltem a ser código morto.

    test "a espera crescente é registrada quando dispara", ctx do
      # `@tentativas_livres` é 3: a quarta tentativa espera.
      for _ <- 1..3 do
        {:error, :invalid_credentials} = Tenants.authenticate(ctx.alvo.email, "errada-comprida-1")
      end

      log =
        capture_log(fn ->
          assert {:error, {:throttled, _}} = Tenants.authenticate(ctx.alvo.email, @senha)
        end)

      assert log =~ "espera acionada", """
      O `{:throttled, s}` morria no retorno. Quem investiga uma campanha precisa saber que
      a espera disparou, e quantas vezes — e o retorno só conta para quem estava a olhar
      naquele instante.
      """

      assert log =~ "segundos=", "sem os segundos, o evento não diz o tamanho da espera"
    end
  end

  describe "segredo nunca entra no log" do
    test "nem a senha, nem o token de sessão, nem a temporária", ctx do
      {:ok, temporaria} = Tenants.reset_password(ctx.tenant, ctx.alvo.id, ctx.admin.id)

      log =
        capture_log(fn ->
          Tenants.authenticate(ctx.alvo.email, @senha)
          Tenants.authenticate(ctx.alvo.email, temporaria)
        end)

      refute log =~ @senha, "a senha entrou no log"
      refute log =~ temporaria, "a senha temporária entrou no log"

      {:ok, recarregada} = Tenants.fetch_user(ctx.alvo.id)

      refute log =~ recarregada.session_token, """
      `redact: true` protege o `inspect/1`, e **não** uma interpolação escrita à mão. A
      proteção real é as funções de `AccessEvents` receberem identificadores e motivos —
      nunca credencial. Este teste mede a proteção real.
      """
    end
  end
end
