defmodule Mix.Tasks.TheBand.ConfereEncerramentos do
  @shortdoc "Falha se algum job terminal do Oban não tem a data que a poda compara"

  @moduledoc """
  Confere que todo registro encerrado carrega a data do encerramento — feature 064, T008,
  FR-015, SC-008.

      mix the_band.confere_encerramentos

  | código | significa |
  |---|---|
  | `0` | nenhum registro terminal sem a coluna que a poda compara |
  | `1` | pelo menos um, e a saída diz qual |

  Sem esta tarefa, a migração da T007 é um `UPDATE` que ninguém repete: o registro sem data
  volta, e fica para sempre, sem ninguém saber.

  **Não imprime `args`, `errors` nem `meta`.** São as colunas onde o segredo foi achado em
  2026-09-12, e o verificador de uma feature de segredo não pode ser mais uma cópia dele.

  Confere o banco do ambiente em que roda. No CI é o de teste, recriado a cada execução, e por
  isso ali ela prova que roda, e não que produção está limpa. O contrato é
  `specs/064-segredo-em-repouso/contracts/confere-encerramentos.md`.
  """
  use Mix.Task

  alias TheBand.Repo

  # A coluna que a poda do Oban 2.23.1 compara com o corte, por estado
  # (`Oban.Engines.Basic.prune_jobs/3`). `completed` usa `scheduled_at`, que é `NOT NULL`, e por
  # isso não entra.
  @colunas [{"cancelled", "cancelled_at"}, {"discarded", "discarded_at"}]

  @limite 20

  @impl Mix.Task
  def run(_args) do
    # Só o `Repo`, e não a aplicação: subir a aplicação inteira sobe o Oban (e a poda que se
    # quer conferir), o endpoint, e exige a chave mestra — nada disso é preciso para ler uma
    # tabela, e a exigência reprovaria o gate de quem não tem a chave no ambiente.
    Mix.Task.run("app.config")
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, _} = Repo.start_link()
    {codigo, texto} = executar()
    IO.write(texto)
    if codigo != 0, do: exit({:shutdown, codigo})
  end

  @doc false
  # Devolve `{codigo, texto}`, e não sai: é o que o teste chama. `run/1` é quem sai.
  @spec executar() :: {0 | 1, String.t()}
  def executar do
    case sem_data() do
      [] ->
        {0, "encerramentos: todo registro terminal tem a data que a poda compara\n"}

      achados ->
        {1, falha(achados)}
    end
  end

  # Só colunas de identificação. Nada de `args`, `errors` ou `meta`: ver o moduledoc. A condição
  # repete `@colunas` por extenso, e não interpolada, para a consulta ser um literal.
  defp sem_data do
    %{rows: rows} =
      Repo.query!(~s"""
      SELECT id, worker, state FROM oban_jobs
       WHERE (state = 'cancelled' AND cancelled_at IS NULL)
          OR (state = 'discarded' AND discarded_at IS NULL)
       ORDER BY id
      """)

    rows
  end

  defp falha(achados) do
    colunas = Map.new(@colunas)

    linhas =
      achados
      |> Enum.take(@limite)
      |> Enum.map_join("\n", fn [id, worker, estado] ->
        "  job #{id} · #{worker} · #{estado} · #{colunas[estado]} nula"
      end)

    resto =
      if length(achados) > @limite,
        do: "\n  … e mais #{length(achados) - @limite}",
        else: ""

    """
    encerramentos: #{length(achados)} registro(s) terminal(is) sem a data que a poda compara
    #{linhas}#{resto}

    A poda do Oban apaga por `coluna < corte`, e NULL nunca é menor que nada: estes registros
    não serão apagados nunca. É o caminho pelo qual um job que falhou carregando segredo fica
    para sempre. Ver specs/064-segredo-em-repouso/contracts/confere-encerramentos.md.
    """
  end
end
