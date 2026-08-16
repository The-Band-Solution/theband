defmodule TheBand.Repo.Migrations.CreateAiProviderCredentials do
  @moduledoc """
  A credencial do provedor de modelo de linguagem — feature 027.

  ## Por que não é uma `connected_tool`

  Os tipos aceitos lá são `github`, `gitlab`, `azure_devops`, `jira` e `sonar` — todos
  **fontes de observação**: a plataforma coleta deles e grava proveniência apontando para
  eles.

  Um provedor de modelo não produz dado sobre a organização; ele **interpreta** o que a
  plataforma já observou. Guardá-lo em `connected_tools` faria a plataforma afirmar que
  observa a OpenAI, e faria a tela de ferramentas oferecer sincronização de algo que não
  tem o que sincronizar.

  O que se reusa é o que importa: o mesmo `Ecto.Type` de cifragem da credencial de coleta.

  ## Uma por tenant, e por provedor

  Trocar a chave é gravar outra, e a anterior é substituída. Não há histórico de segredo:
  segredo antigo guardado é superfície de ataque sem uso.
  """

  use Ecto.Migration

  def change do
    create table(:ai_provider_credentials, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :provider, :string, null: false
      add :base_url, :string, null: false
      add :default_model, :string

      # Cifrada em repouso pelo mesmo `Ecto.Type` da credencial de coleta. A leitura direta
      # da tabela devolve texto cifrado.
      add :secret, :binary, null: false

      # Os últimos quatro caracteres, em claro, e **só eles**: é o que permite alguém
      # reconhecer qual chave está lá sem que a tela precise decifrar coisa alguma.
      add :last_four, :string, null: false

      add :declared_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)

      # Quando a plataforma **conferiu** a chave contra o provedor. Nulo é "nunca conferida",
      # que é diferente de "conferida e falhou" — esta última tem motivo.
      add :validated_at, :utc_datetime
      add :last_failure_at, :utc_datetime
      add :last_failure_reason, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:ai_provider_credentials, [:tenant_id, :provider],
             name: :ai_provider_credentials_por_tenant_index
           )
  end
end
