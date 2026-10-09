defmodule TheBand.Telemetria.TaxonomiaTest do
  @moduledoc """
  A taxonomia da jornada, lida da base de conhecimento — spec 074, T007 (a leitura do YAML).

  O que está escrito aqui é a tabela *A régua* da spec, e não uma cópia do YAML: se o YAML
  mudar sem a spec, este teste reprova, e a diferença aparece para quem revisa.
  """
  use ExUnit.Case, async: true

  alias TheBand.Telemetria.Taxonomia

  @motivos %{
    "abrir_a_entrada" => [],
    "entrar_com_senha" => ~w(senha_errada identificador_nao_resolveu conta_sem_senha
                             conta_desativada organizacao_suspensa em_espera
                             limite_por_origem),
    "sair" => ~w(sessao_ja_nao_existia),
    "sessao_derrubada" => ~w(malformado inexistente resumo_errado encerrada vencida epoca_velha
                             organizacao_suspensa conta_desativada),
    "definir_a_senha" => ~w(confirmacao_diferente recusada_pela_regra fora_do_fluxo),
    "trocar_a_senha" => ~w(senha_atual_nao_confere recusada_pela_regra em_espera
                           tentativas_esgotadas)
  }

  test "os seis passos da régua, e nenhum outro" do
    assert Enum.sort(Taxonomia.passos()) == Enum.sort(Map.keys(@motivos))
  end

  test "cada passo devolve exatamente os motivos da régua" do
    for {passo, motivos} <- @motivos do
      assert Enum.sort(Taxonomia.motivos(passo)) == Enum.sort(motivos), "motivos de #{passo}"
    end
  end

  test "abandonou é declarado em abrir_a_entrada, e fica FORA do que a aplicação pode emitir" do
    assert "abandonou" in Taxonomia.desfechos("abrir_a_entrada")

    for {_passo, %{desfechos: desfechos}} <- Taxonomia.regras_por_passo() do
      refute "abandonou" in desfechos
    end
  end

  test "sessao_derrubada só falha; os outros passos com motivo concluem ou falham" do
    regras = Taxonomia.regras_por_passo()
    assert regras["sessao_derrubada"].desfechos == ["falhou"]

    for passo <- ~w(entrar_com_senha sair definir_a_senha trocar_a_senha) do
      assert Enum.sort(regras[passo].desfechos) == ["concluiu", "falhou"], passo
    end
  end

  test "passo desconhecido não tem motivo nem desfecho" do
    assert Taxonomia.motivos("entrar_pelo_github") == []
    assert Taxonomia.desfechos("entrar_pelo_github") == []
  end
end

