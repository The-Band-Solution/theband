defmodule TheBand.Repo.Migrations.QualPessoaObservadaEAConta do
  @moduledoc """
  Qual pessoa observada é cada pessoa usuária — issue #369, FR-012c.

  ## O que faltava, e não estava na issue

  A decisão de 2026-08-26 diz quem vê o painel de quem: a própria pessoa, o líder da equipe
  dela, e o responsável da organização. **Nenhuma das três é computável sem saber qual das
  pessoas observadas é quem está logado**, e esse elo não existia: `users` não tinha coluna
  alguma que apontasse para `eo_people`.

  ## Por que o id do GitHub, e não o e-mail

  Decisão da pessoa mantenedora. Medido no mesmo dia, sobre as 88 pessoas observadas:

      com external_id (o id do GitHub) .. 88
      com login ......................... 88
      com email .........................  0

  O GitHub **não entrega e-mail**, por privacidade. Exigir e-mail obrigaria a digitar os
  dois lados do elo; a identidade da origem já está gravada nas 88, e o lado observado não
  precisa de digitação nenhuma.

  `external_id` é o node id — `U_kgDOABFnGA` —, e não o login. **Login é renomeável**, e o
  GitHub permite que o nome liberado seja reusado por outra pessoa: casar por login faria a
  visibilidade mudar de dono sem nada ter acontecido na plataforma.

  ## A coluna aponta para a pessoa, e não para o id

  `person_id` referencia `eo_people`, que **já carrega** o `external_id` como critério de
  identidade. Guardar o id cru aqui criaria uma segunda cópia dele, e duas cópias divergem.

  Vale também para o dia em que a organização coletar de mais de uma origem: a pessoa é uma
  só e as identidades de origem são várias, e é `eo_people` que as reúne.

  ## Único entre os vigentes

  O elo é o que concede visibilidade. Duas contas apontando para a mesma pessoa fariam duas
  pessoas alcançarem o mesmo painel, e a plataforma não teria como saber que isso foi
  engano. O índice parcial recusa a segunda, e a tela diz de quem já é.

  A recíproca **não** é restringida: uma conta aponta para uma pessoa, e é a coluna que
  garante isso por ser uma só.

  ## Revogar marca

  Retirar o elo é retirar acesso, e é justamente o que se audita. `person_revoked_at`
  preserva o começo — "desde quando essa conta via esse painel" precisa ter resposta, e
  apagar a linha deixaria a pergunta sem nada.
  """
  use Ecto.Migration

  def change do
    alter table(:users) do
      # `restrict`: a pessoa observada não pode sumir por baixo de um elo vigente. Apagar
      # em cascata levaria o rastro junto, e é o rastro que responde quem via o quê.
      add :person_id, references(:eo_people, type: :uuid, on_delete: :restrict)
      add :person_declared_by_user_id, references(:users, type: :uuid, on_delete: :restrict)
      add :person_declared_at, :utc_datetime
      add :person_revoked_by_user_id, references(:users, type: :uuid, on_delete: :restrict)
      add :person_revoked_at, :utc_datetime
    end

    create constraint(:users, :elo_da_pessoa_tem_autor_e_data,
             check:
               "(person_id IS NULL AND person_declared_by_user_id IS NULL AND person_declared_at IS NULL) OR (person_id IS NOT NULL AND person_declared_by_user_id IS NOT NULL AND person_declared_at IS NOT NULL)"
           )

    create unique_index(:users, [:person_id],
             where: "person_id IS NOT NULL AND person_revoked_at IS NULL",
             name: :users_pessoa_observada_vigente_index
           )
  end
end
