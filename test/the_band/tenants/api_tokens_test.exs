defmodule TheBand.Tenants.ApiTokensTest do
  @moduledoc """
  O token que abre a API pública — spec 061, FR-001 a FR-012.

  **Os testes que importam aqui são os da violação.** "O token é gerado" prova pouco; "o valor
  não está em lugar nenhum" e "a comparação não é `==`" provam o que a feature existe para
  garantir. Cinco casos abaixo estão escritos nessa forma, de propósito.
  """
  use TheBand.DataCase, async: true

  alias TheBand.Tenants
  alias TheBand.Tenants.Schemas.ApiAccessToken, as: Token

  setup do
    tenant = tenant_fixture()
    admin = user_fixture(tenant)
    %{tenant: tenant, admin: admin}
  end

  defp criar(ctx, attrs \\ %{}) do
    {:ok, token, valor} =
      Tenants.create_api_token(
        ctx.tenant,
        ctx.admin,
        Map.merge(%{label: "painel"}, attrs),
        ctx.admin
      )

    {token, valor}
  end

  describe "a forma do token" do
    test "tem o prefixo da base de conhecimento, e três partes", ctx do
      {_token, valor} = criar(ctx)
      prefixo = Tenants.api_token_prefix()

      assert String.starts_with?(valor, prefixo), """
      O token não carrega o prefixo declarado em `api.access.thresholds`.

      Sem ele a varredura de segredo em repositório e em log não reconhece o vazamento.
      """

      resto = String.replace_prefix(valor, prefixo, "")
      assert [id_publico, segredo] = String.split(resto, "_", parts: 2)
      assert byte_size(id_publico) > 0
      assert byte_size(segredo) >= 40, "o segredo tem menos que os 32 bytes de FR-002"
    end

    test "o prefixo vem da base, e não de constante deste módulo", _ctx do
      assert Tenants.api_token_prefix() == "tb_api_"

      refute File.read!("lib/the_band/tenants/api_tokens.ex") =~ ~s|@prefixo "tb_api_"|, """
      O prefixo virou constante de módulo.

      Duas cópias divergem, e a que fica para trás é a do varredor de segredo — que falha
      em silêncio. FR-069.
      """
    end

    test "o id público NUNCA contém o separador — o defeito de 2026-09-20", ctx do
      # **Determinístico, e não por amostragem.** O defeito anterior aparecia em ~11,5% dos
      # tokens, o que o fazia passar numa execução e reprovar na seguinte. Mil gerações
      # tornam a ausência de `_` uma afirmação, e não uma sorte.
      ids =
        for _ <- 1..1_000 do
          {token, _valor} = criar(ctx, %{label: "lote"})
          token.public_id
        end

      com_separador = Enum.filter(ids, &String.contains?(&1, "_"))

      assert com_separador == [], """
      #{length(com_separador)} de 1 000 ids públicos contêm `_`, que é o separador das três
      partes do token.

      Quando isso acontece o parser corta no lugar errado, a busca não acha a linha, e o
      token nasce inválido — sem erro nenhum na criação. Foi o defeito de 2026-09-20: o id
      usava Base64 seguro para URL, cujo alfabeto inclui `_`, e 11,5% dos tokens nasciam
      quebrados.
      """

      assert Enum.all?(ids, &String.match?(&1, ~r/^[0-9a-f]+$/)),
             "o id público deixou de ser hexadecimal, e o alfabeto novo pode reintroduzir o `_`"
    end

    test "mil tokens gerados autenticam, todos", ctx do
      # O teste anterior prova a causa; este prova o efeito. Os dois juntos porque um id sem
      # `_` que ainda assim não autenticasse seria outro defeito.
      falhas =
        for _ <- 1..1_000, reduce: [] do
          acc ->
            {_token, valor} = criar(ctx, %{label: "lote"})

            case Tenants.authenticate_api_token(valor) do
              {:ok, _} -> acc
              {:error, _} -> [valor | acc]
            end
        end

      assert falhas == [], "#{length(falhas)} de 1 000 tokens recém-criados não autenticaram"
    end

    test "dois tokens não compartilham id público nem segredo", ctx do
      {a, valor_a} = criar(ctx)
      {b, valor_b} = criar(ctx)

      refute a.public_id == b.public_id
      refute valor_a == valor_b
    end
  end

  describe "o que NÃO é guardado" do
    test "o valor em claro não está no banco", ctx do
      {token, valor} = criar(ctx)

      linha = Repo.get!(Token, token.id)

      refute linha.value, "o campo virtual veio preenchido do banco — ele não pode estar lá"

      {:ok, %{rows: rows}} =
        Repo.query("SELECT * FROM api_access_tokens WHERE id = $1", [Ecto.UUID.dump!(token.id)])

      cru = rows |> List.first() |> Enum.map_join(" ", &inspect/1)

      refute cru =~ valor, """
      O valor em claro do token apareceu numa coluna da linha.

      É SC-001: zero ocorrências em log, resposta, página e banco.
      """
    end

    test "inspect não vaza o hash, nem aninhado", ctx do
      {token, _valor} = criar(ctx)

      texto = inspect(token)
      aninhado = inspect(%{carga: %{token: token}})

      refute texto =~ "token_hash", "`inspect/1` mostrou o hash"

      refute aninhado =~ "token_hash", """
      `inspect/1` escondeu o hash no struct e o mostrou dentro de um mapa.

      Foi assim que um token do GitHub ficou oito dias em claro em `oban_jobs.errors`: um
      struct com segredo dentro, numa mensagem de erro.
      """
    end

    test "a busca não é pelo hash", _ctx do
      # SÓ O CÓDIGO. A prosa do `@moduledoc` cita o padrão proibido justamente para
      # explicá-lo, e uma guarda que lesse o documento reprovaria o arquivo por dizer a
      # coisa certa. Fora comentário e fora documentação.
      fonte =
        "lib/the_band/tenants/api_tokens.ex"
        |> File.read!()
        |> String.replace(~r/@moduledoc\s+"""..*?"""/s, "")
        |> String.replace(~r/@doc\s+"""..*?"""/s, "")
        |> String.split("\n")
        |> Enum.reject(&(String.trim(&1) == "" or String.starts_with?(String.trim(&1), "#")))
        |> Enum.join("\n")

      refute fonte =~ "token_hash ==", """
      Alguma consulta busca pelo `token_hash`.

      Isso entrega a comparação ao Postgres, fora do nosso controle de tempo, e desfaz a
      garantia de tempo constante no mesmo gesto que parecia cumpri-la. É a razão de o token
      ter três partes — ADR 0010.
      """

      assert fonte =~ "secure_compare", "a conferência não usa comparação em tempo constante"
    end
  end

  describe "a conferência, e a recusa que é uma só PARA QUEM CHAMA" do
    test "o valor recém-criado autentica", ctx do
      {token, valor} = criar(ctx)

      assert {:ok, autenticado} = Tenants.authenticate_api_token(valor)
      assert autenticado.id == token.id
    end

    test "as quatro recusas são o mesmo retorno", ctx do
      {_ativo, valor} = criar(ctx)
      prefixo = Tenants.api_token_prefix()

      {revogado, valor_revogado} = criar(ctx)

      {:ok, _} =
        Tenants.revoke_api_token(ctx.tenant, revogado.id, ctx.admin, %{
          revocation_clause: "integracao_encerrada"
        })

      {_expirado, valor_expirado} = criar(ctx, %{expires_in_days: -1})

      recusas = [
        Tenants.authenticate_api_token(prefixo <> "naoexiste_" <> "qualquercoisa"),
        Tenants.authenticate_api_token(valor_revogado),
        Tenants.authenticate_api_token(valor_expirado),
        Tenants.authenticate_api_token("sem_prefixo_nenhum")
      ]

      # **A FR-016 tem DUAS frases, e este teste afirmava só a primeira — de um jeito que
      # tornava a segunda impossível.**
      #
      #   > Token inexistente, revogado e expirado recebem **a mesma resposta**: `401`, com
      #   > o mesmo código de erro e o mesmo texto. **O motivo real é registrado do lado de
      #   > dentro, no log estruturado da aplicação, com o identificador da requisição.**
      #
      # A versão anterior exigia que o **retorno da função** fosse idêntico nas quatro. Com
      # isso o motivo era descartado antes de existir, e o log não tinha o que registrar —
      # foi o SC-004, que reprovou na aceitação de 2026-09-23.
      #
      # O que a FR-016 protege é **a resposta**, e não o retorno interno. Aqui se afirma que
      # as quatro são recusa; que a resposta HTTP é idêntica está em
      # `test/the_band_web/api/motivo_da_recusa_test.exs`, e os dois lados precisam existir.
      assert Enum.all?(recusas, &match?({:error, _}, &1)), """
      Alguma das quatro NÃO foi recusada: #{inspect(recusas)}
      """

      motivos = Enum.map(recusas, fn {:error, m} -> m end)

      assert length(Enum.uniq(motivos)) > 1, """
      As quatro recusas devolvem o mesmo motivo: #{inspect(Enum.uniq(motivos))}

      A FR-016 pede o motivo real **do lado de dentro**. Se o retorno não o carrega, o log
      não tem o que registrar, e à pergunta *"esta credencial foi recusada por quê?"* a
      resposta operacional volta a ser *"por alguma coisa"*.
      """

      assert {:ok, _} = Tenants.authenticate_api_token(valor), "o token ativo foi recusado junto"
    end

    test "o segredo errado com id público certo é recusado", ctx do
      {token, _valor} = criar(ctx)
      forjado = Tenants.api_token_prefix() <> token.public_id <> "_" <> "segredoerrado"

      # O motivo é `:segredo_errado`, e não `:inexistente`: o id público existe, o segredo
      # não confere. A distinção é do log; a resposta HTTP é a mesma das outras.
      assert {:error, :segredo_errado} = Tenants.authenticate_api_token(forjado)
    end

    test "entrada malformada não levanta exceção", _ctx do
      # **O motivo varia, e é correto que varie.** `"tb_api_so_um"` é bem formado — vira id
      # público `so` e segredo `um` — e por isso cai em `:inexistente`, não em
      # `:malformado`. Exigir um motivo só aqui confundiria *"o formato não bate"* com
      # *"o formato bate e a credencial não existe"*, que são coisas diferentes no log.
      #
      # O que este teste afirma é o que o nome dele diz: **nenhuma entrada levanta exceção**.
      for valor <- ["", "tb_api_", "tb_api_so_um", "qualquer coisa", "tb_api__", nil] do
        assert {:error, motivo} = Tenants.authenticate_api_token(valor),
               "não recusou #{inspect(valor)}"

        assert is_atom(motivo), "o motivo de #{inspect(valor)} não é átomo: #{inspect(motivo)}"
      end
    end

    test "a chamada aceita carimba o último uso; a recusada não", ctx do
      {token, valor} = criar(ctx)
      refute token.last_used_at, "nasceu com data de uso — nulo é 'nunca usado'"

      {:ok, usado} = Tenants.authenticate_api_token(valor)
      assert usado.last_used_at

      {:error, :inexistente} = Tenants.authenticate_api_token("tb_api_x_y")
      {:ok, relido} = Tenants.fetch_api_token(ctx.tenant, token.id)
      assert relido.last_used_at == usado.last_used_at
    end
  end

  describe "o estado é lido, nunca gravado" do
    test "revogado vence expirado", ctx do
      {token, _} = criar(ctx, %{expires_in_days: -1})

      {:ok, revogado} =
        Tenants.revoke_api_token(ctx.tenant, token.id, ctx.admin, %{
          revocation_clause: "integracao_encerrada"
        })

      assert Token.estado(revogado, DateTime.utc_now(:second)) == :revogado, """
      Um token revogado que também passou da data foi lido como expirado.

      Revogar foi um ato de alguém; dizer "expirado" apaga o ato e faz parecer que o relógio
      resolveu.
      """
    end

    test "não existe coluna de estado", _ctx do
      colunas = Token.__schema__(:fields)

      refute :status in colunas
      refute :state in colunas
      refute :active in colunas
    end
  end

  describe "a revogação marca, e não apaga" do
    test "a linha continua, e a contagem não muda", ctx do
      {token, _} = criar(ctx)
      antes = Repo.aggregate(Token, :count)

      {:ok, revogado} =
        Tenants.revoke_api_token(ctx.tenant, token.id, ctx.admin, %{
          revocation_clause: "integracao_encerrada"
        })

      assert Repo.aggregate(Token, :count) == antes, "SC-012: zero linhas removidas"
      assert revogado.revoked_at
      assert revogado.revoked_by_user_id == ctx.admin.id
    end

    test "revogar de novo não reescreve quem revogou", ctx do
      {token, _} = criar(ctx)
      outro = user_fixture(ctx.tenant)

      {:ok, primeira} =
        Tenants.revoke_api_token(ctx.tenant, token.id, ctx.admin, %{
          revocation_clause: "integracao_encerrada"
        })

      {:ok, segunda} =
        Tenants.revoke_api_token(ctx.tenant, token.id, outro, %{
          revocation_clause: "suspeita_de_vazamento"
        })

      assert segunda.revoked_by_user_id == primeira.revoked_by_user_id
      assert segunda.revoked_at == primeira.revoked_at
    end

    test "não existe reativar nem apagar na fronteira", _ctx do
      funcoes = Tenants.__info__(:functions) |> Keyword.keys() |> Enum.map(&to_string/1)

      refute Enum.any?(funcoes, &String.contains?(&1, "unrevoke"))
      refute Enum.any?(funcoes, &String.contains?(&1, "reactivate"))
      refute Enum.any?(funcoes, &(&1 == "delete_api_token"))
      refute Enum.any?(funcoes, &(&1 == "update_api_token"))
    end
  end

  describe "o prazo vem da base de conhecimento" do
    test "sem pedido, a expiração é o teto declarado", ctx do
      {token, _} = criar(ctx)
      {maximo, true} = Tenants.api_token_threshold("token_lifetime", "max_days")

      dias = DateTime.diff(token.expires_at, DateTime.utc_now(:second), :day)
      assert_in_delta dias, maximo, 1
    end

    test "pedido acima do teto é REDUZIDO ao teto, e não recusado", ctx do
      {token, _} = criar(ctx, %{expires_in_days: 3650})
      {maximo, true} = Tenants.api_token_threshold("token_lifetime", "max_days")

      dias = DateTime.diff(token.expires_at, DateTime.utc_now(:second), :day)

      assert_in_delta dias, maximo, 1, """
      Um pedido de dez anos virou dez anos, ou virou erro.

      Quem pede 3 650 dias quer o máximo que puder ter; recusar transforma isso em erro de
      formulário sem informação nova.
      """
    end

    # **Não pedir e pedir "sem prazo" são coisas diferentes** — desde que a Q1 passou a
    # oferecer "sem expiração", em 2026-09-23. Colapsar as duas faria toda chamada que omite
    # o campo — um seed, um teste, a fronteira interna — gerar token eterno em silêncio.
    test "campo AUSENTE cai no teto; campo presente e vazio é sem expiração", ctx do
      {maximo, true} = Tenants.api_token_threshold("token_lifetime", "max_days")

      {sem_pedir, _} = criar(ctx)
      assert sem_pedir.expires_at, "omitir o campo gerou token sem prazo, em silêncio"

      assert_in_delta DateTime.diff(sem_pedir.expires_at, DateTime.utc_now(:second), :day),
                      maximo,
                      1

      {escolheu, _} = criar(ctx, %{expires_in_days: nil})

      refute escolheu.expires_at, """
      Escolher "sem expiração" ainda produziu um prazo. A opção existe no formulário desde
      2026-09-23, e um select que não muda o que grava é pior que um select ausente.
      """

      # A tela manda string vazia, e não `nil` — o `<option value="">`. As duas formas do
      # mesmo nada têm de chegar ao mesmo lugar.
      {da_tela, _} = criar(ctx, %{"expires_in_days" => ""})
      refute da_tela.expires_at
    end

    test "o limiar de desuso é declarado e NÃO aplicado", _ctx do
      assert {30, false} = Tenants.api_token_threshold("token_idle_expiry", "idle_days"), """
      O limiar de desuso mudou de valor ou passou a ser aplicado.

      Aplicá-lo exige o carimbo de último uso maduro: expirar por desuso um token que nunca
      teve chance de ser usado derrubaria a integração no dia seguinte ao de gerá-la.
      """
    end
  end

  describe "o isolamento por tenant" do
    test "o token de outro tenant não é encontrado, e a recusa é :not_found", ctx do
      {token, _} = criar(ctx)
      outro = tenant_fixture()

      assert {:error, :not_found} = Tenants.fetch_api_token(outro, token.id)

      assert {:error, :not_found} =
               Tenants.revoke_api_token(outro, token.id, ctx.admin, %{
                 revocation_clause: "integracao_encerrada"
               })
    end

    test "a listagem só traz os do tenant", ctx do
      {meu, _} = criar(ctx)
      outro = tenant_fixture()
      admin_outro = user_fixture(outro)

      {:ok, alheio, _} =
        Tenants.create_api_token(outro, admin_outro, %{label: "outro"}, admin_outro)

      ids = ctx.tenant |> Tenants.list_api_tokens() |> Enum.map(& &1.token.id)

      assert meu.id in ids
      refute alheio.id in ids
    end
  end
end