defmodule TheBand.Telemetria.TaxonomiaGateTest do
  @moduledoc """
  O gate da taxonomia — spec 074, T019; FR-002, FR-007; research R8.

  Compara o que o código **emite** com o que o YAML **declara**, pelo comportamento e não pelo
  texto-fonte: cada caminho de cada passo é percorrido como a pessoa o percorre, e o que chega
  ao destino, **depois do filtro**, é coletado. Três reprovações:

  1. **motivo emitido e não declarado**: o filtro apaga `failure.reason` fora da lista do passo
     (e conta o descarte). Um span `falhou` sem `failure.reason` é a marca dele;
  2. **motivo declarado que nenhum caminho produz**: a diferença entre o YAML e o coletado;
  3. **`abandonou` emitido pela aplicação**: é derivado na consulta (research R6). O filtro o
     apaga de `outcome`; um span sem `outcome` é a marca.
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query, only: [from: 2]

  alias TheBand.Spans
  alias TheBand.Telemetria.Contadores
  alias TheBand.Telemetria.Taxonomia
  alias TheBand.Tenants
  alias TheBand.Tenants.Schemas.UserSession

  @senha "senha-do-gate-comprida-1"

  setup do
    :ok = Spans.ligar()
    {tenant, admin} = tenant_with_admin()
    Spans.recebidos(0)
    %{tenant: tenant, admin: admin}
  end

  defp conta(tenant, senha \\ @senha) do
    {:ok, u} =
      Tenants.create_user(tenant, %{
        "email" => "gate-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    if senha, do: elem(Tenants.set_password(tenant, u.id, senha), 1), else: u
  end

  defp entrar(conn \\ build_conn(), email, senha),
    do: post(conn, ~p"/session", %{"identifier" => email, "password" => senha})

  defp cookie(conn), do: Map.take(get_session(conn), ["session_id", "session_secret"])
  defp com(cookie), do: init_test_session(build_conn(), cookie)

  defp sessao(tenant) do
    u = conta(tenant)
    {u, u |> then(&entrar(&1.email, @senha)) |> cookie()}
  end

  defp mudar(schema, id, campos),
    do: {1, _} = Repo.update_all(from(r in schema, where: r.id == ^id), set: campos)

  defp percorrer(ctx) do
    t = ctx.tenant

    # abrir_a_entrada
    {:ok, _, _} = build_conn() |> get(~p"/sign-in") |> live()

    # entrar_com_senha: concluiu e os sete motivos
    u = conta(t)
    entrar(u.email, @senha)
    entrar(u.email, "errada-e-comprida-1")
    entrar("ninguem-#{System.unique_integer([:positive])}@example.test", @senha)
    entrar(conta(t, nil).email, @senha)
    d = conta(t)
    mudar(Tenants.User, d.id, disabled_at: DateTime.utc_now(:second))
    entrar(d.email, @senha)
    e = conta(t)
    for _ <- 1..4, do: entrar(e.email, "errada-e-comprida-1")
    {outra, _} = tenant_with_admin()
    s = conta(outra)
    mudar(Tenants.Tenant, outra.id, status: "suspended")
    entrar(s.email, @senha)

    # limite_por_origem (spec 077): onze falhas da MESMA origem; a décima primeira é recusada
    # pelo limite, antes de resolver o identificador.
    mesma = build_conn()

    for _ <- 1..11,
        do: entrar(%{build_conn() | remote_ip: mesma.remote_ip}, "ninguem@example.test", @senha)

    # sair: concluiu, e o cookie velho
    {_, c} = sessao(t)
    c |> com() |> delete(~p"/session")
    c |> com() |> delete(~p"/session")

    # sessao_derrubada: os outros sete (encerrada saiu acima)
    {_, c} = sessao(t)
    %{c | "session_id" => "nao-e-uuid"} |> com() |> get(~p"/version")
    %{c | "session_id" => Ecto.UUID.generate()} |> com() |> get(~p"/version")
    %{c | "session_secret" => Base.url_encode64("x")} |> com() |> get(~p"/version")
    {_, c} = sessao(t)
    mudar(UserSession, c["session_id"], inserted_at: DateTime.add(DateTime.utc_now(), -8, :day))
    c |> com() |> get(~p"/version")
    {u2, c} = sessao(t)

    {1, _} =
      Repo.update_all(from(x in Tenants.User, where: x.id == ^u2.id), inc: [password_epoch: 1])

    c |> com() |> get(~p"/version")
    {u3, c} = sessao(t)
    mudar(Tenants.User, u3.id, disabled_at: DateTime.utc_now(:second))
    c |> com() |> get(~p"/version")
    {outra2, _} = tenant_with_admin()
    {_, c} = sessao(outra2)
    mudar(Tenants.Tenant, outra2.id, status: "suspended")
    c |> com() |> get(~p"/version")

    # definir_a_senha: concluiu, confirmacao_diferente, recusada_pela_regra, fora_do_fluxo
    tmp = conta(t)
    {:ok, temporaria} = Tenants.reset_password(t, tmp.id, ctx.admin.id)
    dentro = entrar(tmp.email, temporaria)

    definir = fn conn, a, b ->
      post(recycle(conn), ~p"/set-password", %{"password" => a, "password_confirmation" => b})
    end

    definir.(dentro, "definitiva-comprida-1", "outra-coisa-comprida-1")
    definir.(dentro, "curta", "curta")
    definir.(build_conn(), "definitiva-comprida-1", "definitiva-comprida-1")
    definir.(dentro, "definitiva-comprida-1", "definitiva-comprida-1")

    # trocar_a_senha: concluiu, senha_atual_nao_confere, recusada_pela_regra
    tr = conta(t)
    logado = log_in(build_conn(), tr)

    trocar = fn atual, nova ->
      post(logado, ~p"/profile/password", %{"current" => atual, "password" => nova})
    end

    trocar.("atual-errada-e-longa", "novissima-comprida-1")
    trocar.(@senha, "curta")
    trocar.(@senha, "novissima-comprida-1")

    # trocar_a_senha: tentativas_esgotadas e em_espera (#1409). Três erradas seguidas numa sessão
    # esgotam as livres e a encerram; a seguinte, noutra sessão, cai na espera.
    esg = conta(t)
    sessao_esg = log_in(build_conn(), esg)

    for _ <- 1..3,
        do:
          post(sessao_esg, ~p"/profile/password", %{
            "current" => "errada-e-longa-1",
            "password" => "novissima-comprida-1"
          })

    post(log_in(build_conn(), esg), ~p"/profile/password", %{
      "current" => @senha,
      "password" => "novissima-comprida-1"
    })

    Spans.recebidos()
  end

  test "o que o código emite é exatamente o que o YAML declara", ctx do
    descartados_antes = Contadores.valor(:atributo_descartado, "failure.reason")
    spans = percorrer(ctx)
    atributos = Enum.map(spans, &Spans.atributos/1)

    sem_outcome = Enum.reject(atributos, &Map.has_key?(&1, "outcome"))

    assert sem_outcome == [],
           "desfecho fora da lista (abandonou?) emitido: #{inspect(sem_outcome)}"

    falhou_sem_motivo =
      Enum.filter(
        atributos,
        &(&1["outcome"] == "falhou" and not Map.has_key?(&1, "failure.reason"))
      )

    assert falhou_sem_motivo == [],
           "motivo emitido e não declarado (o filtro o apagou): #{inspect(falhou_sem_motivo)}"

    assert Contadores.valor(:atributo_descartado, "failure.reason") == descartados_antes

    emitidos =
      for a <- atributos,
          a["outcome"] == "falhou",
          into: MapSet.new(),
          do: {a["journey.step"], a["failure.reason"]}

    declarados =
      for passo <- Taxonomia.passos(),
          motivo <- Taxonomia.motivos(passo),
          into: MapSet.new(),
          do: {passo, motivo}

    nunca_emitidos = declarados |> MapSet.difference(emitidos) |> Enum.sort()
    assert nunca_emitidos == [], "declarado e nunca emitido: #{inspect(nunca_emitidos)}"

    nao_declarados = emitidos |> MapSet.difference(declarados) |> Enum.sort()
    assert nao_declarados == [], "emitido e não declarado: #{inspect(nao_declarados)}"

    concluidos =
      for a <- atributos, a["outcome"] == "concluiu", into: MapSet.new(), do: a["journey.step"]

    for passo <- Taxonomia.passos(), "concluiu" in Taxonomia.desfechos(passo) do
      assert passo in concluidos, "#{passo} nunca concluiu nos caminhos percorridos"
    end
  end
end
