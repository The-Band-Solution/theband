defmodule TheBand.Repo.Migrations.AddMergedCheckState do
  @moduledoc """
  O estado da verificação do commit que **entrou** — issue #439.

  ## O que estas colunas consertam

  A feature 037 liga verificação a commit pelo `head_sha`, e o `head_sha` de uma execução é a
  ponta do ramo **naquele instante**. Ramo que recebeu mais commits depois deixa aquela execução
  apontando para um SHA que não é mais a ponta, e o casamento só acha execução para os commits
  que foram ponta em algum push.

  Medido em 2026-08-19, para uma pessoa com 415 solicitações integradas: 98 caíam nesse buraco,
  e a tela as chamava de **"não dá para saber"**. A pessoa mantenedora perguntou se realmente
  não havia como saber — e não havia, com o que eu tinha coletado. Com o que a origem oferece,
  há.

  ## `statusCheckRollup` é campo do COMMIT, e agrega o que faltava

  Ele soma as duas camadas que a coleta de `workflow_run` não alcança:

    * os `check_run` da API de Checks — que é o que o Actions produz por job, e o que apps de
      terceiros publicam;
    * os `status` da API antiga — postos por serviço externo.

  A consulta pede `commits(last: 1)`: a ponta do ramo no momento do merge. É ela que interessa,
  porque a máxima `ci.ap03` fala de **integrado** com verificação vermelha, e o que foi
  integrado é a ponta.

  ## Nulo NÃO é desconhecimento, e é por isso que são duas colunas

  `merged_check_state` nulo com `merged_check_contexts` igual a zero significa **nenhum check
  rodou** — fato sobre o processo, e não lacuna de coleta. Conferido em
  `ifesserra-lab/egressos#18`.

  Sem a contagem de contextos as duas situações seriam indistinguíveis: "não coletamos" e "não
  havia o que coletar" ficariam com o mesmo nulo, que é exatamente a confusão que esta casa mais
  combate.

  E as colunas ficam **cruas**: `SUCCESS`, `FAILURE`, `PENDING`, `ERROR`, `EXPECTED`. A tradução
  para fase da CIRO fica na leitura, nunca no lugar do que a origem disse.
  """
  use Ecto.Migration

  def change do
    alter table(:collected_change_requests) do
      # O SHA da ponta no momento do merge. Guardado porque `statusCheckRollup` é dele, e sem o
      # SHA não há como conferir depois de qual commit o estado veio.
      add :merged_head_sha, :string
      add :merged_check_state, :string
      # Zero com estado nulo = nenhum check rodou. Nulo aqui = não medimos ainda.
      add :merged_check_contexts, :integer
    end

    # A pergunta da máxima é "quais integraram vermelho", e ela filtra por este estado. Índice
    # parcial porque a maioria é SUCCESS ou nulo, e indexá-los não serve à pergunta.
    create index(:collected_change_requests, [:merged_check_state],
             where: "merged_check_state IN ('FAILURE', 'ERROR')",
             name: :collected_change_requests_merged_red_index
           )
  end
end
