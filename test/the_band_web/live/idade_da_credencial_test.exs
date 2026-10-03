defmodule TheBandWeb.IdadeDaCredencialTest do
  @moduledoc """
  O pedido de troca da credencial na tela que a administra — 064/T018, FR-016, FR-017, FR-019.

  A régua é a seção 3 de `specs/064-segredo-em-repouso/prototipo/PROMPT.md` (versão 2, aprovada
  em 2026-10-03). Cada teste nomeia o item que confere; os itens que só se verificam olhando a
  tela (cor, cinza, 360 px, alvo de 44 px) ficam para o QA com navegador.

  ## O que este arquivo protege

  - **pedir, e não impedir**: credencial vencida continua coletando e nada na tela é
    desabilitado (F.6, G.3);
  - **sem data é idade desconhecida, nunca no prazo** — em especial a `API_KEY` do ambiente
    (achado 3, D8, 2.6);
  - **o pedido diz há quanto tempo**: "4 months ago, on <data>", e não "credencial antiga".

  O Mox substitui só a borda HTTP do provedor de modelos.
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query
  import Mox
  import Phoenix.LiveViewTest

  alias TheBand.AI
  alias TheBand.AI.ProviderCredential
  alias TheBand.Credenciais.Idade
  alias TheBand.Ingestion
  alias TheBand.Repo
  alias TheBand.Sources
  alias TheBand.Sources.ConnectedTool
  alias TheBand.Sources.ToolCredential
  alias TheBand.Tenants
  alias TheBandWeb.IdadeDaCredencial

  setup :verify_on_exit!

  @chave "sk-uma-chave-de-teste-com-mais-de-vinte-caracteres-9876"
  @segredo_da_ferramenta "ghp_segredo_da_ferramenta_que_nao_aparece_8f2a"

  setup %{conn: conn} do
    anterior = System.get_env("API_KEY")
    System.delete_env("API_KEY")

    on_exit(fn ->
      if anterior, do: System.put_env("API_KEY", anterior), else: System.delete_env("API_KEY")
    end)

    {tenant, admin} = tenant_with_admin()
    agora = DateTime.utc_now(:second)

    %{
      conn: log_in(conn, admin),
      tenant: tenant,
      admin: admin,
      agora: agora,
      quatro_meses: DateTime.shift(agora, month: -4),
      ontem: DateTime.shift(agora, day: -1)
    }
  end

  defp ferramenta(tenant, org) do
    {:ok, tool} =
      %ConnectedTool{}
      |> ConnectedTool.changeset(%{
        tenant_id: tenant.id,
        tool_type: "github",
        instance_url: "https://github.com",
        organization_login: org
      })
      |> Repo.insert()

    tool
  end

  defp credencial(tenant, tool, label, validada, ativa \\ true) do
    {:ok, credential} =
      %ToolCredential{}
      |> ToolCredential.changeset(%{
        tenant_id: tenant.id,
        connected_tool_id: tool.id,
        label: label,
        secret: @segredo_da_ferramenta,
        last_four: ToolCredential.last_four(@segredo_da_ferramenta),
        scopes: ["read:org"],
        active: ativa,
        validated_at: validada,
        owner_login: "example-bot"
      })
      |> Repo.insert()

    credential
  end

  # A chave do modelo gravada pelo caminho real, e as datas postas depois: `put/3` não aceita
  # data de quem chama (achado 2), e é isso mesmo que se quer.
  defp chave_do_modelo(tenant, datas) do
    expect(TheBand.LLMHTTPMock, :verify, fn _s, _o -> {:ok, ["gpt-5.4"]} end)
    {:ok, cred} = AI.put(tenant, %{"secret" => @chave})

    {1, _} =
      Repo.update_all(
        from(c in ProviderCredential, where: c.id == ^cred.id),
        set: datas
      )

    :ok
  end

  defp data(instante), do: IdadeDaCredencial.data(instante)

  # O HEEx quebra a frase em linhas; a tela, não. Comparar com a frase inteira exige juntar os
  # espaços — a quebra é do código, e não do texto.
  defp texto(html), do: String.replace(html, ~r/\s+/, " ")

  describe "F.2 — o intervalo como a tela o diz" do
    test "hoje, dias abaixo de um mês, meses inteiros para baixo a partir de um" do
      agora = ~U[2026-10-03 12:00:00Z]

      assert IdadeDaCredencial.intervalo(~U[2026-10-03 08:00:00Z], agora) == "today"
      assert IdadeDaCredencial.intervalo(~U[2026-10-02 08:00:00Z], agora) == "1 day ago"
      assert IdadeDaCredencial.intervalo(~U[2026-09-04 08:00:00Z], agora) == "29 days ago"
      assert IdadeDaCredencial.intervalo(~U[2026-09-03 08:00:00Z], agora) == "1 month ago"
      assert IdadeDaCredencial.intervalo(~U[2026-05-28 08:00:00Z], agora) == "4 months ago"
      # 3 meses e 23 dias são 3 meses, e não 4: para baixo.
      assert IdadeDaCredencial.intervalo(~U[2026-06-10 08:00:00Z], agora) == "3 months ago"
      assert IdadeDaCredencial.duracao(~U[2026-05-28 08:00:00Z], agora) == "4 months"
    end
  end

  describe "tela 1 — /tools" do
    test "1.3, F.1, F.2: credencial ativa de 4 meses traz o pedido E o tempo, pelo rótulo", ctx do
      tool = ferramenta(ctx.tenant, "example-org")
      cred = credencial(ctx.tenant, tool, "service account", ctx.quatro_meses)

      {:ok, live, html} = live(ctx.conn, ~p"/tools")

      pedido = live |> element("#request-#{cred.id}") |> render() |> texto()
      assert pedido =~ "Replace the token “service account”."
      assert pedido =~ "It was registered <b>4 months ago</b>, on #{data(ctx.quatro_meses)}."
      assert pedido =~ "The platform asks for a new token 3 months after one is saved."
      assert pedido =~ "Collection goes on with this token meanwhile."
      assert pedido =~ "Nothing stops and nothing is blocked."
      assert pedido =~ "Removing it here does not revoke it on GitHub: revoke it there too."

      assert pedido =~
               "Who can replace it: an administrator, or someone who answers for example-org."

      # A marca da linha: data e meses em uso.
      celula =
        live |> element("#credential-#{cred.id} td[data-label=registered]") |> render() |> texto()

      assert celula =~ data(ctx.quatro_meses)
      assert celula =~ ~s(data-estado="vencida")
      assert celula =~ "replace · 4 months in use"

      # O que o pedido nunca diz.
      refute html =~ "old credential"
    end

    test "1.6, F.5: a de ontem não traz pedido, e diz quando o pedido começa", ctx do
      tool = ferramenta(ctx.tenant, "acme-labs")
      cred = credencial(ctx.tenant, tool, "main credential", ctx.ontem)

      {:ok, live, html} = live(ctx.conn, ~p"/tools")

      refute has_element?(live, "[data-aviso]"), "credencial no prazo não pede nada"
      refute has_element?(live, "[data-marca-da-aba]")

      celula =
        live |> element("#credential-#{cred.id} td[data-label=registered]") |> render() |> texto()

      assert celula =~ data(ctx.ontem)
      assert celula =~ "1 day ago"
      assert celula =~ ~s(data-estado="no_prazo")
      assert celula =~ "within 3 months"

      assert celula =~
               "replacement asked from #{data(DateTime.shift(ctx.ontem, month: 3))}"

      refute html =~ "Replace the token"
    end

    test "1.4, 3.2: a coluna é `registered`, na ordem aprovada, e a tabela empilha", ctx do
      tool = ferramenta(ctx.tenant, "example-org")
      credencial(ctx.tenant, tool, "service account", ctx.ontem)

      {:ok, live, html} = live(ctx.conn, ~p"/tools")

      refute html =~ "validated at"

      cabecalhos =
        live
        |> element("table.stacked thead")
        |> render()
        |> then(&Regex.scan(~r/<th>([^<]*)<\/th>/, &1, capture: :all_but_first))
        |> List.flatten()

      assert cabecalhos == ["label", "credential", "scopes", "registered", "state", ""]

      for rotulo <- ~w(label credential scopes registered state) do
        assert has_element?(live, "table.stacked td[data-label=#{rotulo}]"),
               "a célula #{rotulo} leva data-label, para empilhar no telefone"
      end
    end

    test "1.5: a linha ativa vencida tem fundo âmbar; a no prazo, não", ctx do
      tool = ferramenta(ctx.tenant, "example-org")
      velha = credencial(ctx.tenant, tool, "service account", ctx.quatro_meses)
      nova = credencial(ctx.tenant, tool, "new service account", ctx.ontem)

      {:ok, live, _html} = live(ctx.conn, ~p"/tools")

      assert has_element?(live, "tr#credential-#{velha.id}.bg-warning\\/10")
      refute has_element?(live, "tr#credential-#{nova.id}.bg-warning\\/10")
    end

    test "1.7, D5: com a nova já dentro, o pedido vira desativar a antiga", ctx do
      tool = ferramenta(ctx.tenant, "example-org")
      velha = credencial(ctx.tenant, tool, "service account", ctx.quatro_meses)
      credencial(ctx.tenant, tool, "new service account", ctx.agora)

      {:ok, live, html} = live(ctx.conn, ~p"/tools")

      pedido = live |> element("#request-#{velha.id}") |> render() |> texto()
      assert pedido =~ "The new token is in. “service account” is still active."

      assert pedido =~
               "“service account” was registered <b>4 months ago</b>, on #{data(ctx.quatro_meses)}."

      assert pedido =~
               "Once “new service account” has collected, deactivate or remove the old one, and"

      assert pedido =~ "revoke it on GitHub."
      assert pedido =~ "Collection goes on with both meanwhile."
      refute html =~ "Replace the token “service account”."
    end

    test "1.8, Q1 b: inativa vencida não pede troca; a linha pede para remover", ctx do
      tool = ferramenta(ctx.tenant, "example-org")
      credencial(ctx.tenant, tool, "main", ctx.ontem)
      inativa = credencial(ctx.tenant, tool, "read-only backup", ctx.quatro_meses, false)

      {:ok, live, html} = live(ctx.conn, ~p"/tools")

      refute has_element?(live, "#request-#{inativa.id}")
      refute html =~ "Replace the token"

      celula =
        live
        |> element("#credential-#{inativa.id} td[data-label=registered]")
        |> render()
        |> texto()

      assert celula =~ "past 3 months · inactive"

      linha = live |> element("#inactive-#{inativa.id}") |> render() |> texto()

      assert linha =~
               "“read-only backup” is inactive and was registered 4 months ago, on #{data(ctx.quatro_meses)}."

      assert linha =~ "Its secret is still stored; remove it if it is no longer needed."

      # Inativa não acende a marca da aba (A.1 fala de credencial ATIVA).
      refute has_element?(live, "[data-marca-da-aba]")
    end

    test "1.9, F.3: sem data, a célula diz idade desconhecida e de quem é a ausência" do
      # `tool_credentials.validated_at` é NOT NULL: o caso não é alcançável pelo banco hoje, e a
      # célula é conferida pelo componente — o estado existe, e a tela trata os três.
      html =
        render_component(&IdadeDaCredencial.idade/1,
          credencial: %ToolCredential{validated_at: nil, active: true},
          agora: DateTime.utc_now(:second),
          sem_data: "the platform has no date for this credential"
        )

      assert html =~ ~s(data-estado="idade_desconhecida")
      assert html =~ "age unknown"
      assert html =~ "the platform has no date for this credential"
      refute html =~ "within"
    end

    test "1.2, 1.10, F.6, F.7: nada desabilitado, nada a dispensar, e o rodapé diz que pede",
         ctx do
      tool = ferramenta(ctx.tenant, "example-org")
      credencial(ctx.tenant, tool, "service account", ctx.quatro_meses)

      {:ok, live, html} = live(ctx.conn, ~p"/tools")

      assert has_element?(live, "button", "replace the token")
      assert has_element?(live, "button", "deactivate")
      assert has_element?(live, "button", "remove")
      refute has_element?(live, "button[disabled]"), "a idade não desabilita ação nenhuma"
      refute html =~ ~r/dismiss|snooze|remind me later/i

      assert html =~
               "We ask for a new token 3 months after one is saved. We ask; we never stop"

      assert html =~ "collecting because of age."
    end

    test "4.4: nenhuma parte do segredo no pedido nem na tela", ctx do
      tool = ferramenta(ctx.tenant, "example-org")
      credencial(ctx.tenant, tool, "service account", ctx.quatro_meses)

      {:ok, _live, html} = live(ctx.conn, ~p"/tools")

      refute html =~ @segredo_da_ferramenta
      refute html =~ String.slice(@segredo_da_ferramenta, 0, 8)
    end
  end

  describe "G.3 — pedir, e não impedir" do
    test "a coleta disparada com credencial vencida continua, e com ela", ctx do
      tool = ferramenta(ctx.tenant, "example-org")
      cred = credencial(ctx.tenant, tool, "service account", ctx.quatro_meses)
      assert Idade.estado(cred, ctx.agora) == :vencida

      {:ok, tool} = Sources.fetch_connected_tool(ctx.tenant, tool.id)

      assert {:ok, sync} = Ingestion.start_sync(ctx.tenant, tool)
      assert sync.credential_id == cred.id
    end

    test "a geração com a chave vencida continua recebendo a chave", ctx do
      chave_do_modelo(ctx.tenant, secret_set_at: ctx.quatro_meses)
      {:ok, cred} = AI.fetch(ctx.tenant)
      assert Idade.estado(cred, ctx.agora) == :vencida

      assert Keyword.has_key?(AI.opcoes(ctx.tenant), :key)
    end
  end

  describe "tela 2 — /ai" do
    test "2.2, 2.3: chave de 4 meses traz o pedido e a data dentro de Key in use", ctx do
      chave_do_modelo(ctx.tenant, secret_set_at: ctx.quatro_meses)

      {:ok, live, html} = live(ctx.conn, ~p"/ai")

      pedido = live |> element("#key-request") |> render() |> texto()
      assert pedido =~ "Replace this key."
      assert pedido =~ "It was registered <b>4 months ago</b>, on #{data(ctx.quatro_meses)}."
      assert pedido =~ "The platform asks for a new key 3 months after one is saved."

      assert pedido =~
               "Profile generation goes on with this key meanwhile. Nothing stops and nothing is blocked."

      assert pedido =~ "then revoke the old one"
      assert pedido =~ "Who can replace it: an administrator, or anyone with access to Connected"
      assert pedido =~ "The key"
      assert pedido =~ "is one for the whole organisation."

      registrada = live |> element("#key-registered") |> render() |> texto()
      assert registrada =~ "key registered"
      assert registrada =~ data(ctx.quatro_meses)
      assert registrada =~ "replace · 4 months in use"

      assert html =~ "checked against the provider at"
      refute has_element?(live, "button[disabled]")
    end

    test "2.4: a de ontem não traz pedido", ctx do
      chave_do_modelo(ctx.tenant, secret_set_at: ctx.ontem)

      {:ok, live, _html} = live(ctx.conn, ~p"/ai")

      refute has_element?(live, "#key-request")
      registrada = live |> element("#key-registered") |> render() |> texto()
      assert registrada =~ "within 3 months"
      assert registrada =~ "replacement asked from"
    end

    test "2.5, D7: chave anterior às datas tem a data inferida, hachurada, e pede se vencida",
         ctx do
      chave_do_modelo(ctx.tenant, secret_set_at: nil, validated_at: ctx.quatro_meses)

      {:ok, live, _html} = live(ctx.conn, ~p"/ai")

      registrada = live |> element("#key-registered") |> render() |> texto()
      assert registrada =~ ~s(data-estado="inferida")
      assert registrada =~ "inferred from the last check"
      assert registrada =~ "This key was saved before the platform recorded replacement dates."
      assert registrada =~ "replace · 4 months in use"
      assert has_element?(live, "#key-request", "Replace this key.")
    end

    test "2.6, D8: a chave do ambiente é idade desconhecida, NUNCA no prazo", ctx do
      System.put_env("API_KEY", "sk-do-ambiente-91fc")

      {:ok, live, html} = live(ctx.conn, ~p"/ai")

      bloco = live |> element("#env-key-age") |> render() |> texto()
      assert bloco =~ ~s(data-estado="idade_desconhecida")
      assert bloco =~ "age unknown"
      assert bloco =~ "The absence is the platform&#39;s, not the provider&#39;s."
      assert bloco =~ "This key&#39;s age is unknown, so it is not counted as within 3 months."
      assert bloco =~ "Whoever runs the server replaces it"

      # A violação que o item existe para pegar: a marca de "no prazo" em qualquer lugar.
      refute has_element?(live, ~s([data-estado="no_prazo"]))
      refute has_element?(live, "[data-marca-da-aba]"), "sem data, nada afirma prazo vencido"
      assert html =~ "server environment"
    end

    test "2.6 bis: chave gravada sem data nenhuma também é idade desconhecida", ctx do
      chave_do_modelo(ctx.tenant, secret_set_at: nil, validated_at: nil)

      {:ok, live, _html} = live(ctx.conn, ~p"/ai")

      assert has_element?(live, ~s(#key-registered [data-estado="idade_desconhecida"]))
      refute has_element?(live, ~s([data-estado="no_prazo"]))
      assert has_element?(live, "#key-request", "The age of this key is unknown.")
    end

    test "2.7, D6: a troca diz que data substituiu, e a anterior fica registrada", ctx do
      chave_do_modelo(ctx.tenant, secret_set_at: ctx.quatro_meses)
      expect(TheBand.LLMHTTPMock, :verify, fn _s, _o -> {:ok, ["gpt-5.4"]} end)

      {:ok, live, _html} = live(ctx.conn, ~p"/ai")

      html =
        live
        |> form("#ai-credential", %{
          "secret" => "sk-outra-chave-de-teste-com-mais-de-vinte-7c1e",
          "default_model" => ""
        })
        |> render_submit()

      assert html =~
               "Key checked against the provider and saved (••••7c1e). It replaces the key registered on #{data(ctx.quatro_meses)}; the count starts again today."

      registrada = live |> element("#key-registered") |> render() |> texto()
      assert registrada =~ "today"
      assert registrada =~ "within 3 months"

      anterior = live |> element("#previous-key") |> render() |> texto()
      assert anterior =~ "previous key"
      assert anterior =~ "#{data(ctx.quatro_meses)} → #{data(ctx.agora)}"
      assert anterior =~ "in use for 4 months"
      assert anterior =~ "the date is kept; the secret is gone"
      refute has_element?(live, "#key-request")
    end

    test "2.9: a nota do formulário diz o que a troca e a mesma chave fazem com a data", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/ai")

      assert html =~ "Saving a different key replaces the previous one and starts the count"
      assert html =~ "Saving the same key again"
      assert html =~ "keeps its date."
      refute html =~ "There is no history of secrets"
    end

    test "2.10: sem chave nenhuma, nem idade nem pedido", ctx do
      {:ok, live, html} = live(ctx.conn, ~p"/ai")

      assert html =~ "No key saved"
      refute has_element?(live, "[data-estado]")
      refute has_element?(live, "[data-aviso]")
    end
  end

  describe "A.1, A.2 — a marca na aba" do
    test "ferramenta vencida marca Connected tools nas duas telas, inclusive a atual", ctx do
      tool = ferramenta(ctx.tenant, "example-org")
      credencial(ctx.tenant, tool, "service account", ctx.quatro_meses)

      {:ok, live, _} = live(ctx.conn, ~p"/tools")
      assert has_element?(live, "nav[aria-label=areas] span", "Connected tools")

      assert live |> element("nav[aria-label=areas]") |> render() |> texto() =~
               marca_em("Connected tools")

      {:ok, live, _} = live(ctx.conn, ~p"/ai")

      assert live |> element("nav[aria-label=areas]") |> render() |> texto() =~
               marca_em("Connected tools")

      refute live |> element("nav[aria-label=areas]") |> render() |> texto() =~
               marca_em("AI provider")
    end

    test "chave vencida marca AI provider nas duas telas", ctx do
      chave_do_modelo(ctx.tenant, secret_set_at: ctx.quatro_meses)

      for rota <- [~p"/tools", ~p"/ai"] do
        {:ok, live, _} = live(ctx.conn, rota)
        abas = live |> element("nav[aria-label=areas]") |> render() |> texto()
        assert abas =~ marca_em("AI provider"), "#{rota} sem a marca na aba AI provider"
        refute abas =~ marca_em("Connected tools")
      end
    end

    test "A.2: a marca não sai das abas — nem na navegação principal de outra tela", ctx do
      tool = ferramenta(ctx.tenant, "example-org")
      credencial(ctx.tenant, tool, "service account", ctx.quatro_meses)

      {:ok, live, _} = live(ctx.conn, ~p"/people")
      refute has_element?(live, "[data-marca-da-aba]")
    end
  end

  # A marca vem logo depois do rótulo da aba: o rótulo, o fechamento do link ou do span, e a
  # marca. Confere a aba certa sem depender de espaço em branco.
  defp marca_em(rotulo),
    do: ~r/#{rotulo}\s*<\/(a|span)>\s*<span[^>]*data-marca-da-aba[^>]*>\s*replace/

  describe "tela 4 — quem não administra" do
    setup ctx do
      org_a = organization_fixture(ctx.tenant, "org-a")
      _org_b = organization_fixture(ctx.tenant, "org-b")

      {:ok, membro} =
        Tenants.create_user(ctx.tenant, %{
          "email" => "op-#{System.unique_integer([:positive])}@example.test",
          "role" => "member"
        })

      %{org_a: org_a, membro: membro}
    end

    test "4.1: sem acesso operacional, o redirecionamento de hoje, e nenhuma idade", ctx do
      tool = ferramenta(ctx.tenant, "org-a")
      credencial(ctx.tenant, tool, "service account", ctx.quatro_meses)
      conn = log_in(build_conn(), ctx.membro)

      for rota <- [~p"/tools", ~p"/ai"] do
        assert {:error, {:redirect, %{to: "/people", flash: flash}}} = live(conn, rota)
        assert flash["error"] =~ "organization"
      end

      {:ok, live, _} = live(conn, ~p"/people")
      refute has_element?(live, "[data-aviso]")
      refute has_element?(live, "[data-marca-da-aba]")
    end

    test "4.2: concessão da org A vê o pedido da A, e nada — nem marca — da B", ctx do
      {:ok, _} =
        Tenants.grant_scope(ctx.tenant, ctx.membro.id, :organization, ctx.org_a.id, ctx.admin)

      tool_a = ferramenta(ctx.tenant, "org-a")
      tool_b = ferramenta(ctx.tenant, "org-b")
      credencial(ctx.tenant, tool_a, "credencial-da-org-a", ctx.ontem)
      vencida_b = credencial(ctx.tenant, tool_b, "credencial-da-org-b", ctx.quatro_meses)

      conn = log_in(build_conn(), ctx.membro)

      {:ok, live, html} = live(conn, ~p"/tools")
      refute has_element?(live, "#request-#{vencida_b.id}")
      refute html =~ "credencial-da-org-b"
      refute has_element?(live, "[data-marca-da-aba]"), "a marca contaria a vencida da B"

      {:ok, live, _} = live(conn, ~p"/ai")
      refute has_element?(live, "[data-marca-da-aba]"), "nem em /ai a marca conta a B"

      # E a vencida da A, sim, aparece para quem responde por ela — como 1.7, porque a A já
      # tem uma ativa no prazo, mais nova.
      vencida_a = credencial(ctx.tenant, tool_a, "credencial-velha-da-org-a", ctx.quatro_meses)
      {:ok, live, _} = live(conn, ~p"/tools")

      assert live |> element("#request-#{vencida_a.id}") |> render() |> texto() =~
               "“credencial-velha-da-org-a” is still active."

      assert has_element?(live, "[data-marca-da-aba]")
    end

    test "4.3: em /ai, todo operador vê o pedido da chave", ctx do
      {:ok, _} =
        Tenants.grant_scope(ctx.tenant, ctx.membro.id, :organization, ctx.org_a.id, ctx.admin)

      chave_do_modelo(ctx.tenant, secret_set_at: ctx.quatro_meses)

      {:ok, live, html} = live(log_in(build_conn(), ctx.membro), ~p"/ai")
      assert has_element?(live, "#key-request", "Replace this key.")
      refute html =~ @chave
    end
  end

  describe "G.1 — as marcas se distinguem pela forma, além do texto" do
    test "três formas diferentes para três estados, e a hachura para a data inferida" do
      formas =
        for estado <- [:no_prazo, :vencida, :idade_desconhecida] do
          render_component(&IdadeDaCredencial.marca/1, estado: estado, meses: 4)
        end

      [no_prazo, vencida, desconhecida] = formas
      assert no_prazo =~ "border border-current" and not (no_prazo =~ "border-dashed")
      assert vencida =~ "border-double"
      assert vencida =~ "!"
      assert desconhecida =~ "border-dashed"
      assert desconhecida =~ "italic"
    end
  end
end
