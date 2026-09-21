defmodule TheBandWeb.Api.V1.PersonDetailTest do
  @moduledoc """
  `GET /api/v1/people/:id` — uma pessoa, com o que a tela dela mostra.

  ## O que este arquivo existe para impedir

  **Que a API tenha alcance diferente da tela.** A listagem não filtra por `Access` porque
  a tela `/people` não filtra; o detalhe filtra porque a tela `/people/:id` filtra. Igualar
  as duas — nos dois sentidos — alargaria ou estreitaria o alcance pela porta do transporte,
  e alcance é decisão da plataforma.

  **Que a recusa aconteça sem ficar escrita.** A FR-024 da spec 045 aceita o risco de
  agregação e aponta o registro de acesso como o caminho para percebê-lo. Uma rota de API
  que recusasse em silêncio abriria esse caminho com MENOS atrito que a tela: um laço sobre
  a listagem percorre o tenant inteiro sem deixar rastro.

  **Que as medidas sejam calculadas para quem não pode vê-las.** Calcular e depois esconder
  é fazer o trabalho do vazamento com o mesmo custo — e o dado passa a existir em memória.
  """
  use TheBandWeb.ConnCase, async: false

  import ExUnit.CaptureLog

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()

    {:ok, pessoa} =
      EO.upsert_person_from_source(tenant, %{
        login: "alvo",
        name: "Pessoa Alvo",
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "U_alvo",
        collected_at: DateTime.utc_now(:second)
      })

    %{conn: conn, tenant: tenant, admin: admin, pessoa: pessoa}
  end

  # O alcance do token é o de quem o CRIOU. Não há identidade de API separada: quem integra
  # recebe o que veria na tela, nem mais nem menos.
  defp com_token(conn, tenant, dono, ator \\ nil) do
    {:ok, _t, valor} =
      Tenants.create_api_token(tenant, dono, %{label: "teste"}, ator || dono)

    conn
    |> Plug.Conn.put_req_header("authorization", "Bearer " <> valor)
    |> Plug.Conn.put_req_header("accept", "application/json")
  end

  defp membro(tenant) do
    {:ok, u} =
      Tenants.create_user(tenant, %{
        "email" => "membro-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    u
  end

  describe "o corpo espelha a tela" do
    setup ctx do
      conn = com_token(ctx.conn, ctx.tenant, ctx.admin)
      %{corpo: conn |> get(~p"/api/v1/people/#{ctx.pessoa.id}") |> json_response(200)}
    end

    test "as seções da tela estão todas no corpo", %{corpo: corpo} do
      d = corpo["data"]

      for secao <- ~w(provenance organizations teams roles account profile access work) do
        assert Map.has_key?(d, secao), "falta a seção *#{secao}*, que a tela mostra"
      end
    end

    test "a procedência traz o que a seção *Where this came from* mostra", %{corpo: corpo} do
      p = corpo["data"]["provenance"]

      assert p["source_system"] == "github"
      assert p["source_instance"] == "https://github.com"
      assert p["external_id"] == "U_alvo"
      assert p["first_observed_at"]
      assert Map.has_key?(p, "last_observed_at")
      assert Map.has_key?(p, "no_longer_observed_at")
    end

    test "as duas afirmações sobre organização vêm SEPARADAS, e com a razão junto", %{
      corpo: corpo
    } do
      o = corpo["data"]["organizations"]

      assert Map.has_key?(o, "by_membership"), "*is a member of* é uma afirmação"
      assert Map.has_key?(o, "by_work"), "*worked at* é outra"
      refute Map.has_key?(o, "organizations"), "não pode haver uma lista só, somando as duas"

      assert o["note"] =~ "never summed",
             "sem a nota, quem lê o corpo cru soma as duas e afirma o que ninguém afirmou"
    end

    test "papel sem declaração traz a RAZÃO, e não uma lista muda", %{corpo: corpo} do
      assert corpo["data"]["roles"] == []

      assert corpo["data"]["roles_note"] =~ "nobody declared",
             "lista vazia sem razão leria como *esta pessoa não tem papel*"
    end

    test "perfil ausente traz a razão, e diz que quando existe é DERIVADO", %{corpo: corpo} do
      assert corpo["data"]["profile"] == nil
      assert corpo["data"]["profile_note"] =~ "derived"
    end

    test "a cobertura do elo de conta vem com os dois lados", %{corpo: corpo} do
      c = corpo["data"]["account"]["link_coverage"]

      assert is_integer(c["accounts"]) and is_integer(c["declared"])

      assert c["declared"] <= c["accounts"],
             "declaradas não pode passar do total de contas — o denominador é o total"
    end
  end

  describe "o veredito de acesso decide se o painel existe" do
    test "quem alcança recebe o painel, e `reason` é nulo", ctx do
      corpo =
        ctx.conn
        |> com_token(ctx.tenant, ctx.admin)
        |> get(~p"/api/v1/people/#{ctx.pessoa.id}")
        |> json_response(200)

      assert corpo["data"]["access"]["can_see_work"] == true
      assert corpo["data"]["access"]["reason"] == nil
      assert is_map(corpo["data"]["work"])
    end

    test "quem não alcança recebe `work: null` e o MOTIVO", ctx do
      corpo =
        ctx.conn
        |> com_token(ctx.tenant, membro(ctx.tenant), ctx.admin)
        |> get(~p"/api/v1/people/#{ctx.pessoa.id}")
        |> json_response(200)

      assert corpo["data"]["access"]["can_see_work"] == false

      assert corpo["data"]["work"] == nil,
             "painel vazio e painel ausente são coisas diferentes: `null` diz que não foi dado"

      assert corpo["data"]["access"]["reason"],
             "o motivo não é descartável — *não declararam quem você é* e *ninguém foi " <>
               "declarado líder* têm remédios diferentes"
    end

    test "o resto da pessoa CONTINUA vindo — o veredito protege o painel, não a identidade",
         ctx do
      corpo =
        ctx.conn
        |> com_token(ctx.tenant, membro(ctx.tenant), ctx.admin)
        |> get(~p"/api/v1/people/#{ctx.pessoa.id}")
        |> json_response(200)

      assert corpo["data"]["login"] == "alvo"
      assert corpo["data"]["provenance"]["source_system"] == "github"
      assert is_list(corpo["data"]["teams"])
    end

    test "a recusa é REGISTRADA — a FR-024 depende disto", ctx do
      conn = com_token(ctx.conn, ctx.tenant, membro(ctx.tenant), ctx.admin)

      log = capture_log(fn -> get(conn, ~p"/api/v1/people/#{ctx.pessoa.id}") end)

      assert log =~ "painel recusado", """
      A rota recusou o painel e não registrou. Amanhã, à pergunta "esta credencial tentou
      ler o painel de alguém?", a resposta continua sendo "não se sabe" — e pela API o
      laço custa menos que pela tela.
      """

      assert log =~ ctx.pessoa.id, "sem o alvo, o registro não diz de quem era o painel"
    end

    test "quem alcança NÃO gera registro de recusa", ctx do
      conn = com_token(ctx.conn, ctx.tenant, ctx.admin)

      log = capture_log(fn -> get(conn, ~p"/api/v1/people/#{ctx.pessoa.id}") end)

      refute log =~ "painel recusado",
             "registrar recusa onde houve acesso encheria o log de ruído e treinaria a ignorá-lo"
    end

    # As medidas do painel NÃO podem ser calculadas quando o veredito é `não`. Calcular e
    # esconder tem o mesmo custo do vazamento, e o dado passa a existir em memória.
    test "recusado custa MENOS consultas que permitido", ctx do
      permitido = consultas(com_token(ctx.conn, ctx.tenant, ctx.admin), ctx.pessoa.id)

      recusado =
        consultas(
          com_token(ctx.conn, ctx.tenant, membro(ctx.tenant), ctx.admin),
          ctx.pessoa.id
        )

      assert permitido > 0, "nenhuma consulta observada — o contador está medindo o vazio"

      assert recusado < permitido,
             "recusado custou #{recusado} e permitido #{permitido}: o painel está sendo " <>
               "calculado para quem não pode vê-lo, e depois escondido"
    end

    defp consultas(conn, person_id) do
      nome = "conta-#{System.unique_integer([:positive])}"
      {:ok, agente} = Agent.start_link(fn -> 0 end)

      :telemetry.attach(
        nome,
        [:the_band, :repo, :query],
        fn _e, _m, _md, _c -> Agent.update(agente, &(&1 + 1)) end,
        nil
      )

      capture_log(fn -> get(conn, ~p"/api/v1/people/#{person_id}") end)
      :telemetry.detach(nome)

      Agent.get(agente, & &1)
    end
  end

  describe "as competências de cada pessoa" do
    setup ctx do
      # Quem TEM perfil, com dois destaques — e um terceiro **sem tarefa concluída**, que
      # não pode contar: destaque sem entrega é texto do modelo sem evidência.
      {:ok, _} =
        EO.record_profile(ctx.tenant, %{
          person_id: ctx.pessoa.id,
          generated_at: ~U[2026-09-01 10:00:00Z],
          model: "modelo-de-teste",
          tasks_closed: 0,
          tasks_open: 0,
          tasks_with_body: 0,
          tasks_authored_by_other: 0,
          tasks_shared: 0,
          content: %{
            "habilidades" => ["Elixir", "Ecto"],
            "lacunas" => ["observabilidade"],
            "resumo" => %{"forcas" => "F", "evolucao" => "E", "atencao" => "A"},
            # O schema exige as três: um perfil sem trajetória, alocação e recomendações
            # seria conclusão sem o caminho que levou a ela.
            "trajetoria" => [
              %{
                "periodo" => 1,
                "meses" => "2026-01 to 2026-06",
                "texto" => "T",
                "tarefas_citadas" => ["uma tarefa"]
              }
            ],
            "alocacao" => [
              %{
                "de" => "2026-01",
                "ate" => "2026-06",
                "dominio" => "coleta do GitHub",
                "demonstrou" => "x",
                "tarefas" => 12
              }
            ],
            "recomendacoes" => ["siga medindo contra a origem"],
            "destaques" => [
              %{
                "dominio" => "coleta do GitHub",
                "demonstrou" => "percorreu a timeline",
                "tarefas" => 12,
                "periodos" => [1, 2],
                "mais_recente" => "2026-08",
                "evidencia" => [101, 102]
              },
              %{
                "dominio" => "ontologia",
                "demonstrou" => "emendou SRO",
                "tarefas" => 3,
                "periodos" => [2],
                "mais_recente" => "2026-09",
                "evidencia" => [201]
              },
              # **Zero tarefas concluídas: não é competência.** Entrega, nunca promessa.
              %{"dominio" => "promessa", "demonstrou" => "disse que faria", "tarefas" => 0}
            ]
          }
        })

      {:ok, sem_perfil} =
        EO.upsert_person_from_source(ctx.tenant, %{
          login: "sem-perfil",
          name: "Sem Perfil",
          account_type: "person",
          source_system: "github",
          source_instance: "https://github.com",
          external_id: "U_sem",
          collected_at: DateTime.utc_now(:second)
        })

      %{conn: com_token(ctx.conn, ctx.tenant, ctx.admin), sem_perfil: sem_perfil}
    end

    test "na LISTAGEM, quem tem perfil traz domínio e tarefas concluídas", ctx do
      linhas = ctx.conn |> get(~p"/api/v1/people") |> json_response(200) |> Map.fetch!("data")
      alvo = Enum.find(linhas, &(&1["login"] == "alvo"))

      assert alvo["competencies"] == [
               %{"domain" => "coleta do GitHub", "completed_tasks" => 12},
               %{"domain" => "ontologia", "completed_tasks" => 3}
             ]

      assert alvo["competencies_note"] == nil
    end

    test "destaque com ZERO tarefa concluída não é competência", ctx do
      linhas = ctx.conn |> get(~p"/api/v1/people") |> json_response(200) |> Map.fetch!("data")
      alvo = Enum.find(linhas, &(&1["login"] == "alvo"))

      refute Enum.any?(alvo["competencies"], &(&1["domain"] == "promessa")),
             "tarefa aberta é intenção e não demonstra nada — só entrega conta"
    end

    # A FR-023 inteira está nesta dupla de testes.
    test "quem NÃO tem perfil traz `null` — e não lista vazia", ctx do
      linhas = ctx.conn |> get(~p"/api/v1/people") |> json_response(200) |> Map.fetch!("data")
      sem = Enum.find(linhas, &(&1["login"] == "sem-perfil"))

      assert sem["competencies"] == nil, """
      Lista vazia diria *o registro foi lido e nada foi demonstrado*. O que houve foi que
      não houve leitura. Achatar as duas transforma lacuna do registro em julgamento da
      pessoa — é o que a FR-023 existe para impedir.
      """

      assert sem["competencies_note"] =~ "absence of reading"
    end

    test "perfil LIDO e nada demonstrado é `[]` — a outra metade da FR-023", ctx do
      {:ok, _} =
        EO.record_profile(ctx.tenant, %{
          person_id: ctx.sem_perfil.id,
          generated_at: ~U[2026-09-02 10:00:00Z],
          model: "modelo-de-teste",
          tasks_closed: 0,
          tasks_open: 0,
          tasks_with_body: 0,
          tasks_authored_by_other: 0,
          tasks_shared: 0,
          # **`destaques` vazio com `habilidades` preenchido é o caso que o schema PERMITE**,
          # e é exactamente o da FR-023: o modelo nomeou habilidades e nenhum domínio teve
          # tarefa concluída. Perfil sem habilidade alguma o schema recusa — "resposta sem
          # habilidade alguma é falha, e não perfil" — então este é o único caminho para
          # `competencies: []`, e é o que prova que aquele ramo não é código morto.
          content: %{
            "destaques" => [],
            "habilidades" => ["disse que sabe"],
            "trajetoria" => [],
            "alocacao" => [],
            "recomendacoes" => [],
            "resumo" => %{},
            "lacunas" => []
          }
        })

      linhas = ctx.conn |> get(~p"/api/v1/people") |> json_response(200) |> Map.fetch!("data")
      sem = Enum.find(linhas, &(&1["login"] == "sem-perfil"))

      assert sem["competencies"] == [],
             "houve leitura e nada foi demonstrado — isto NÃO é `null`"

      assert sem["competencies_note"] == nil,
             "a razão da ausência de leitura não cabe onde houve leitura"
    end

    test "no DETALHE, cada competência desce até as issues que a sustentam", ctx do
      pr =
        ctx.conn
        |> get(~p"/api/v1/people/#{ctx.pessoa.id}")
        |> json_response(200)
        |> get_in(["data", "profile"])

      assert [primeira, segunda] = pr["competencies"]

      assert primeira == %{
               "domain" => "coleta do GitHub",
               "completed_tasks" => 12,
               "demonstrated" => "percorreu a timeline",
               "evidence_issue_numbers" => [101, 102],
               "periods" => [1, 2],
               "most_recent_period" => "2026-08"
             }

      assert segunda["evidence_issue_numbers"] == [201],
             "sem a evidência, a competência é afirmação sem origem"
    end

    test "`skills` é rótulo do modelo, e NÃO se confunde com competência", ctx do
      pr =
        ctx.conn
        |> get(~p"/api/v1/people/#{ctx.pessoa.id}")
        |> json_response(200)
        |> get_in(["data", "profile"])

      assert pr["skills"] == ["Elixir", "Ecto"]

      # A distinção é o ponto: `skills` não tem contagem nem evidência. Tratá-los como
      # equivalentes daria a mesma autoridade a um domínio com 12 tarefas e a uma palavra.
      assert Enum.all?(pr["competencies"], &Map.has_key?(&1, "completed_tasks"))
      assert is_list(pr["skills"]) and Enum.all?(pr["skills"], &is_binary/1)
    end

    test "o perfil carrega a MARCA de derivado e as ressalvas sobre si", ctx do
      pr =
        ctx.conn
        |> get(~p"/api/v1/people/#{ctx.pessoa.id}")
        |> json_response(200)
        |> get_in(["data", "profile"])

      assert pr["origin"] == "derived"
      assert pr["origin_note"] =~ "language model"
      assert Map.has_key?(pr["limits"], "beyond_reach")
      assert Map.has_key?(pr["limits"], "team_not_person")
      assert Map.has_key?(pr["limits"], "wrote_for_others")
    end

    test "a ordem do resumo é forças, evolução, atenção — e é conteúdo", ctx do
      pr =
        ctx.conn
        |> get(~p"/api/v1/people/#{ctx.pessoa.id}")
        |> json_response(200)
        |> get_in(["data", "profile"])

      assert pr["summary"]["strengths"] == "F"
      assert pr["summary"]["evolution"] == "E"
      assert pr["summary"]["attention"] == "A"
    end

    test "a idade do perfil vem declarada — FR-016", ctx do
      pr =
        ctx.conn
        |> get(~p"/api/v1/people/#{ctx.pessoa.id}")
        |> json_response(200)
        |> get_in(["data", "profile"])

      assert Map.has_key?(pr, "tasks_closed_since"),
             "sem isto, um perfil de dezembro parece atual em junho"

      assert pr["generated_at"]
      assert pr["model"] == "modelo-de-teste"
    end

    test "a evolução tem um ponto por geração, e nenhum mês interpolado", ctx do
      {:ok, _} =
        EO.record_profile(ctx.tenant, %{
          person_id: ctx.pessoa.id,
          generated_at: ~U[2026-09-15 10:00:00Z],
          model: "modelo-de-teste",
          tasks_closed: 0,
          tasks_open: 0,
          tasks_with_body: 0,
          tasks_authored_by_other: 0,
          tasks_shared: 0,
          content: %{
            "destaques" => [
              %{"dominio" => "coleta do GitHub", "tarefas" => 20, "demonstrou" => "x"}
            ],
            "trajetoria" => [],
            "alocacao" => [],
            "recomendacoes" => [],
            "habilidades" => ["Elixir"],
            "resumo" => %{},
            "lacunas" => []
          }
        })

      ev =
        ctx.conn
        |> get(~p"/api/v1/people/#{ctx.pessoa.id}")
        |> json_response(200)
        |> get_in(["data", "profile", "evolution_over_time"])

      assert length(ev["generations"]) == 2, "duas gerações, dois pontos — nunca três"
      assert ev["note"] =~ "never interpolated"

      # A contagem cresceu de 12 para 20 no mesmo domínio: é isso que a série mostra.
      assert Enum.map(ev["generations"], & &1["competencies"]["coleta do GitHub"]) == [12, 20]
    end
  end

  describe "as seções que a tela mostra fora do painel" do
    setup ctx, do: %{conn: com_token(ctx.conn, ctx.tenant, ctx.admin)}

    test "discussões e mudanças vêm com o LIMITE declarado", ctx do
      d = ctx.conn |> get(~p"/api/v1/people/#{ctx.pessoa.id}") |> json_response(200)

      assert d["data"]["discussion_participation"]["limit"] == 20
      assert d["data"]["changes"]["limit"] == 10

      assert d["data"]["changes"]["note"] =~ "never summed",
             "lista truncada em silêncio faz quem integra concluir que aquilo é tudo"
    end

    test "as quatro listas de mudança são SEPARADAS, sem total", ctx do
      m = ctx.conn |> get(~p"/api/v1/people/#{ctx.pessoa.id}") |> json_response(200)
      m = m["data"]["changes"]

      for lista <- ~w(opened reviewed merged commits), do: assert(is_list(m[lista]))
      refute Map.has_key?(m, "total"), "a mesma solicitação aparece em mais de uma lista"
    end

    test "discussões e mudanças continuam vindo para quem o veredito RECUSA", ctx do
      # Na tela essas duas seções vivem fora do painel, e o veredito não as esconde.
      # Protegê-las aqui estreitaria o alcance pela porta do transporte.
      d =
        ctx.conn
        |> recycle()
        |> then(&com_token(&1, ctx.tenant, membro(ctx.tenant), ctx.admin))
        |> get(~p"/api/v1/people/#{ctx.pessoa.id}")
        |> json_response(200)

      assert d["data"]["access"]["can_see_work"] == false
      assert d["data"]["work"] == nil
      assert is_map(d["data"]["changes"])
      assert is_map(d["data"]["discussion_participation"])
    end

    test "as paradas ficam DENTRO do painel, e carregam o corte em dias", ctx do
      w = ctx.conn |> get(~p"/api/v1/people/#{ctx.pessoa.id}") |> json_response(200)
      st = w["data"]["work"]["stale_open"]

      assert st["stale_after_days"] == 90,
             "\"parada\" não é adjetivo, é um corte em dias — sem ele o número não diz nada"

      assert is_list(st["items"])
      assert w["data"]["work"]["issues"]["limit"] == 25
      assert w["data"]["work"]["issues"]["note"] =~ "own resource"
    end
  end

  describe "o que a rota recusa dizer" do
    test "pessoa de OUTRO tenant é 404 — igual a pessoa que não existe", ctx do
      {outro, outro_admin} = tenant_with_admin("outro-tenant")

      {:ok, alheia} =
        EO.upsert_person_from_source(outro, %{
          login: "alheia",
          name: "Alheia",
          account_type: "person",
          source_system: "github",
          source_instance: "https://github.com",
          external_id: "U_alheia",
          collected_at: DateTime.utc_now(:second)
        })

      conn = com_token(ctx.conn, ctx.tenant, ctx.admin)

      de_outro = conn |> get(~p"/api/v1/people/#{alheia.id}") |> json_response(404)
      inexistente = conn |> get(~p"/api/v1/people/#{Ecto.UUID.generate()}") |> json_response(404)

      assert de_outro["error"]["code"] == inexistente["error"]["code"]

      assert de_outro["error"]["message"] == inexistente["error"]["message"],
             "distinguir as duas confirmaria a quem varre que o id existe em algum lugar"

      # E o dono do outro tenant vê a sua — o que prova que o 404 acima é o recorte, e não
      # uma pessoa que não foi criada.
      assert ctx.conn
             |> com_token(outro, outro_admin)
             |> get(~p"/api/v1/people/#{alheia.id}")
             |> json_response(200)
             |> get_in(["data", "login"]) == "alheia"
    end

    test "id malformado é 404, e não 500", ctx do
      corpo =
        ctx.conn
        |> com_token(ctx.tenant, ctx.admin)
        |> get(~p"/api/v1/people/nao-e-um-uuid")
        |> json_response(404)

      assert corpo["error"]["code"] == "not_found"
    end

    test "e-mail não aparece em lugar nenhum do corpo", ctx do
      # A consulta de papéis carrega o e-mail de quem declarou, e a listagem exclui e-mail
      # de propósito. Expô-lo aqui porque a consulta já o traz desfaria a decisão por
      # acidente — e é por isso que a guarda olha o corpo INTEIRO, e não um campo.
      cru =
        ctx.conn
        |> com_token(ctx.tenant, ctx.admin)
        |> get(~p"/api/v1/people/#{ctx.pessoa.id}")
        |> Map.fetch!(:resp_body)

      assert ctx.admin.email =~ "@", "o teste só vale se a conta TIVER e-mail"

      refute cru =~ ctx.admin.email
      refute cru =~ ~r/"email"\s*:/
    end

    test "nenhum método de escrita responde", ctx do
      conn = com_token(ctx.conn, ctx.tenant, ctx.admin)
      caminho = "/api/v1/people/#{ctx.pessoa.id}"

      for r <- [
            post(conn, caminho, %{}),
            put(conn, caminho, %{}),
            patch(conn, caminho, %{}),
            delete(conn, caminho)
          ] do
        assert r.status == 405
        assert get_resp_header(r, "allow") == ["GET, HEAD"]
      end
    end

    test "sem token é a mesma recusa das outras rotas", %{conn: conn, pessoa: pessoa} do
      corpo =
        conn
        |> Plug.Conn.put_req_header("accept", "application/json")
        |> get(~p"/api/v1/people/#{pessoa.id}")
        |> json_response(401)

      assert corpo["error"]["code"] == "unauthorized"
    end
  end

  test "a rota aparece na descrição OpenAPI", ctx do
    descricao = ctx.conn |> get(~p"/api/openapi") |> json_response(200)

    assert Map.has_key?(descricao["paths"], "/api/v1/people/{id}"),
           "descrição que não traz a rota mente para quem integra"
  end
end
