defmodule TheBand.Repo.Migrations.AddDivergenceKind do
  @moduledoc """
  O **tipo** da divergência, ao lado da frase que a explica.

  ## Por que a frase não bastava

  `divergence_reason` é texto para quem lê. Serve para entender uma issue, e não serve para
  responder *"quantas issues do repositório têm tarefa com partes?"* — a resposta exigiria
  casar substring, e casar substring quebra na primeira vez que alguém melhorar a redação.

  É o mesmo par que a lacuna já usa: `skip_reason` classifica, `skip_detail` detalha.

  ## Os cinco tipos, e por que exatamente estes

  | tipo | o que aconteceu |
  |---|---|
  | `epic_without_parts` | o rótulo afirmou épico e não há partes — `sro.rule05` |
  | `composition_makes_epic` | o rótulo afirmou atômica e há partes que são user stories |
  | `task_with_parts` | classificada tarefa, e tem partes coletadas |
  | `user_story_without_parts` | classificada user story, e é folha |
  | `label_vs_structure` | o rótulo e a estrutura discordam de outro jeito |

  Os dois primeiros são **axioma aplicado**: a plataforma mudou o conceito, e diz por quê.
  Os dois seguintes são **sinal**: o conceito foi **mantido**, porque nenhum axioma proíbe
  o caso — e trocar seria a plataforma inventando axioma.

  Essa diferença é o que o tipo torna consultável, e a frase sozinha escondia.

  ## Anulável, e sem retrofito

  As promoções já gravadas têm a frase e não têm o tipo. Deduzir o tipo do texto seria
  exatamente o casamento de substring que esta coluna existe para evitar.

  Nenhuma coluna é removida.
  """
  use Ecto.Migration

  def up do
    alter table(:issue_promotions) do
      add(:divergence_kind, :string)
    end

    create index(:issue_promotions, [:tenant_id, :divergence_kind])

    create constraint(:issue_promotions, :issue_promotions_divergence_kind_known,
             check: """
             divergence_kind is null or divergence_kind in (
               'epic_without_parts', 'composition_makes_epic',
               'task_with_parts', 'user_story_without_parts', 'label_vs_structure'
             )
             """
           )

    # Tipo sem frase seria classificação sem explicação; frase sem tipo é o estado das
    # promoções antigas, e continua permitido.
    create constraint(:issue_promotions, :issue_promotions_divergence_kind_needs_reason,
             check: "divergence_kind is null or divergence_reason is not null"
           )
  end

  def down do
    drop(constraint(:issue_promotions, :issue_promotions_divergence_kind_needs_reason))
    drop(constraint(:issue_promotions, :issue_promotions_divergence_kind_known))
    drop(index(:issue_promotions, [:tenant_id, :divergence_kind]))

    alter table(:issue_promotions) do
      remove(:divergence_kind)
    end
  end
end
