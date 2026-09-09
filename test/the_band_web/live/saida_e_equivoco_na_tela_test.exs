defmodule TheBandWeb.SaidaEEquivocoNaTelaTest do
  @moduledoc """
  Os dois formulários da linha — feature 060, T015 e T017: FR-019 a FR-025.

  ## As asserções que carregam este arquivo

  1. **a data não vem preenchida** (FR-023). O protótipo aprovado em 2026-09-07 mostrava
     `2026-09-05` no campo, e a FR-023 substituiu aquela premissa da 055 ("hoje, marcada como
     presumida"): presunção sem marca no registro vira fato. Um campo já preenchido com hoje é
     aceito com um clique, e a data de hoje passa a ser a data de saída de quem saiu no mês
     passado;
  2. **a recusa por data ausente é do servidor**, e não do `required` do HTML. O evento chega
     por websocket, e quem sabe o nome dele não passa pelo formulário;
  3. **"equívoco" não é "saiu"**, e o texto tem de dizer a diferença na tela — não só no
     modelo. As duas ações levam a números diferentes em datas anteriores;
  4. **as ações não existem para quem não gere**, e o evento é recusado de todo modo.
  """
  use TheBandWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TheBand.Ontology.SEON.EO

  setup do
    {tenant, admin} = tenant_with_admin()
    org = organization_fixture(tenant, "acme")
    equipe = team_fixture(tenant, "T_plataforma", %{organization: org, name: "PLATAFORMA"})

    {:ok, papel} =
      EO.create_role(tenant, org.id, %{code: "dev", name: "Desenvolvedora"}, admin.id)

    {:ok, ana} =
      EO.upsert_person_from_source(tenant, source_attrs("U_ana", %{name: "Ana", login: "ana"}))

    {:ok, _} =
      EO.allocate(tenant, %{
        person_id: ana.id,
        team_id: equipe.id,
        organizational_role_id: papel.id,
        declared_by_user_id: admin.id,
        started_at: ~U[2026-01-01 00:00:00Z]
      })

    %{
      conn: log_in(build_conn(), admin),
      tenant: tenant,
      admin: admin,
      equipe: equipe,
      ana: ana,
      papel: papel
    }
  end

  defp estrutura(ctx), do: live(ctx.conn, ~p"/teams/#{ctx.equipe.id}?tab=structure")

  describe "a saída declarada (T015, FR-019 a FR-023)" do
    test "o botão abre o formulário sob a linha, e a data vem VAZIA", ctx do
      {:ok, live, html} = estrutura(ctx)

      refute html =~ "left the team ·", "o formulário não pode nascer aberto"

      aberto =
        live
        |> element(~s|button[phx-click="abrir_saida"][phx-value-person_id="#{ctx.ana.id}"]|)
        |> render_click()

      assert aberto =~ "left the team ·"
      assert aberto =~ "Record departure"

      # O CAMPO SEM VALOR. `value=` preenchido aqui é o defeito que a FR-023 nomeia.
      assert aberto =~ ~s|type="date" name="quando"|

      refute aberto =~ ~r/name="quando"[^>]*value="\d/, """
      A data da saída não pode vir preenchida (FR-023). Um campo com hoje dentro é aceito com
      um clique, e a data de hoje passa a ser a data de saída de quem saiu no mês passado — sem
      que ninguém tenha afirmado isso.
      """
    end

    test "a nota diz que o vínculo é encerrado, e não apagado", ctx do
      {:ok, live, _html} = estrutura(ctx)

      aberto =
        live
        |> element(~s|button[phx-click="abrir_saida"][phx-value-person_id="#{ctx.ana.id}"]|)
        |> render_click()

      assert aberto =~ "ended, not deleted"
      assert aberto =~ "stays exactly the same"
      assert aberto =~ "will show"
    end

    test "registrar a saída fecha o vínculo e diz quantos alcançou", ctx do
      {:ok, live, _html} = estrutura(ctx)

      depois =
        render_submit(live, "registrar_saida", %{
          "person_id" => ctx.ana.id,
          "quando" => "2026-08-20"
        })

      assert depois =~ "Departure recorded"
      assert depois =~ "1 link ended", "a frase tem de dizer quantos vínculos foram alcançados"

      # E o fato no banco: encerrado na data informada, com autor.
      assert EO.count_team_members_at(ctx.tenant, ctx.equipe.id, ~U[2026-09-01 00:00:00Z]) == 0

      assert EO.count_team_members_at(ctx.tenant, ctx.equipe.id, ~U[2026-06-01 00:00:00Z]) == 1,
             "encerrar reescreveu um período anterior à saída"
    end

    test "data vazia é recusada pelo SERVIDOR, com a razão", ctx do
      {:ok, live, _html} = estrutura(ctx)

      # Sem passar pelo formulário: é assim que o evento chega de quem sabe o nome dele, e o
      # `required` do HTML não vale aqui.
      depois =
        render_submit(live, "registrar_saida", %{"person_id" => ctx.ana.id, "quando" => ""})

      assert depois =~ "needs a date"
      assert depois =~ "does not assume today"

      assert EO.count_team_members_at(ctx.tenant, ctx.equipe.id, DateTime.utc_now()) == 1,
             "a recusa encerrou o vínculo mesmo assim"
    end

    test "data no futuro é recusada", ctx do
      {:ok, live, _html} = estrutura(ctx)
      amanha = Date.utc_today() |> Date.add(1) |> Date.to_iso8601()

      depois =
        render_submit(live, "registrar_saida", %{
          "person_id" => ctx.ana.id,
          "quando" => amanha
        })

      # A recusa vem do domínio, e o texto dela está em PORTUGUÊS numa tela em inglês —
      # `record_team_departure/5` devolve "a saída não pode estar no futuro" como string crua,
      # não como `dgettext`. É anterior à feature 060 (nasceu na 055) e está registrado como
      # dívida; o teste afirma o texto que a tela de facto mostra, e não o que ela deveria.
      assert depois =~ "não pode estar no futuro"

      assert EO.count_team_members_at(ctx.tenant, ctx.equipe.id, DateTime.utc_now()) == 1
    end
  end

  describe "o equívoco (T017, FR-024 e FR-025)" do
    test "o formulário exige razão, e o texto separa equívoco de saída", ctx do
      {:ok, live, _html} = estrutura(ctx)

      aberto =
        live
        |> element(~s|button[phx-click="abrir_equivoco"][phx-value-person_id="#{ctx.ana.id}"]|)
        |> render_click()

      assert aberto =~ "registered by mistake ·"
      assert aberto =~ "Invalidate link"
      assert aberto =~ ~s|name="razao"|
      assert aberto =~ "required"

      # O TEXTO QUE SEPARA AS DUAS AÇÕES. Sem ele, "equívoco" é lido como uma saída mais
      # enfática — e as duas dão números diferentes em datas anteriores.
      assert aberto =~ "This is not"
      assert aberto =~ "never was"
      assert aberto =~ "every date"
      assert aberto =~ "declared and observed"
    end

    test "registrar o equívoco tira a pessoa de TODA data", ctx do
      {:ok, live, _html} = estrutura(ctx)

      depois =
        render_submit(live, "registrar_equivoco", %{
          "person_id" => ctx.ana.id,
          "razao" => "login errado ao declarar"
        })

      assert depois =~ "Recorded as a mistake"
      assert depois =~ "counts for no date"

      # A diferença com a saída, medida: o período anterior também zera.
      assert EO.count_team_members_at(ctx.tenant, ctx.equipe.id, ~U[2026-06-01 00:00:00Z]) == 0,
             "o equívoco tem de sair da medida também nas datas anteriores"
    end

    test "razão vazia é recusada, e nada é gravado", ctx do
      {:ok, live, _html} = estrutura(ctx)

      depois =
        render_submit(live, "registrar_equivoco", %{
          "person_id" => ctx.ana.id,
          "razao" => "   "
        })

      assert depois =~ "razão escrita"

      assert EO.count_team_members_at(ctx.tenant, ctx.equipe.id, DateTime.utc_now()) == 1
    end

    test "um formulário por vez: abrir o equívoco fecha a saída", ctx do
      {:ok, live, _html} = estrutura(ctx)

      live
      |> element(~s|button[phx-click="abrir_saida"][phx-value-person_id="#{ctx.ana.id}"]|)
      |> render_click()

      depois =
        live
        |> element(~s|button[phx-click="abrir_equivoco"][phx-value-person_id="#{ctx.ana.id}"]|)
        |> render_click()

      assert depois =~ "registered by mistake ·"

      refute depois =~ "left the team ·", """
      Dois formulários abertos sobre a mesma pessoa — um dizendo "saiu em", o outro "nunca
      esteve" — convidam a preencher os dois. São afirmações contraditórias.
      """
    end
  end

  describe "quem não gere não vê ação, e o evento é recusado (FR-006)" do
    setup ctx do
      {:ok, outra} =
        TheBand.Tenants.create_user(ctx.tenant, %{
          "email" => "sem-gestao-#{System.unique_integer([:positive])}@example.test",
          "role" => "member"
        })

      %{leitor: log_in(build_conn(), outra)}
    end

    test "lê a lista inteira e não vê os botões", ctx do
      {:ok, _live, html} = live(ctx.leitor, ~p"/teams/#{ctx.equipe.id}?tab=structure")

      assert html =~ "Ana", "quem não gere continua LENDO a estrutura inteira"
      refute html =~ "abrir_saida"
      refute html =~ "abrir_equivoco"
    end

    test "o evento disparado direto é recusado, e nada muda", ctx do
      {:ok, live, _html} = live(ctx.leitor, ~p"/teams/#{ctx.equipe.id}?tab=structure")

      depois =
        render_submit(live, "registrar_saida", %{
          "person_id" => ctx.ana.id,
          "quando" => "2026-08-20"
        })

      assert depois =~ "not linked to a person"

      assert EO.count_team_members_at(ctx.tenant, ctx.equipe.id, DateTime.utc_now()) == 1,
             "o evento passou sem o veredito"
    end
  end
end
