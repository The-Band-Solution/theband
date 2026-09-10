defmodule TheBand.Repo.Migrations.EpisodioDeDesativacao do
  @moduledoc """
  A desativação vira **episódio** — protótipo de 2026-09-10, decisão 3.

  ## O defeito que esta migração corrige

  `reativar_changeset/1` fazia `disabled_at: nil, disabled_by_user_id: nil`. É um
  `delete` escrito como `update`: depois de reativar, **ninguém desativou aquela conta
  nunca**. Nesta casa nada é apagado, e aqui isso não é preferência — é o que um
  incidente de acesso precisa reconstruir (SC-005 da spec 045).

  E o par de colunas em `users` só cabe **um** episódio. Uma conta desativada duas
  vezes perdia a primeira.

  ## A forma: `ScopeGrant`, as duas pontas

  Aberto com autor, instante e razão; fechado com autor, instante e razão. Fechar não
  apaga a abertura. O índice parcial garante **um episódio aberto por conta** — o
  histórico de fechados fica livre, que é a mesma forma do
  `access_scope_grants_vigente_index`.

  ## `users.disabled_at` fica, e o que ele passa a ser

  A coluna continua sendo a resposta rápida a *"pode entrar?"*, lida por
  `Auth.verificar/2` a cada entrada. O **registro** é a tabela: reativar zera a coluna
  e **fecha** a linha, e o que aconteceu sobrevive. Denormalização declarada, e não
  duas fontes discordando — `disabled_at` nulo com episódio aberto é estado inválido, e
  os dois se escrevem na mesma transação.

  ## O backfill, e a razão que ele NÃO inventa

  Cada conta hoje desativada ganha um episódio **aberto** com
  `disable_reason = 'not_recorded'`. A cláusula existe no vocabulário declarado
  (`access.account_lifecycle`) e **não é oferecida no formulário**: escolher
  `left_the_organisation` para elas seria a plataforma afirmando uma razão que ninguém
  deu. A tela escreve *"the reason was not recorded"*.

  Contas nunca desativadas não ganham linha nenhuma — não havia episódio.

  ## Por que `disabled_by_user_id` aceita nulo aqui

  Porque o backfill pode não ter autor: `users.disabled_by_user_id` é
  `on_delete: :nilify_all`, e a coluna nasceu depois de o ato existir. Pôr
  `COALESCE(disabled_by_user_id, user_id)` faria a plataforma **afirmar** que a pessoa
  se desativou a si — inventar autor é pior que dizer que não há. O ato daqui para a
  frente sempre grava o seu; a tela escreve *"the author was not recorded"* quando não
  houver.
  """
  use Ecto.Migration

  def up do
    # A CREDENCIAL: de qual ato ela veio, e quem a emitiu.
    #
    # A tela precisa distinguir `temporary · from creation` de `temporary · from a reset`,
    # e **nada no banco dizia qual era qual**. Derivar de `logged_in_at` acerta na maioria
    # e erra no reinício de quem nunca entrou; derivar de `password_set_at ≈ inserted_at`
    # é heurística com cara de fato, que é o pior dos dois.
    #
    # `password_source` é gravada **no momento em que se sabe** — o cadastro sabe que é
    # cadastro, o reinício sabe que é reinício. Nulo é a conta cuja credencial foi emitida
    # antes de esta coluna existir, e a tela escreve isso em vez de escolher uma das duas.
    #
    # `password_set_by_user_id` fecha a outra metade: `reset_password/3` recebia
    # `_actor_id` e **descartava**. A tela dizia "issued 9 Sep by Paulo" no protótipo, e o
    # dado não tinha o Paulo.
    alter table(:users) do
      add :password_source, :string
      add :password_set_by_user_id, :binary_id
    end

    create table(:account_disablements, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :binary_id, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :restrict), null: false

      add :disabled_at, :utc_datetime, null: false
      add :disabled_by_user_id, :binary_id
      add :disable_reason, :string, null: false
      add :disable_note, :text

      add :enabled_at, :utc_datetime
      add :enabled_by_user_id, :binary_id
      add :enable_reason, :string
      add :enable_note, :text

      timestamps(type: :utc_datetime)
    end

    create index(:account_disablements, [:tenant_id, :user_id, :disabled_at])

    # UM episódio aberto por conta. A forma do `access_scope_grants_vigente_index`: o
    # vigente é único, o histórico é livre.
    create unique_index(:account_disablements, [:tenant_id, :user_id],
             where: "enabled_at IS NULL",
             name: :account_disablements_aberto_index
           )

    execute """
    INSERT INTO account_disablements
      (id, tenant_id, user_id, disabled_at, disabled_by_user_id, disable_reason,
       inserted_at, updated_at)
    SELECT gen_random_uuid(), u.tenant_id, u.id, u.disabled_at,
           u.disabled_by_user_id, 'not_recorded', now(), now()
    FROM users u
    WHERE u.disabled_at IS NOT NULL
    """
  end

  def down do
    drop table(:account_disablements)

    alter table(:users) do
      remove :password_source
      remove :password_set_by_user_id
    end
  end
end
