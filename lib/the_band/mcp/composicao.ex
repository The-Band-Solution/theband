defmodule TheBand.MCP.Composicao do
  @moduledoc """
  O bloco `composition` do envelope, montado a partir do **escopo que a ferramenta usou para
  contar** — issues #987 e #1016.

  Depende de: EO (o escopo vem de `EO.team_roster_scope/2`).

  Três ferramentas (`team_open_work`, `team_review_wait` e `team_stale_work`) gravavam
  `is_composed: false` fixo, e o envelope afirmava uma coisa falsa sobre a equipe. Derivar a
  composição do mesmo escopo da contagem é o que impede as duas de discordarem: não há um
  segundo lugar onde a composição seja decidida.

  O escopo começa pela própria equipe, então mais de um elemento é ter partes com composição
  vigente. As notas são frases de tela, em inglês.
  """

  @doc "A composição de uma leitura feita sobre `escopo`, com a nota de cada caso."
  @spec de([Ecto.UUID.t()], String.t(), String.t()) :: %{is_composed: boolean(), note: String.t()}
  def de([_so_a_equipe], nota_simples, _nota_composta),
    do: %{is_composed: false, note: nota_simples}

  def de([_ | _], _nota_simples, nota_composta),
    do: %{is_composed: true, note: nota_composta <> " It is not the sum of the parts."}
end
