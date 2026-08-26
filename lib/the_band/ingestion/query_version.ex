defmodule TheBand.Ingestion.QueryVersion do
  @moduledoc """
  Em que versão está cada consulta da coleta, e o que acontece com o já coletado quando ela
  muda — issue #452.

  ## O defeito que este módulo existe para impedir

  O corte incremental responde *"já coletei este registro"*. Quando a consulta ganha um
  campo, a pergunta vira outra: *"já coletei este registro **com esta consulta**"*.

  As duas coincidem até alguém acrescentar campo. A feature 041 acrescentou
  `statusCheckRollup` à consulta de solicitações; duas semanas depois havia **763
  solicitações em 10 repositórios** sem o campo, 100% em cada um dos dez. Nenhum erro, e a
  tela dizia *"não dá para saber"* sobre dado que a origem responde.

  ## Duas peças, e elas fazem coisas diferentes

  **A versão** faz a coleta reabrir o corte uma vez, para quem ficou para trás. É o remédio,
  e vale para as fases listadas em `@versoes`.

  **A impressão digital** faz o teste reprovar quando um arquivo `.graphql` muda sem que
  alguém tenha decidido o que fazer com o já coletado. É a prevenção, e vale para **todos**
  os arquivos de consulta — inclusive os de fases que ainda não têm remédio automático.

  A prevenção sozinha já resolve o silêncio, que era o pior do defeito: quem mudar a
  consulta é obrigado a olhar. O remédio automático poupa o passo manual onde existe.

  ## O que fazer quando o teste reprovar

  Duas saídas, e a escolha é o ponto:

  1. **o campo é novo** — incrementar a versão da fase em `@versoes` **e** atualizar a
     impressão digital. A coleta reabre o corte uma vez por repositório;
  2. **a mudança não acrescenta campo** — só atualizar a impressão digital. Reformatar,
     renomear alias, comentar: nada disso muda o que a origem devolve, e reabrir a coleta
     por causa disso repaginaria o histórico sem motivo.

  Escolher a 2 quando era a 1 recria o defeito. O teste não impede o erro; ele impede que
  o erro seja **silencioso**, que é a diferença que a #452 pede.

  ## O que este módulo NÃO cobre

  - **`verifications`** sai de requisições REST, e não de arquivo `.graphql`. Não há o que
    vigiar por impressão digital, e a mudança de forma continua invisível ali;
  - **`issues`** e **`branches`** têm corte, mas com formas diferentes — `percorrer?/2`
    compara com `last_pushed_at`. Ganham a prevenção pela impressão digital, e não o
    remédio automático;
  - **`reviews_collected_at`** existe na tabela e **ninguém escreve nela**. Coluna morta,
    registrada aqui porque quem for mexer vai encontrá-la.
  """

  # Relativo ao fonte, e resolvido em **tempo de compilação**: `File.read!` com nome vindo
  # de fora aceita `../..`, e o Sobelow reprova com razão. Aqui nada é lido em tempo de
  # execução — não há caminho a atravessar.
  @diretorio Path.expand("../../../priv/connectors/github/queries", __DIR__)

  # Cada consulta é recurso externo: mudar o `.graphql` recompila este módulo, e é isso que
  # faz o teste ver a mudança.
  for arquivo <- Path.wildcard(Path.join(@diretorio, "*.graphql")) do
    @external_resource arquivo
  end

  @atuais (for arquivo <- Path.wildcard(Path.join(@diretorio, "*.graphql")), into: %{} do
             {Path.basename(arquivo, ".graphql"),
              :crypto.hash(:sha256, File.read!(arquivo))
              |> Base.encode16(case: :lower)
              |> binary_part(0, 16)}
           end)

  # A versão de cada fase que tem remédio automático. Incrementar aqui faz a coleta ignorar
  # o corte uma vez, por repositório.
  @versoes %{
    # 2: `statusCheckRollup` entrou na feature 041, e foi o que expôs o defeito.
    "changes" => 2,
    "comments" => 1
  }

  # A impressão digital de cada arquivo de consulta. Muda o arquivo, muda o número, e o
  # teste reprova até alguém decidir se a mudança acrescenta campo.
  @impressoes %{
    "branches" => "70431e741e0a3e11",
    "change_requests" => "1dd8e96a07a3d4ad",
    "issue_comments" => "c3cea59315496c95",
    "issue_types" => "02dd1d6214a74ba7",
    "issues" => "adb2c1bc7548b0ce",
    "organization" => "47dedb4ec75486a8",
    "organization_members" => "d659d90c384e064b",
    "project_boards" => "f274aa21a5d98649",
    "project_items" => "0b825bd39c27b8d5",
    "project_items_full" => "168c0be8d7de2d50",
    "project_iterations" => "19612bdade1b3f3f",
    "pull_request_commits" => "756c217c2cbf8896",
    "repositories" => "89fa9050f685d6cb",
    "team_members" => "7cc577f6ea2453eb",
    "teams" => "8d90c8866fa4fae6"
  }

  @doc "A versão atual da fase. Fase sem remédio automático não está aqui, e falha alto."
  @spec atual(String.t()) :: pos_integer()
  def atual(fase), do: Map.fetch!(@versoes, fase)

  @doc "As fases com remédio automático."
  @spec fases() :: [String.t()]
  def fases, do: Map.keys(@versoes)

  @doc "As impressões digitais declaradas, por nome de arquivo."
  @spec impressoes() :: %{String.t() => String.t()}
  def impressoes, do: @impressoes

  @doc """
  A impressão digital **atual** do arquivo, calculada na compilação.

  Sobre o conteúdo cru: reformatar muda o número, e é de propósito — a decisão de reabrir ou
  não a coleta é de quem mexeu, e não de um comparador tentando adivinhar se a mudança foi
  semântica.

  ## Por que na compilação, e não na leitura

  `File.read!` com nome recebido de fora aceita `../..`, e o Sobelow reprova com razão. Aqui
  os arquivos são `@external_resource`: o Elixir recompila este módulo quando qualquer
  `.graphql` muda, as impressões viram constantes, e **nenhum caminho é montado em tempo de
  execução**.

  O `@external_resource` não é detalhe de desempenho: sem ele, mudar só o `.graphql` não
  recompilaria este módulo, e o teste compararia a impressão antiga contra ela mesma —
  passando enquanto a consulta já era outra.
  """
  @spec impressao_de(String.t()) :: String.t() | nil
  def impressao_de(nome), do: Map.get(@atuais, nome)

  @doc "Os arquivos de consulta que existem no disco, lidos na compilação."
  @spec arquivos() :: [String.t()]
  def arquivos, do: Map.keys(@atuais) |> Enum.sort()

  @doc """
  O corte vale para este repositório, ou a consulta mudou desde a última passagem?

  `false` faz a coleta repaginar o histórico **uma vez**. Na passagem seguinte a versão
  gravada já é a atual, e o corte volta a valer.

  Mapa vazio — repositório coletado antes de a versão existir — também devolve `false`: não
  saber com que versão foi percorrido é o mesmo risco que saber que foi com uma antiga, e
  presumir a atual deixaria de fora justamente quem o defeito atingiu.
  """
  @spec corte_vale?(map() | nil, String.t()) :: boolean()
  def corte_vale?(versoes, fase) do
    case Map.get(versoes || %{}, fase) do
      gravada when is_integer(gravada) -> gravada >= atual(fase)
      _ -> false
    end
  end

  @doc """
  O mapa de versões com a fase atualizada para a versão atual.

  As outras fases são preservadas: acrescentar campo na consulta de solicitações não pode
  fazer os comentários repaginarem.
  """
  @spec marcar(map() | nil, String.t()) :: map()
  def marcar(versoes, fase), do: Map.put(versoes || %{}, fase, atual(fase))
end
