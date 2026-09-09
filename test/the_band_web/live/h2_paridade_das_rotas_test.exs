defmodule TheBandWeb.H2ParidadeDasRotasTest do
  @moduledoc """
  A paridade das rotas que servem **agregado por pessoa nomeada** — achado **H2**,
  item 3 do que o fecha.

  ## Por que este arquivo existe, e o que ele impede

  O H2 não foi uma tela esquecida: foi um **regime herdado por omissão**. A spec 023
  descreve o que vigorava antes — *"toda pessoa autenticada do tenant vê qualquer
  outra"* — e diz que vigorava **por omissão**: o roteador exigia `require_user` e nada
  além. As seções construídas depois herdaram a omissão sem ninguém decidir.

  Consertar as rotas de hoje não impede a de amanhã de herdar o mesmo. **O que impede é
  este teste**: ele enumera as rotas que servem ranking por pessoa nomeada e exige que
  **todas** respondam igual ao mesmo veredito.

  ## O que ele NÃO cobre, e está declarado

  As rotas de **atribuição no item** — quem abriu esta issue, quem revisou esta
  solicitação, quem tocou este arquivo — e o **diretório de pessoas** (`/people`).

  **E não é lacuna: é decisão.** A **FR-024 da spec 045**, decidida pela pessoa
  mantenedora em 2026-09-09, diz que o veredito cobre **agregado sobre a pessoa** e
  **não** cobre atribuição nem diretório. A autoria é parte do trabalho, e o diretório
  afirma que a pessoa existe.

  O **risco de agregação** fica aceito e declarado por aquela FR — quem acumula muitos
  itens reconstrói o agregado —, e o caminho dele é o achado **H4** (registro de acesso)
  com limite de taxa, e não esconder o autor.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures, only: [cenario_real: 1]

  alias TheBand.Changes.Commands, as: ChangeCommands
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.SPO.Schemas.PerformedProjectActivity
  alias TheBand.Repo
  alias TheBand.Tenants

  # AS ROTAS QUE SERVEM RANKING POR PESSOA NOMEADA.
  #
  # Acrescentar tela nova que ranqueie pessoa e **não** a pôr aqui é o que este teste
  # existe para tornar difícil: a lista é a declaração, e a asserção é a cobrança.
  @rotas_com_ranking [
    {"/work/verifications/people", "Who merged red"},
    {"/process", "Process"}
  ]

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)

    {:ok, alvo} =
      EO.upsert_person_from_source(tenant, %{
        login: "pessoa-do-ranking",
        # AS DUAS ROTAS RENDERIZAM IDENTIFICADORES DIFERENTES: `/process` mostra
        # `{p.name || p.login}` e o ranking das verificações mostra o login. Tentei um
        # fixture sem nome para unificar, e `Person` exige `name` — está certo em exigir.
        #
        # Então este arquivo afirma sobre **os dois**: o `refute` exige que **nenhum**
        # apareça, o que é mais forte que escolher um; e o `assert` da administração exige
        # que **ao menos um** apareça, o que é o que prova que o `refute` não é vazio.
        name: "Pessoa Do Ranking",
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        source_endpoint: "/users/pessoa-do-ranking",
        external_id: "U_ranking",
        collected_at: DateTime.utc_now(:second)
      })

    {:ok, estranha} =
      Tenants.create_user(tenant, %{
        "email" => "estranha-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    # POVOAR AS DUAS ROTAS, e é o que torna o `refute` deste arquivo significativo.
    #
    # Sem isto, "a conta estranha não vê o login" passaria por a lista estar **vazia** —
    # e passaria igual se o filtro não existisse. É a armadilha que o próprio documento
    # do H3 nomeia: *"sem isso, 'o suspenso não vê nada' passaria com a consulta quebrada
    # nos dois"*.

    # `/work/verifications/people`: uma integrada VERMELHA em nome da pessoa.
    {:ok, _} =
      ChangeCommands.record_change_request(tenant, %{
        observed_repository_id: cenario.observed_repository_id,
        number: 7777,
        title: "pr vermelho do ranking",
        state: "MERGED",
        author_login: alvo.login,
        author_person_id: alvo.id,
        merged_check_state: "FAILURE",
        merged_check_contexts: 2,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "PR_7777"
      })

    # `/process`: uma atividade executada em nome da pessoa.
    Repo.insert!(%PerformedProjectActivity{
      tenant_id: tenant.id,
      internal_id: "atividade-do-ranking-#{System.unique_integer([:positive])}",
      activity_type: "commit",
      # `subject_type` e `subject_id` são `NOT NULL` no esquema: a atividade é sempre
      # **sobre** algo, e o schema recusa a que não diz sobre o quê. A primeira versão
      # deste setup os omitia e o Postgres reprovou — o que é o comportamento certo.
      subject_type: "collected_commit",
      subject_id: Ecto.UUID.generate(),
      performer_id: alvo.id,
      performer_login: alvo.login,
      occurred_at: DateTime.utc_now(:second),
      source_system: "github",
      source_instance: "https://github.com"
    })

    %{
      conn: conn,
      tenant: tenant,
      admin: admin,
      alvo: alvo,
      estranha: estranha,
      repo_id: cenario.observed_repository_id
    }
  end

  test "a guarda: a conta estranha é de facto recusada pelo veredito", ctx do
    assert {:nao, _} = Tenants.pode_ver(ctx.tenant, ctx.estranha, ctx.alvo.id), """
    Sem esta asserção, todo `refute` deste arquivo mediria o caminho PERMITIDO e passaria
    verde afirmando o contrário.
    """
  end

  test "toda rota com ranking esconde o login de quem a conta não alcança", ctx do
    conn = log_in(ctx.conn, ctx.estranha)

    for {rota, marca} <- @rotas_com_ranking do
      {:ok, _live, html} = live(conn, rota)

      assert html =~ marca, """
      A rota #{rota} tem de continuar abrindo — o que muda é o conteúdo, e não o acesso.
      Fechar a página faria quem tem escopo de uma equipe perder a leitura da própria.
      """

      for identificador <- [ctx.alvo.login, ctx.alvo.name] do
        refute html =~ identificador, """
        #{rota} mostra o login de `#{ctx.alvo.login}` a uma conta que o veredito recusa.

        É o achado H2: o regime da FR-012 vigorava por omissão, e cada seção nova o
        herdava. Esta rota está na lista `@rotas_com_ranking` deste arquivo, então ela
        **declarou** servir ranking por pessoa — e ranking por pessoa segue o veredito.

        O identificador que vazou: `#{identificador}`.
        """
      end
    end
  end

  test "a administração VÊ o login em todas — e é o que prova que o refute acima não é vazio",
       ctx do
    conn = log_in(ctx.conn, ctx.admin)

    for {rota, _marca} <- @rotas_com_ranking do
      {:ok, _live, html} = live(conn, rota)

      assert html =~ ctx.alvo.login or html =~ ctx.alvo.name, """
      A administração alcança tudo no tenant (FR-022, emendada em 2026-09-09), e a
      pessoa foi POVOADA nesta rota pelo setup.

      Este `assert` tem duas funções, e a segunda é a que importa:

      1. prova que o conserto do H2 **não fechou** a leitura de quem a decisão diz que
         pode ver — a suíte ficaria verde afirmando segurança onde há tela trancada;
      2. prova que o `refute` do teste anterior **não é vazio**. Se a pessoa não
         aparecesse aqui, ela também não apareceria lá — e o `refute` passaria por a
         lista estar vazia, não por o filtro funcionar.

      A primeira versão deste teste asseria `is_binary(html)`, que é verdadeiro para
      qualquer resposta. Não media nada, e passava.
      """
    end
  end
end
