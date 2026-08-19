defmodule TheBand.Repo.Migrations.AddAttendedIssuesProvenance do
  @moduledoc """
  O que a origem disse sobre as issues atendidas, e o que ficou sem resolver — issue #438.

  ## O defeito que estas colunas consertam

  `vincular_issues/3` traduzia `closingIssuesReferences` para ids internos e gravava **só o
  que casou** com uma issue já coletada. Quando a issue não estava no banco, o vínculo era
  descartado **em silêncio**, e a função devolvia o que casou em vez do que a origem disse.

  Medido em 2026-08-19: um painel novo mostrou "no issue recognised: 4.177" — 83% das
  solicitações. Conferido contra a origem, dois de três amostrados **fechavam issue sim**.
  `theband#427` fecha a #426 e a coleta tem até a #397; `otto#127` fecha a #675 de
  `plataformas-project` e a coleta tem até a #671.

  A causa **não** é referência entre repositórios — isso funciona, e `plataformas-project` é
  observado. É que a coleta de issues fica **atrás** da de solicitações, e o vínculo é
  tentado **uma única vez**: solicitação já mergeada não volta a ser percorrida, então a
  issue que chega depois nunca liga.

  ## Por que duas colunas, e por que uma delas é array

  `attended_issues_total` é o número da origem, como `commits_total` já faz. Sozinho ele
  revela o buraco e não deixa fechá-lo.

  `attended_issues_unresolved` guarda os **identificadores externos** que não resolveram. É
  o que permite reconciliar **localmente**, sem tocar na API: quando a issue chegar ao banco
  numa passada seguinte, o vínculo se resolve sem recoletar a solicitação. Guardar só a
  contagem obrigaria a refazer a chamada para descobrir quais eram.
  """
  use Ecto.Migration

  def change do
    alter table(:collected_change_requests) do
      # O que a ORIGEM reconheceu. Nulo é "não sabemos": as solicitações coletadas antes
      # desta migração têm nulo, e a tela não pode ler isso como zero.
      add :attended_issues_total, :integer
      add :attended_issues_unresolved, {:array, :string}, null: false, default: []
    end

    # A pergunta da reconciliação é "quais solicitações têm pendência", e ela é contenção
    # em array — GIN, e não igualdade.
    create index(:collected_change_requests, [:attended_issues_unresolved], using: :gin)
  end
end
