defmodule TheBand.Repo.Migrations.TokensDeApi do
  @moduledoc """
  A credencial que abre a API pública — spec 061, FR-001 a FR-012.

  ## O que esta tabela deliberadamente NÃO tem

  **O valor em claro** (FR-003). Não existe coluna com ele, nem coluna cifrada reversível a
  ele. A plataforma só precisa **conferir** o token, nunca replicá-lo — e guardar cifrado o
  que só precisa ser conferido é guardar uma porta a mais. Ver a ADR 0010.

  **Escopo, papel, ou qualquer veredito** (FR-027). O que o token alcança é recomputado a
  cada requisição por `Tenants.Access`, que lê as relações vigentes. Veredito gravado é
  segunda verdade, e ela **envelhece no bolso de quem saiu**.

  **Coluna de estado.** Ativo, revogado e expirado são **leitura** contra o instante da
  requisição. Uma coluna exigiria job para virar `expired`, e job cria a janela entre vencer
  e ser marcado — que é acesso concedido por atraso de fila.

  **`deleted_at` ou qualquer apagar.** Revogação marca. A linha revogada continua na lista,
  com data e autor, porque um token que sumiu da tela é um token que ninguém sabe que existiu.

  ## Os dois índices, e o que NÃO é indexado

  O único em `(tenant_id, public_id)`: é o caminho de busca de **toda** requisição
  autenticada, e único para que não haja dois candidatos.

  O de `(tenant_id, user_id)`: a lista da tela, e a revogação em massa por conta.

  **Nenhum índice em `token_hash`**, e a ausência é a decisão. Buscar por ele entregaria a
  comparação ao Postgres, fora do nosso controle de tempo — e desfaria a garantia de tempo
  constante no mesmo gesto que parecia cumpri-la. É a razão de o token ter três partes.

  ## `restrict` nas duas chaves

  Apagar um tenant ou uma conta **não pode** apagar em silêncio a credencial que abria a
  porta: o rastro de que ela existiu é o que responde *"o que essa integração alcançava?"*
  depois. É o que 61 das 65 chaves de `tenant_id` já fazem.
  """
  use Ecto.Migration

  def change do
    create table(:api_access_tokens, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      # De quem o token HERDA o alcance — FR-025, decisão Q2. Sem conta dona não há alcance
      # a recomputar, e por isso não aceita nulo.
      add :user_id, references(:users, type: :uuid, on_delete: :restrict), null: false

      # FR-009. Token sem rótulo é token que ninguém sabe revogar.
      add :label, :string, null: false

      # A parte por onde a linha é buscada. Ver o moduledoc.
      add :public_id, :string, null: false

      # SHA-256 do segredo — 32 bytes. Nunca o valor, nunca reversível (FR-003, ADR 0010).
      add :token_hash, :binary, null: false

      # FR-007. Distinguir dois tokens da mesma conta na lista, sem revelar nada.
      add :last_four, :string, size: 4, null: false

      add :created_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)

      # FR-011. Nulo é "sem expiração", e a tela escreve isso — nunca uma data vazia.
      add :expires_at, :utc_datetime

      # FR-010. Nulo é "nunca usado", e a tela escreve isso — nunca a data de criação.
      add :last_used_at, :utc_datetime

      # FR-012. Revogação MARCA.
      add :revoked_at, :utc_datetime
      add :revoked_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:api_access_tokens, [:tenant_id, :public_id])
    create index(:api_access_tokens, [:tenant_id, :user_id])
  end
end
