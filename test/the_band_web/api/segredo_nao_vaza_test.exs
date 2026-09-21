defmodule TheBandWeb.Api.SegredoNaoVazaTest do
  @moduledoc """
  **SC-001 — o valor em claro de um token não existe em lugar nenhum.** T022.

  É o critério que nenhum outro teste desta fatia substitui. Os outros conferem que a
  credencial *funciona*; este confere que ela não fica *guardada* — e as duas coisas falham
  de maneiras diferentes.

  ## O que "em lugar nenhum" quer dizer, exatamente

  O valor aparece **uma vez**, no render da criação, e é por isso que ele existe: quem o
  criou precisa copiá-lo. Qualquer navegação o apaga do socket (`handle_params`), e a partir
  daí ele não pode reaparecer em canto algum.

  Quatro lugares, e cada um falha de um jeito próprio:

  | Lugar | Como vazaria |
  |---|---|
  | log | um `Logger.info` do parâmetro, ou uma exceção que imprime o `conn` |
  | corpo da resposta | um erro que devolve o que recebeu, "para ajudar a depurar" |
  | HTML renderizado | o valor sobrevivendo ao `assign` de uma navegação |
  | banco | alguém guardando o valor "para poder reexibir" |

  ## O alvo da varredura é o SEGREDO, não o valor inteiro

  O formato é `tb_api_<id_publico>_<segredo>`, e o **id público está no banco de propósito**:
  é por ele que a credencial é encontrada em tempo constante. Varrer pelo valor inteiro
  passaria com o segredo guardado numa coluna sozinha, que é precisamente o vazamento.

  Por isso a varredura procura o **segredo isolado**. E procura o id público também — mas
  para **exigir que ele apareça**: é o que prova que a varredura alcança o banco, e não
  passa por estar olhando para o lugar errado.
  """
  use TheBandWeb.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest

  alias TheBand.Repo

  # As colunas de TEXTO da tabela, e não só `token_hash`. A tarefa pede isso com todas as
  # letras: guardar o segredo em `label` vazaria igual, e um teste que olhasse só a coluna
  # do hash daria verde.
  @tabela "api_access_tokens"

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    %{conn: log_in(conn, admin), tenant: tenant, admin: admin}
  end

  # Extrai o valor do HTML da criação. Se o formato mudar, o teste para de achar e reprova
  # na asserção seguinte — que é o comportamento certo: deixar de achar o valor não pode
  # virar "não vazou".
  defp valor_do_html(html) do
    case Regex.run(~r/tb_api_[a-f0-9]+_[A-Za-z0-9_-]+/, html) do
      [valor] -> valor
      nil -> flunk("o render da criação não mostrou nenhum valor no formato `tb_api_…`")
    end
  end

  defp partes(valor) do
    ["tb", "api", id_publico, segredo] = String.split(valor, "_", parts: 4)
    %{id_publico: id_publico, segredo: segredo}
  end

  defp colunas_de_texto do
    %{rows: linhas} =
      Repo.query!(
        """
        SELECT column_name FROM information_schema.columns
        WHERE table_name = $1 AND data_type IN ('text','character varying','character')
        """,
        [@tabela]
      )

    Enum.map(linhas, &hd/1)
  end

  # Quantas linhas da tabela têm o texto procurado em QUALQUER coluna de texto.
  defp ocorrencias_no_banco(agulha) do
    colunas = colunas_de_texto()

    refute colunas == [],
           "a tabela #{@tabela} não tem coluna de texto — a varredura olharia o nada"

    condicao = Enum.map_join(colunas, " OR ", &"COALESCE(#{&1}, '') LIKE $1")

    %{rows: [[n]]} =
      Repo.query!("SELECT count(*) FROM #{@tabela} WHERE #{condicao}", ["%" <> agulha <> "%"])

    n
  end

  describe "SC-001 — as quatro varreduras" do
    setup ctx do
      {:ok, view, _} = live(ctx.conn, ~p"/api-tokens")

      log =
        capture_log(fn ->
          html = render_submit(form(view, "#novo-token", %{"label" => "varredura do SC-001"}))
          send(self(), {:html, html})
        end)

      html_da_criacao =
        receive do
          {:html, h} -> h
        after
          0 -> flunk("o render da criação não voltou")
        end

      valor = valor_do_html(html_da_criacao)

      %{
        view: view,
        valor: valor,
        partes: partes(valor),
        html_da_criacao: html_da_criacao,
        log_da_criacao: log
      }
    end

    test "o valor APARECE uma vez, no render da criação — e é por isso que ele existe", ctx do
      # Sem esta asserção as outras quatro passariam com a tela quebrada: se a criação não
      # mostrasse valor nenhum, "não vazou" seria verdade e inútil.
      assert ctx.html_da_criacao =~ ctx.valor
      assert String.length(ctx.partes.segredo) >= 20, "segredo curto demais para ser segredo"
    end

    test "1/4 — não sobrevive a navegação nenhuma", ctx do
      depois = render_patch(ctx.view, ~p"/api-tokens")

      refute depois =~ ctx.valor, "o valor em claro sobreviveu a uma navegação"

      refute depois =~ ctx.partes.segredo, """
      O segredo sobreviveu à navegação, ainda que o valor inteiro não. Meio segredo numa
      página é segredo numa página.
      """

      # E a lista continua sendo uma lista: a navegação não pode ter apagado o token junto.
      assert depois =~ "varredura do SC-001"
    end

    test "2/4 — não aparece no log, nem ao criar nem ao usar", ctx do
      log_de_uso =
        capture_log(fn ->
          build_conn()
          |> Plug.Conn.put_req_header("authorization", "Bearer " <> ctx.valor)
          |> get(~p"/api/v1/teams")
          |> json_response(200)
        end)

      for {onde, log} <- [{"criação", ctx.log_da_criacao}, {"uso", log_de_uso}] do
        refute log =~ ctx.valor, "o valor em claro foi ao log na #{onde}"
        refute log =~ ctx.partes.segredo, "o segredo foi ao log na #{onde}"
      end
    end

    test "3/4 — não aparece no corpo de resposta alguma da API", ctx do
      conn = fn ->
        Plug.Conn.put_req_header(build_conn(), "authorization", "Bearer " <> ctx.valor)
      end

      # **O código esperado vai junto de cada corpo.** Varrer o corpo de um `401` não prova
      # nada: uma recusa nunca traria o segredo, e o teste daria verde com a credencial
      # quebrada — que é o contrário do que ele quer dizer.
      respostas = [
        {"listagem de equipes", conn.() |> get(~p"/api/v1/teams"), 200},
        {"listagem de pessoas", conn.() |> get(~p"/api/v1/people"), 200},
        # O caminho do ERRO é onde um corpo costuma devolver o que recebeu "para ajudar".
        {"id malformado", conn.() |> get("/api/v1/people/nao-e-um-uuid"), 404},
        {"credencial estragada",
         build_conn()
         |> Plug.Conn.put_req_header("authorization", "Bearer " <> ctx.valor <> "-estragado")
         |> Plug.Conn.put_req_header("accept", "application/json")
         |> get(~p"/api/v1/teams"), 401}
      ]

      for {onde, resposta, esperado} <- respostas do
        assert resposta.status == esperado,
               "#{onde} devolveu #{resposta.status} e não #{esperado} — o corpo varrido é outro"

        refute resposta.resp_body =~ ctx.valor, "o valor em claro saiu no corpo de #{onde}"
        refute resposta.resp_body =~ ctx.partes.segredo, "o segredo saiu no corpo de #{onde}"
      end
    end

    test "4/4 — não está em NENHUMA coluna de texto do banco", ctx do
      assert ocorrencias_no_banco(ctx.valor) == 0, "o valor em claro está guardado"

      assert ocorrencias_no_banco(ctx.partes.segredo) == 0, """
      O SEGREDO está guardado em alguma coluna de texto de #{@tabela}.

      Varrer só pelo valor inteiro não pegaria isto: bastaria guardar o segredo sozinho, sem
      o prefixo, e a busca pelo valor completo daria zero.
      """
    end

    test "e a varredura do banco ALCANÇA a tabela — o id público está lá", ctx do
      # A prova de que os dois `== 0` acima medem alguma coisa. O id público é guardado de
      # propósito: é por ele que a credencial é encontrada em tempo constante. Se esta
      # asserção falhar, as duas de cima estavam olhando para o lugar errado e passando.
      assert ocorrencias_no_banco(ctx.partes.id_publico) == 1, """
      A varredura não achou o id público, que está no banco por desenho. Então ela não está
      alcançando #{@tabela}, e os dois `== 0` acima não provam nada.
      """

      # E alcança `label` também — que é a coluna onde um vazamento acidental cairia, porque
      # é a única que recebe texto de quem usa. Achar só `public_id` provaria que a
      # varredura lê uma coluna, não que lê todas.
      assert ocorrencias_no_banco("varredura do SC-001") == 1,
             "a varredura não alcança `label`, e é nela que um vazamento por descuido cairia"
    end
  end
end
