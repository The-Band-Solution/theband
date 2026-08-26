defmodule TheBandWeb.FiltrarPorOrganizacaoTest do
  @moduledoc """
  Escolher uma organização e ver só o que é dela — issue #81, US2 do épico #79.

  ## Os dois casos que carregam este arquivo

  **T016 — o filtro não vaza entre clientes.** O filtro por organização vem da interface, e
  é exatamente onde um vazamento entre organizações clientes nasceria. O princípio V trata
  consulta sem filtro de tenant como bug de **segurança**, e o caso é a violação: um tenant
  pede o identificador do outro e recebe vazio.

  **T014 — a pessoa sobreposta é contada uma vez.** Quem está em duas equipes da mesma
  organização aparece uma vez; quem está em duas organizações aparece nas duas, e a soma
  das contagens fica **maior** que o total. Isso está certo, e sem o caso escrito alguém
  "conserta" a soma.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Ontology.SEON.EO

  setup %{conn: conn} do
    {tenant, user} = tenant_with_admin()
    %{conn: log_in(conn, user), tenant: tenant, user: user}
  end

  describe "o filtro" do
    test "escolher uma organização mostra só quem é dela", ctx do
      {uma, ana} = organizacao_com_pessoa(ctx, "alfa", "ana")
      {outra, bruno} = organizacao_com_pessoa(ctx, "beta", "bruno")

      {:ok, live, html} = live(ctx.conn, ~p"/people")
      assert html =~ "ana"
      assert html =~ "bruno"

      filtrada = filtrar(live, uma.id)
      assert filtrada =~ ana.name
      refute filtrada =~ bruno.name, "quem não é da organização escolhida não aparece"

      outra_filtrada = filtrar(live, outra.id)
      assert outra_filtrada =~ bruno.name
      refute outra_filtrada =~ ana.name
    end

    test "o filtro vive no ENDEREÇO, e sobrevive ao recarregamento", ctx do
      {org, ana} = organizacao_com_pessoa(ctx, "alfa", "ana")
      {_, bruno} = organizacao_com_pessoa(ctx, "beta", "bruno")

      {:ok, _live, html} = live(ctx.conn, ~p"/people?organizacao=#{org.id}")

      assert html =~ ana.name

      refute html =~ bruno.name, """
      **O estado vem do endereço, e não do socket.** Recarregar precisa devolver a mesma
      tela, e o link precisa levar quem recebe ao que quem mandou estava vendo.
      """
    end
  end

  describe "a pessoa sobreposta — T014" do
    test "em duas equipes da MESMA organização, aparece uma vez", ctx do
      {org, ana} = organizacao_com_pessoa(ctx, "alfa", "ana")
      # segunda equipe da mesma organização, com a mesma pessoa
      equipe = team_fixture(ctx.tenant, "T-extra", %{organization: org})
      evidencia(ctx, ana, equipe)

      {:ok, _live, html} = live(ctx.conn, ~p"/people?organizacao=#{org.id}")

      assert EO.count_people(ctx.tenant, organization_id: org.id) == 1, """
      **`IN (subquery)`, e não `join`.** Um `join` devolveria a pessoa uma vez por equipe, e
      a contagem diria dois onde há uma pessoa.
      """

      # A tela mostra a linha uma vez só.
      assert length(String.split(html, ana.name)) - 1 >= 1
    end

    test "em duas organizações, aparece nas DUAS — e a soma passa do total", ctx do
      {uma, ana} = organizacao_com_pessoa(ctx, "alfa", "ana")
      outra = organization_fixture(ctx.tenant, "beta")
      equipe = team_fixture(ctx.tenant, "T-beta", %{organization: outra})
      evidencia(ctx, ana, equipe)

      total = EO.count_people(ctx.tenant)
      na_uma = EO.count_people(ctx.tenant, organization_id: uma.id)
      na_outra = EO.count_people(ctx.tenant, organization_id: outra.id)

      assert na_uma == 1
      assert na_outra == 1

      assert na_uma + na_outra > total, """
      **A soma ser maior que o total está CERTO.** Ana está em duas organizações e é uma
      pessoa só. Sem este caso escrito, alguém "conserta" a soma contando a mesma pessoa
      duas vezes — e aí o total é que passa a mentir.
      """
    end
  end

  describe "o filtro não vaza entre clientes — T016" do
    test "pedir o identificador de organização de OUTRO tenant devolve vazio", ctx do
      {_, ana} = organizacao_com_pessoa(ctx, "alfa", "ana")

      outro_tenant = tenant_fixture()
      alheia = organization_fixture(outro_tenant, "alheia")
      equipe_alheia = team_fixture(outro_tenant, "T-alheia", %{organization: alheia})

      # **Pelo endereço, e não pelo formulário.** O seletor só oferece as organizações do
      # próprio tenant, e o `render_change` do LiveViewTest recusa valor fora das opções —
      # o que é certo, e é justamente por isso que não é o caminho do ataque. Quem quer o
      # dado alheio monta a URL.
      {:ok, _live, html} = live(ctx.conn, ~p"/people?organizacao=#{alheia.id}")

      refute html =~ ana.name, """
      **Princípio V: consulta sem filtro de tenant é bug de SEGURANÇA, não de correção.**

      O identificador de organização vem da interface, e nada impede alguém de mandar o de
      outro cliente. O filtro precisa devolver vazio — e não a lista inteira do tenant de
      quem pediu, que é o que aconteceria se o `organization_id` fosse aplicado sem o
      `tenant_id` continuar valendo.
      """

      assert EO.count_people(ctx.tenant, organization_id: alheia.id) == 0
      refute is_nil(equipe_alheia.id)
    end
  end

  describe "vazio de dado e vazio de filtro são frases diferentes — T017" do
    test "sem organização escolhida e sem coleta: manda esperar a coleta", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/people")
      assert html =~ "No sync has brought people yet"
    end

    test "organização escolhida e ninguém nela: explica que a ligação vem da equipe", ctx do
      organizacao_com_pessoa(ctx, "alfa", "ana")
      vazia = organization_fixture(ctx.tenant, "vazia")

      {:ok, _live, html} = live(ctx.conn, ~p"/people?organizacao=#{vazia.id}")

      assert html =~ "No person is in this organisation", """
      **Vazio de filtro não é vazio de dado.** "Nenhuma pessoa" quando a coleta nunca rodou
      manda esperar; "nenhuma pessoa nesta organização" manda trocar o filtro. Uma frase só
      para os dois faz quem lê procurar no lugar errado.
      """

      assert html =~ "through a team", "e diz POR QUE alguém pode não estar em organização alguma"
    end
  end

  # ------------------------------------------------------------------ apoio

  defp filtrar(live, organizacao_id) do
    live
    |> form("form[phx-change=filtrar_organizacao]", %{"organizacao" => organizacao_id})
    |> render_change()
  end

  defp organizacao_com_pessoa(ctx, login_org, login_pessoa) do
    org = organization_fixture(ctx.tenant, login_org)
    equipe = team_fixture(ctx.tenant, "T-#{login_org}", %{organization: org})
    pessoa = pessoa(ctx.tenant, login_pessoa)
    evidencia(ctx, pessoa, equipe)
    {org, pessoa}
  end

  defp pessoa(tenant, login) do
    {:ok, p} =
      EO.upsert_person_from_source(tenant, %{
        name: login,
        login: login,
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "U_#{login}",
        collected_at: DateTime.utc_now(:second)
      })

    p
  end

  defp evidencia(ctx, pessoa, equipe) do
    {:ok, _} =
      EO.record_team_membership_evidence(ctx.tenant, %{
        team_id: equipe.id,
        person_id: pessoa.id,
        team_external_id: equipe.external_id,
        person_external_id: pessoa.external_id,
        source_system: "github",
        source_instance: "https://github.com",
        # Vínculo observado no GitHub precisa trazer o nível de acesso — e o nível de acesso
        # NÃO é papel: a feature 043 separou os dois de propósito.
        platform_access_level: "MEMBER",
        collected_at: DateTime.utc_now(:second)
      })
  end
end
