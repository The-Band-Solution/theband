defmodule TheBand.Repo.Migrations.RegistroDeLeituraDaApi do
  @moduledoc """
  O registro de **leitura bem-sucedida** pela API — achado A1 da avaliação de segurança da
  feature 062, em 2026-09-22.

  ## O que faltava, e por que é alto

  Nada registrava leitura bem-sucedida. `AccessEvents` tem seis funções e nenhuma é *"leu o
  dado de alguém"*; o plug da API registra só a **recusa**; e `api_access_tokens.last_used_at`
  é um carimbo **sobrescrito** a cada chamada.

  A FR-024 da spec 045 aceita o risco de **agregação** — quem alcança muitos itens reconstrói
  por acumulação o que o veredito recusa direto — e aponta o **registro de acesso** como o
  caminho para percebê-lo. Esse caminho não existia.

  Cenário medido no desenho: quem tem token válido chama as listagens uma vez por dia durante
  um mês e monta a série temporal do trabalho de cada pessoa. Nenhuma chamada recusada, nenhum
  veredito violado, e o único rastro seria **uma data sobrescrita**.

  ## Por que tabela, e não linha de log

  Duas razões, e a primeira é verificabilidade:

  1. **o nível de log em teste é `:warning`**, e o próprio `AccessEvents` documenta que um
     evento em `:info` não é observável por teste nenhum. Um registro que nenhum teste
     alcança é um registro em que ninguém confia;
  2. **a FR-024 pede contagem**, e não rastro: *"quantas leituras esta credencial fez na
     última janela"* é consulta. Log vira contagem só com agregador, e esta instalação não
     declara nenhum.

  ## O que NÃO entra

  **O corpo da resposta não é gravado.** O registro diz *quem leu o quê, e quando* — nunca
  *o que leu*. Gravar o corpo criaria uma segunda cópia do dado, com a mesma sensibilidade e
  sem o veredito na frente.

  **O segredo do token não entra**: só o `public_id`, que já é o identificador de busca.
  """
  use Ecto.Migration

  def change do
    create table(:api_access_reads, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # `on_delete: :restrict`, como 61 das 65 chaves desta base: apagar um tenant não pode
      # levar junto o registro de quem leu o que era dele.
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      # O ID PÚBLICO, e não o id da linha do token: o registro tem de continuar legível
      # depois de o token ser apagado. Quem investiga agregação investiga o passado.
      add :token_public_id, :string, null: false

      # Qual porta, e qual alvo. `target_id` é nulo nas listagens — elas não têm alvo, e
      # nulo aqui é **a ausência dita**, nunca um alvo vazio.
      add :route, :string, null: false
      add :target_id, :uuid

      add :occurred_at, :utc_datetime_usec, null: false
    end

    # A consulta que a FR-024 precisa: *"quantas leituras esta credencial fez na janela"*.
    # Sem este índice ela varre a tabela, e uma varredura por chamada é o oposto do que um
    # registro de acesso deve custar.
    create index(:api_access_reads, [:tenant_id, :token_public_id, :occurred_at])
  end
end
