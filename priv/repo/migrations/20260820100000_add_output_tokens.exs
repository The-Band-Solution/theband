defmodule TheBand.Repo.Migrations.AddOutputTokens do
  @moduledoc """
  A outra metade da conta — issue #454.

  ## O que esta coluna conserta

  A `FR-014` mandava gravar "o total de **tokens de entrada** consumidos", e a `FR-021` manda
  medir "o **custo** de uma rodada completa". Os dois não fecham: token de saída é cobrado a
  uma taxa mais alta que o de entrada, e a soma de entrada não permite chegar ao valor.

  A T024 pedia um custo, e o registro só tinha metade dele. Rodar uma rodada nova não
  destravava — ela gravaria de novo a mesma metade.

  ## O número já chegava, e era descartado

  `GenerateWorker.tokens_de_entrada/1` lia `usage["prompt_tokens"] || usage["input_tokens"]`
  do mapa que o provedor devolve. **O mesmo mapa carrega a contagem de saída** —
  `completion_tokens` na rota de chat, `output_tokens` na de mensagens —, e a função lia uma
  chave e jogava o resto fora.

  Não é requisição nova nem chamada extra: é uma chave de um mapa que já estava em memória.
  Mesma alavanca do `raw_payload` preservado, que resolveu o #438 em cinco segundos.

  ## Nula por ausência, nunca zero

  Igual ao `input_tokens`, e pelo mesmo motivo declarado lá: zero significaria "chamou e não
  consumiu". As quatro rodadas já gravadas ficam **nulas** nesta coluna — elas não mediram, e
  dizer zero faria a soma histórica afirmar que aquelas gerações não custaram saída nenhuma.

  ## Sem backfill, e isso é declarado

  A contagem de saída daquelas rodadas está no `usage` de respostas que ninguém preservou —
  ao contrário do `raw_payload` das coletas, a resposta do provedor não é guardada. **Não há
  de onde recuperar**, e é por isso que a coluna nasce nula em vez de zero.

  É a L68 aparecendo de novo: campo novo deixa o registro antigo de fora. Aqui não há corte
  incremental para reabrir — há ausência permanente, e ela fica nomeada.
  """
  use Ecto.Migration

  def change do
    alter table(:profile_run_entries) do
      # Nula = não medimos. Zero seria "chamou e não consumiu", que nunca é verdade numa
      # geração bem-sucedida.
      add :output_tokens, :integer
    end
  end
end
