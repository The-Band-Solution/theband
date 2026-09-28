defmodule TheBand.Segredo.Varredura do
  @moduledoc """
  Procura segredo em claro num dump ou no banco — feature 064, T002 a T004, FR-008 e FR-009.

  O contrato está em `specs/064-segredo-em-repouso/contracts/varre-segredos.md`. Três regras
  que esta implementação guarda, cada uma com o defeito que a derrubaria:

  1. **O controle positivo vem antes do resultado.** Cada padrão tem o seu exemplo plantado no
     material, e a varredura só relata se achou todos. Sem isso, "zero" significaria tanto
     *limpo* quanto *não olhei* (a L104);
  2. **nada é plantado no material original.** No dump, o plantio vai numa cópia, apagada em
     `after`. No banco, numa transação desfeita sempre, inclusive se a varredura falhar;
  3. **o valor achado nunca sai.** O achado diz tabela, coluna, linha, deslocamento e tamanho.
     Quem investiga vai ao lugar; o relatório não vira mais uma cópia do segredo.

  Os padrões vêm de `TheBand.Segredo.Padroes`, e de nenhum outro lugar.
  """

  alias TheBand.Repo
  alias TheBand.Segredo.Padroes

  Module.register_attribute(__MODULE__, :sobelow_skip, accumulate: true)

  # O esquema dos blocos plantados. O achado nele é o controle, e não entra no resultado.
  @controle "varredura_controle"

  @typedoc "Onde um segredo foi achado. Nunca o valor."
  @type achado :: %{
          tabela: String.t(),
          coluna: String.t(),
          linha: pos_integer(),
          deslocamento: non_neg_integer(),
          tamanho: pos_integer()
        }

  @typedoc "O resultado de uma varredura."
  @type relatorio :: %{
          fonte: String.t(),
          bytes: non_neg_integer() | nil,
          padroes: [Padroes.t()],
          controle: :achou | {:falhou, [atom()]},
          achados: %{atom() => [achado()]}
        }

  # ------------------------------------------------------------------------------- o dump

  @doc """
  Varre um arquivo de `pg_dump`. O plantio vai numa cópia, e a cópia é apagada no fim, com ou
  sem erro.
  """
  @spec dump(Path.t(), [Padroes.t()]) :: {:ok, relatorio()} | {:error, :arquivo_ausente}
  # EXCEÇÃO DE GATE, decidida pela pessoa mantenedora em 2026-09-28. O `sobelow` aponta
  # "Directory Traversal" (confiança baixa) em `File.cp!`, `File.stream!` e `File.rm` com caminho
  # variável. O caminho vem de quem OPERA, pelo `--dump` da linha de comando da própria máquina,
  # e não de requisição: quem roda a tarefa já lê qualquer arquivo dali, e não há travessia a
  # ganhar. A cópia vai para o diretório temporário, com nome gerado aqui. A anotação vale só
  # para esta função, e `varredura_sobelow_test.exs` reprova se ela aparecer em outra.
  @sobelow_skip ["Traversal.FileModule"]
  def dump(caminho, padroes \\ Padroes.todos()) do
    if File.regular?(caminho) do
      copia = Path.join(System.tmp_dir!(), "varredura-#{System.unique_integer([:positive])}.sql")

      try do
        File.cp!(caminho, copia)
        File.write!(copia, bloco_de_controle(padroes), [:append])

        achados = copia |> File.stream!() |> varrer_linhas(padroes)

        {:ok, relatorio("dump: #{caminho}", File.stat!(caminho).size, padroes, achados)}
      after
        File.rm(copia)
      end
    else
      {:error, :arquivo_ausente}
    end
  end

  # Um bloco `COPY` por padrão, no esquema do controle, com a coluna em que ele vale. Assim o
  # controle exercita a mesma regra de `onde` que a varredura aplica ao material de verdade.
  defp bloco_de_controle(padroes) do
    Enum.map_join(padroes, fn p ->
      {tabela, coluna} = lugar_do_controle(p)
      "\nCOPY #{@controle}.#{tabela} (#{coluna}) FROM stdin;\n#{p.exemplo_valido}\n\\.\n"
    end)
  end

  defp lugar_do_controle(%{onde: :qualquer, tipo: tipo}), do: {"controle_#{tipo}", "texto"}
  defp lugar_do_controle(%{onde: [{tabela, coluna} | _]}), do: {tabela, coluna}

  @doc false
  # As linhas de um dump. Dentro de um bloco `COPY`, cada campo é casado com a coluna do
  # cabeçalho; fora dele, só os padrões que valem em qualquer lugar.
  @spec varrer_linhas(Enumerable.t(), [Padroes.t()]) :: [{atom(), String.t(), achado()}]
  def varrer_linhas(linhas, padroes) do
    linhas
    |> Stream.with_index(1)
    |> Enum.reduce({nil, []}, fn {linha, n}, {bloco, acc} ->
      case {bloco, linha} do
        {_, "COPY " <> _} ->
          {cabecalho_copy(linha), acc}

        {{_, _}, "\\." <> _} ->
          {nil, acc}

        {{esquema_tabela, colunas}, _} ->
          {bloco, casar_campos(linha, n, esquema_tabela, colunas, padroes) ++ acc}

        {nil, _} ->
          {nil, casar_texto(linha, n, "(fora de COPY)", "", padroes) ++ acc}
      end
    end)
    |> elem(1)
    |> Enum.reverse()
  end

  defp cabecalho_copy(linha) do
    case Regex.run(~r/^COPY (\S+) \((.*)\) FROM stdin;/, linha) do
      [_, tabela, colunas] ->
        {tabela,
         colunas |> String.split(",") |> Enum.map(&(&1 |> String.trim() |> String.trim("\"")))}

      nil ->
        nil
    end
  end

  defp casar_campos(linha, n, tabela, colunas, padroes) do
    linha
    |> String.trim_trailing("\n")
    |> String.split("\t")
    |> Enum.with_index()
    |> Enum.flat_map(fn {valor, i} ->
      casar_texto(valor, n, tabela, Enum.at(colunas, i, "?"), padroes)
    end)
  end

  defp casar_texto(valor, n, tabela, coluna, padroes) do
    so_tabela = tabela |> String.split(".") |> List.last()

    for p <- padroes,
        Padroes.vale_em?(p, so_tabela, coluna),
        [{deslocamento, tamanho}] <- Regex.scan(p.regex, valor, return: :index) do
      {p.tipo, tabela,
       %{tabela: tabela, coluna: coluna, linha: n, deslocamento: deslocamento, tamanho: tamanho}}
    end
  end

  # ------------------------------------------------------------------------------- o banco

  @doc """
  Varre as colunas de texto do banco configurado. O plantio acontece numa transação desfeita
  sempre, e as tabelas do controle são temporárias.
  """
  @spec banco([Padroes.t()]) :: {:ok, relatorio()}
  def banco(padroes \\ Padroes.todos()) do
    {:error, {:desfeita, relatorio}} =
      Repo.transaction(
        fn ->
          plantar_no_banco(padroes)
          achados = varrer_colunas(padroes)

          Repo.rollback(
            {:desfeita, relatorio("banco: #{banco_configurado()}", nil, padroes, achados)}
          )
        end,
        timeout: :infinity
      )

    {:ok, relatorio}
  end

  defp banco_configurado, do: Repo.config()[:database]

  # O controle mora em tabelas TEMPORÁRIAS, no esquema temporário desta conexão: somem com a
  # transação e nunca tocam uma tabela de verdade.
  defp plantar_no_banco(padroes) do
    for p <- padroes do
      {tabela, coluna} = lugar_do_controle(p)
      Repo.query!(~s|CREATE TEMP TABLE "#{tabela}" ("#{coluna}" text) ON COMMIT DROP|)
      Repo.query!(~s|INSERT INTO "#{tabela}" ("#{coluna}") VALUES ($1)|, [p.exemplo_valido])
    end
  end

  defp varrer_colunas(padroes) do
    %{rows: colunas} =
      Repo.query!("""
      SELECT c.table_schema, c.table_name, c.column_name
        FROM information_schema.columns c
        JOIN information_schema.tables t
          ON t.table_schema = c.table_schema AND t.table_name = c.table_name
       WHERE c.data_type IN ('text', 'character varying', 'character', 'jsonb', 'json')
         AND t.table_type IN ('BASE TABLE', 'LOCAL TEMPORARY')
         AND (c.table_schema = 'public' OR c.table_schema = pg_my_temp_schema()::regnamespace::text)
       ORDER BY 1, 2, 3
      """)

    temporario = temp_schema()

    Enum.flat_map(colunas, fn [esquema, tabela, coluna] ->
      rotulo =
        if esquema == temporario, do: "#{@controle}.#{tabela}", else: "#{esquema}.#{tabela}"

      %{rows: valores} =
        Repo.query!(
          ~s|SELECT "#{coluna}"::text FROM "#{esquema}"."#{tabela}" WHERE "#{coluna}" IS NOT NULL|
        )

      valores
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {[valor], n} -> casar_texto(valor, n, rotulo, coluna, padroes) end)
    end)
  end

  defp temp_schema do
    %{rows: [[esquema]]} = Repo.query!("SELECT pg_my_temp_schema()::regnamespace::text")
    esquema
  end

  # ----------------------------------------------------------------------------- o relatório

  # O achado no esquema do controle é o controle, e não resultado. Cada padrão precisa ter o
  # seu; o que faltar derruba o relatório inteiro.
  defp relatorio(fonte, bytes, padroes, achados) do
    {controle, reais} = Enum.split_with(achados, fn {_, tabela, _} -> controle?(tabela) end)
    achou_no_controle = MapSet.new(controle, fn {tipo, _, _} -> tipo end)

    faltaram = for p <- padroes, not MapSet.member?(achou_no_controle, p.tipo), do: p.tipo

    %{
      fonte: fonte,
      bytes: bytes,
      padroes: padroes,
      controle: if(faltaram == [], do: :achou, else: {:falhou, faltaram}),
      achados:
        Map.new(padroes, fn p ->
          {p.tipo, for({tipo, _, a} <- reais, tipo == p.tipo, do: a)}
        end)
    }
  end

  defp controle?(tabela), do: String.starts_with?(tabela, @controle <> ".")

  @doc """
  O código de saída do contrato: `0` limpo e controle achado, `1` achou segredo, `2` o
  controle falhou. O `2` vence o `1`: se a varredura não enxerga, o que ela achou não prova
  nada sobre o que ela não achou.
  """
  @spec codigo(relatorio()) :: 0 | 1 | 2
  def codigo(%{controle: {:falhou, _}}), do: 2

  def codigo(%{achados: achados}),
    do: if(Enum.any?(achados, fn {_, l} -> l != [] end), do: 1, else: 0)

  @doc "O relatório em texto. Diz o que procurou, e nunca o valor do que achou."
  @spec formatar(relatorio()) :: String.t()
  def formatar(r) do
    cabeca =
      "varredura de segredos — #{r.fonte}" <>
        if(r.bytes, do: " (#{r.bytes} bytes)", else: "")

    controle =
      case r.controle do
        :achou -> "controle positivo ......... ACHOU o valor plantado de cada padrão  ✓"
        {:falhou, t} -> "controle positivo ......... FALHOU para #{Enum.join(t, ", ")}  ✗"
      end

    linhas_padroes =
      for p <- r.padroes do
        achados = Map.fetch!(r.achados, p.tipo)
        "  #{String.pad_trailing(p.nome <> " ", 56, ".")} #{length(achados)}" <> lugares(achados)
      end

    total = r.achados |> Map.values() |> Enum.map(&length/1) |> Enum.sum()

    resultado =
      case codigo(r) do
        0 -> "RESULTADO: limpo — 0 ocorrências em #{length(r.padroes)} padrões"
        1 -> "RESULTADO: ACHOU — #{total} ocorrência(s)"
        2 -> "RESULTADO: inválido — o controle positivo falhou, e a contagem acima não vale"
      end

    Enum.join(
      [cabeca, "", controle, "padrões procurados ........ #{length(r.padroes)}"] ++
        linhas_padroes ++ ["", resultado, "código de saída: #{codigo(r)}"],
      "\n"
    ) <> "\n"
  end

  # Onde, e nunca o quê. No máximo dez lugares por padrão, e a contagem diz o resto.
  defp lugares([]), do: ""

  defp lugares(achados) do
    achados
    |> Enum.take(10)
    |> Enum.map_join(fn a ->
      "\n      #{a.tabela}.#{a.coluna} · linha #{a.linha} · deslocamento #{a.deslocamento} · #{a.tamanho} caracteres"
    end)
  end
end
