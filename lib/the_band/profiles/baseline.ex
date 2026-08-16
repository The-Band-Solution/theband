defmodule TheBand.Profiles.Baseline do
  @moduledoc """
  A linha de base do tenant, mês a mês — feature 026.

  ## Por que ela existe

  O corpo mediano das descrições deste tenant foi de **216 caracteres em 2025-01 para 1310
  em 2026-06**. Sem comparar cada pessoa com o projeto nos mesmos meses, todo perfil conclui
  que ela aprendeu a documentar — e todos concluem isso no mesmo mês, o mês em que o time
  mudou de convenção.

  A linha de base é o que separa **mudança da pessoa** de **mudança do time**.

  ## Uma consulta, e não uma por pessoa

  A base é do tenant, e é a mesma para todo mundo. Calcular dentro do laço dos períodos seria
  N+1 por definição; calcular por pessoa multiplicaria por 25 uma consulta que tem uma
  resposta só.

  ## Mês sem issue não vira linha com zero

  Ele simplesmente não está no mapa. Zero seria a afirmação de que o projeto não produziu
  naquele mês, e a ausência do mês é a afirmação correta: não há o que medir ali.
  """

  import Ecto.Query

  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @type mes :: %{
          criadas: non_neg_integer(),
          concluidas: non_neg_integer(),
          corpo_mediano: non_neg_integer(),
          pct_titulo_tipado: non_neg_integer()
        }

  @type t :: %{String.t() => mes()}

  @doc """
  Carrega a linha de base inteira do tenant, indexada por `"AAAA-MM"`.
  """
  @spec load(Tenant.t()) :: t()
  def load(%Tenant{id: tenant_id}) do
    criadas = por_mes_de_criacao(tenant_id)
    concluidas = por_mes_de_conclusao(tenant_id)

    Map.new(criadas, fn {mes, {n, corpo, tipado}} ->
      {mes,
       %{
         criadas: n,
         concluidas: Map.get(concluidas, mes, 0),
         corpo_mediano: corpo,
         pct_titulo_tipado: tipado
       }}
    end)
  end

  @doc """
  A fatia da linha de base entre dois meses, inclusive.

  Devolve `{criadas, concluídas, corpo_mediano, pct_titulo_tipado}` do intervalo. O corpo
  mediano do intervalo é a **mediana das medianas mensais** — e não a mediana global, que
  exigiria carregar todos os corpos do tenant para calcular.
  """
  @spec fatia(t(), String.t(), String.t()) ::
          %{
            criadas: non_neg_integer(),
            concluidas: non_neg_integer(),
            corpo_mediano: non_neg_integer(),
            pct_titulo_tipado: non_neg_integer()
          }
  def fatia(base, de, ate) when is_binary(de) and is_binary(ate) do
    meses = for {m, v} <- base, m >= de, m <= ate, do: v

    %{
      criadas: soma(meses, :criadas),
      concluidas: soma(meses, :concluidas),
      corpo_mediano: mediana(Enum.map(meses, & &1.corpo_mediano)),
      pct_titulo_tipado: media(Enum.map(meses, & &1.pct_titulo_tipado))
    }
  end

  def fatia(_base, _de, _ate),
    do: %{criadas: 0, concluidas: 0, corpo_mediano: 0, pct_titulo_tipado: 0}

  # -- as duas consultas -------------------------------------------------------

  defp por_mes_de_criacao(tenant_id) do
    from(i in "collected_issues",
      where: i.tenant_id == type(^tenant_id, :binary_id) and not is_nil(i.external_created_at),
      group_by: fragment("to_char(date_trunc('month', ?), 'YYYY-MM')", i.external_created_at),
      select: {
        fragment("to_char(date_trunc('month', ?), 'YYYY-MM')", i.external_created_at),
        count(i.id),
        fragment(
          "percentile_disc(0.5) within group (order by coalesce(length(?), 0))::int",
          i.body
        ),
        fragment(
          "round(count(*) filter (where ? ~ '^\\[[A-Z]+\\]') * 100.0 / count(*))::int",
          i.title
        )
      }
    )
    |> Repo.all()
    |> Map.new(fn {mes, n, corpo, tipado} -> {mes, {n, corpo || 0, tipado || 0}} end)
  end

  defp por_mes_de_conclusao(tenant_id) do
    from(i in "collected_issues",
      where: i.tenant_id == type(^tenant_id, :binary_id) and not is_nil(i.external_closed_at),
      group_by: fragment("to_char(date_trunc('month', ?), 'YYYY-MM')", i.external_closed_at),
      select: {
        fragment("to_char(date_trunc('month', ?), 'YYYY-MM')", i.external_closed_at),
        count(i.id)
      }
    )
    |> Repo.all()
    |> Map.new()
  end

  # -- aritmética --------------------------------------------------------------

  defp soma(meses, chave), do: Enum.reduce(meses, 0, &(Map.fetch!(&1, chave) + &2))

  defp mediana([]), do: 0

  defp mediana(valores) do
    ordenados = Enum.sort(valores)
    Enum.at(ordenados, div(length(ordenados), 2))
  end

  defp media([]), do: 0
  defp media(valores), do: div(Enum.sum(valores), length(valores))
end
