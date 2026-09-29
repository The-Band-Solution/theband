defmodule TheBand.Repo.Migrations.PreencheDatasDeEncerramento do
  @moduledoc """
  Preenche a data de encerramento que falta em registros terminais do Oban — feature 064, T007,
  FR-015.

  ## Por que o registro sem data é permanente

  A poda do Oban compara `cancelled` por `cancelled_at` e `discarded` por `discarded_at`, e
  `NULL < corte` nunca é verdadeiro. Medido em 2026-09-12, e de novo em 2026-09-28 no banco de
  desenvolvimento: quatro `cancelled` de 2026-09-04 sem `cancelled_at`. Um deles carregava o
  segredo, e nunca seria apagado.

  ## A data escolhida

  A mais tardia que o registro tem, porque é a mais próxima do fim dele — e nunca no futuro:
  `scheduled_at` de um job cancelado antes de rodar pode estar adiante, e encerramento no futuro
  adiaria a poda pelo mesmo tanto.

  ## Por que a marca em `meta`

  Sem ela o `down` não saberia quais datas foram inventadas aqui e quais já existiam, e anularia
  as verdadeiras junto. Com ela o rollback devolve exatamente o estado anterior — menos o que a
  poda já tiver apagado, que é o efeito pretendido.

  Idempotente: a segunda execução não acha coluna nula. O contrato é
  `specs/064-segredo-em-repouso/contracts/confere-encerramentos.md`.
  """
  use Ecto.Migration

  # Os estados terminais cuja coluna de poda aceita nulo. `completed` fica de fora: a poda o
  # compara por `scheduled_at`, que é `NOT NULL`.
  @colunas [{"cancelled", "cancelled_at"}, {"discarded", "discarded_at"}]

  @marca "064_preencheu"

  def up, do: Enum.each(sql_up(), &execute/1)

  def down, do: Enum.each(sql_down(), &execute/1)

  @doc false
  # Públicas para o teste executar o mesmo SQL dentro do sandbox, sem rodar o migrador.
  def sql_up do
    for {estado, coluna} <- @colunas do
      ~s"""
      UPDATE oban_jobs
         SET #{coluna} = LEAST(GREATEST(attempted_at, cancelled_at, discarded_at, completed_at,
                                        scheduled_at, inserted_at), now() AT TIME ZONE 'utc'),
             meta = COALESCE(meta, '{}'::jsonb) || jsonb_build_object('#{@marca}', '#{coluna}')
       WHERE state = '#{estado}' AND #{coluna} IS NULL
      """
    end
  end

  @doc false
  def sql_down do
    for {estado, coluna} <- @colunas do
      ~s"""
      UPDATE oban_jobs
         SET #{coluna} = NULL,
             meta = meta - '#{@marca}'
       WHERE state = '#{estado}' AND meta ->> '#{@marca}' = '#{coluna}'
      """
    end
  end
end
