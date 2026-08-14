defmodule TheBand.Repo.Migrations.PapelDeclaradoTemAutor do
  @moduledoc """
  Quem declarou o vínculo, e o índice que impede a alocação repetida sem proibir o histórico.

  ## O autor

  O vínculo é **declaração humana** — nenhuma origem observada fornece papel organizacional.
  Sem autor, ele fica indistinguível de observação, que é a distinção que a feature inteira
  defende.

  **Anulável de propósito.** Proibir nulo obrigaria a inventar um usuário-sistema para
  qualquer vínculo que não venha de alguém digitando, e autor falso mente mais que autor
  ausente.

  ## O índice parcial

  `WHERE ended_at IS NULL` é o que expressa "vigente" sem inventar coluna de estado.

  Ele impede a mesma pessoa alocada duas vezes ao **mesmo** papel na mesma equipe ao mesmo
  tempo. Permite, de propósito:

    * dois papéis diferentes na mesma equipe — acumular Developer e Scrum Master é comum em
      Scrum, e recusar produziria uma plataforma incapaz de descrever times reais;
    * o mesmo papel com períodos distintos — quem saiu e voltou tem duas linhas.

  Um único simples proibiria o segundo caso, e apagar a linha antiga para permitir a nova
  seria apagar dado.
  """

  use Ecto.Migration

  def change do
    alter table(:eo_team_memberships) do
      add :declared_by_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
    end

    create unique_index(
             :eo_team_memberships,
             [:tenant_id, :person_id, :team_id, :organizational_role_id],
             where: "ended_at IS NULL",
             name: :eo_team_memberships_vigente_index
           )
  end
end
