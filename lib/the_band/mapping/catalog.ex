defmodule TheBand.Mapping.Catalog do
  @moduledoc """
  O catálogo de padrões pré-escritos, **composto em leitura** com as regras da organização.

  ## Nada é copiado para o banco

  Copiar o catálogo na conexão criaria 18 linhas por organização no instante do `connect`,
  todas com autor "sistema" — que é o que FR-041 proíbe. Pior: uma atualização do catálogo
  não teria como alcançar as cópias sem sobrescrever edição, e FR-043 proíbe sobrescrever.

  Compor em leitura resolve os dois: a organização só tem linha quando alguém **decidiu**,
  e a ausência de linha significa "nunca decidido" em vez de "cópia intocada".

  ## A chave é `(where, how, pattern)`, nunca o índice

  Reordenar o catálogo não pode desligar decisões já tomadas — e usar a posição na lista
  faria exatamente isso.

  ## Três estados, e a diferença importa

  | Estado | Significa |
  |---|---|
  | `:proposed` | a organização nunca decidiu sobre esta entrada |
  | `:activated` | ativada como está |
  | `:edited` | ativada e alterada — o catálogo permanece como está para as outras |

  ## O catálogo também diz o que **não** é tipo

  `[Devops]`, `[Back-end]`, `[QA]` — 1274 issues cujo prefixo diz quem faz ou em que área.
  Eles aparecem para serem **recusados**, e é o que impede a tela de empurrar o mapeamento
  de área como conceito. Conceito errado é pior que conceito ausente: a medida passa a
  existir e a mentir.
  """

  alias TheBand.Mapping.Queries
  alias TheBand.Mapping.Schemas.MappingRule
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Tenants.Tenant
  alias TheBand.WorkItems.Routing

  @catalogo "github.issue_pattern_catalog"

  @typedoc "Uma entrada do catálogo, composta com o que a organização decidiu."
  @type proposta :: %{
          catalog_key: String.t(),
          where: String.t(),
          how: String.t(),
          pattern: String.t(),
          case_sensitive: boolean(),
          target_concept: String.t(),
          seen: non_neg_integer(),
          note: String.t() | nil,
          state: :proposed | :activated | :edited,
          rule_id: Ecto.UUID.t() | nil,
          would_match: non_neg_integer()
        }

  @doc """
  As propostas do catálogo, compostas com as regras da organização e com a contagem real.

  `would_match` é medido **nas issues desta organização**: a mesma proposta vale 1031 numa
  e zero na outra, e mostrar o número do catálogo faria a tela prometer o que não existe
  aqui.
  """
  @spec list_proposals(Tenant.t(), Ecto.UUID.t()) :: [proposta()]
  def list_proposals(%Tenant{} = tenant, organization_id) do
    regras = Map.new(Queries.list_rules(tenant, organization_id), &{&1.catalog_key, &1})
    issues = Queries.issues_for_decision(tenant, organization_id)

    Enum.map(entradas(), fn entrada ->
      chave = MappingRule.catalog_key(entrada.where, entrada.how, entrada.pattern)
      regra = Map.get(regras, chave)

      entrada
      |> Map.merge(%{
        catalog_key: chave,
        state: estado(entrada, regra),
        rule_id: regra && regra.id,
        would_match: contar(issues, entrada)
      })
    end)
  end

  @doc """
  Os padrões que o catálogo declara **não serem tipo**, com a contagem nesta organização.

  Existem para a tela sugerir a **recusa**, não o mapeamento.
  """
  @spec not_type_patterns(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def not_type_patterns(%Tenant{} = tenant, organization_id) do
    issues = Queries.issues_for_decision(tenant, organization_id)

    for padrao <- get_in(catalogo(), ["not_type_patterns", "patterns"]) || [] do
      texto = padrao["text"]

      %{
        pattern: texto,
        seen_in_catalog: padrao["seen"] || 0,
        would_match: Enum.count(issues, &String.starts_with?(&1.title || "", texto))
      }
    end
  end

  @doc "A razão, em português, de aqueles padrões não serem tipo."
  @spec not_type_reason() :: String.t() | nil
  def not_type_reason, do: get_in(catalogo(), ["not_type_patterns", "reason", "pt-BR"])

  @doc """
  A entrada do catálogo por chave — o que `activate_catalog_rule/4` grava.

  Devolve `:error` quando a chave não existe: uma entrada removida do catálogo não pode ser
  ativada, e o silêncio criaria regra a partir de nada.
  """
  @spec fetch_entry(String.t()) :: {:ok, map()} | :error
  def fetch_entry(catalog_key) do
    Enum.find_value(entradas(), :error, fn entrada ->
      chave = MappingRule.catalog_key(entrada.where, entrada.how, entrada.pattern)
      if chave == catalog_key, do: {:ok, Map.put(entrada, :catalog_key, chave)}
    end)
  end

  # ------------------------------------------------------------------- privados

  # As duas seções viram uma lista só, e a diferença fica no campo `where` — que é o que
  # distingue evidência forte (o campo tipado na ferramenta) de fraca (convenção de
  # escrita no título).
  defp entradas do
    catalogo = catalogo()

    declaradas =
      for e <- catalogo["declared_type_patterns"] || [], do: entrada(e, "declared_type")

    titulos = for e <- catalogo["title_patterns"] || [], do: entrada(e, "title")

    declaradas ++ titulos
  end

  # O catálogo fala o vocabulário da **origem** — `issue_type` é o nome do campo no
  # GitHub. A regra fala o da plataforma: `declared_type` diz *o que aquilo é*, e não
  # onde mora. Traduzir aqui, na fronteira, é o que permite o YAML permanecer legível para
  # quem conhece o GitHub sem que o nome do fornecedor vaze para a tabela.
  defp entrada(e, onde) do
    match = e["match"] || %{}

    %{
      where: normalizar_onde(match["where"] || onde),
      how: match["how"] || "equals",
      pattern: match["text"],
      case_sensitive: match["case_sensitive"] || false,
      target_concept: e["proposes"],
      seen: e["seen"] || 0,
      note: get_in(e, ["note", "pt-BR"])
    }
  end

  defp normalizar_onde("issue_type"), do: "declared_type"
  defp normalizar_onde(outro), do: outro

  defp catalogo do
    case KnowledgeBase.rule(@catalogo) do
      {:ok, regra} -> regra
      :error -> %{}
    end
  end

  # Alterada em relação ao catálogo é `:edited`; igual é `:activated`; sem linha é
  # `:proposed`. A distinção é o que permite a atualização do catálogo respeitar a edição.
  defp estado(_entrada, nil), do: :proposed

  defp estado(entrada, regra) do
    if regra.target_concept == entrada.target_concept and
         regra.case_sensitive == entrada.case_sensitive,
       do: :activated,
       else: :edited
  end

  # A contagem usa a **mesma** comparação que a decisão: uma contagem própria diria um
  # número e a promoção produziria outro.
  defp contar(issues, entrada) do
    regra = %MappingRule{
      where: entrada.where,
      how: entrada.how,
      pattern: entrada.pattern,
      case_sensitive: entrada.case_sensitive,
      target_concept: entrada.target_concept
    }

    campo = if entrada.where == "declared_type", do: :issue_type, else: :title

    Enum.count(issues, &Routing.combina?(regra, Map.get(&1, campo)))
  end
end
