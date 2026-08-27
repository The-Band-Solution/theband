defmodule TheBand.Quality.Verdict do
  @moduledoc """
  Traduz o estado cru da revisão para o conceito da rede — feature 044, T001.

  ## Por que a tradução existe

  `collected_artifact_evaluations.state` guarda o que o GitHub disse: `APPROVED`,
  `CHANGES_REQUESTED`, `COMMENTED`, `DISMISSED`, `PENDING`. Guardar o cru é certo — é o que
  permite conferir a tradução depois. Mas usar **só** o cru prenderia toda medida sobre
  revisão ao enum de um forjador.

  Decisão da pessoa mantenedora em 2026-08-27: mapear para a ontologia, para ser universal.

  ## O mapa vive na BASE, e não aqui

  As correspondências saem do `value_map` de
  `github.pull_request_review.to.qapo.artifact_evaluation`. Reescrevê-las em código criaria
  uma segunda cópia, e duas cópias divergem no dia em que alguém mudar uma só — a semântica
  vive no YAML (princípio IV), e quem pergunta "o que este estado significa" pergunta a ela.

  ## Três posições, e dois estados que NÃO são posição

  `DISMISSED` e `PENDING` não recebem veredito: a primeira é avaliação retirada de
  circulação, a segunda é avaliação que ainda não aconteceu. Tratá-las como um quarto e
  quinto veredito faria "quantas objeções houve" contar rascunho.

  ## Valor fora do mapa devolve ERRO

  `unmapped: reject` está declarado no mapeamento. Traduzir o não reconhecido para o mais
  plausível é o erro que cai para o lado barato: o não reconhecido alguém corrige, o
  reconhecido errado vira medida e ninguém volta para conferir.

  A issue #526 é a tela que muda isso — com os valores não traduzidos visíveis, `keep_raw`
  passa a ser seguro.
  """

  alias TheBand.Ontology.KnowledgeBase

  @mapeamento "github.pull_request_review.to.qapo.artifact_evaluation"

  # O ciclo de vida sai do MESMO campo da origem, e é outra pergunta. Fica aqui e não no
  # `value_map` porque o `value_map` traduz para CONCEITO, e ciclo de vida não é conceito
  # da rede — é estado do registro.
  @ciclo_de_vida %{"DISMISSED" => :retirada, "PENDING" => :nao_submetida}

  @type resultado ::
          {:veredito, String.t()}
          | {:ciclo_de_vida, :retirada | :nao_submetida}
          | {:error, :nao_mapeado}

  @doc """
  O que este estado da origem significa na rede.

      iex> TheBand.Quality.Verdict.traduzir("APPROVED")
      {:veredito, "qapo.endorsing_verdict"}

      iex> TheBand.Quality.Verdict.traduzir("DISMISSED")
      {:ciclo_de_vida, :retirada}

      iex> TheBand.Quality.Verdict.traduzir("SOMETHING_NEW")
      {:error, :nao_mapeado}
  """
  @spec traduzir(String.t() | nil) :: resultado()
  def traduzir(nil), do: {:error, :nao_mapeado}

  def traduzir(estado) do
    case Map.fetch(@ciclo_de_vida, estado) do
      {:ok, ciclo} -> {:ciclo_de_vida, ciclo}
      :error -> como_veredito(estado)
    end
  end

  @doc """
  Os estados que a base traduz para veredito — para a consulta filtrar por eles.

  Existe para que a consulta que conta vereditos não repita a lista: ela pergunta aqui, e
  acrescentar um estado ao YAML passa a valer sem tocar em Elixir.
  """
  @spec estados_de_veredito() :: [String.t()]
  def estados_de_veredito, do: Map.keys(mapa())

  @doc """
  O rótulo que a tela mostra para cada conceito — T002.

  **Nenhum rótulo repete o enum do GitHub** (`FR-007`): a página nomeia pelo conceito da
  rede, e `APPROVED` não aparece em lugar nenhum da interface.
  """
  @spec rotulo(String.t()) :: String.t()
  def rotulo("qapo.endorsing_verdict"), do: "endorsed"
  def rotulo("qapo.objecting_verdict"), do: "objected"
  def rotulo("qapo.abstaining_verdict"), do: "abstained"
  def rotulo(outro), do: outro

  # --------------------------------------------------------------------------- privadas

  defp como_veredito(estado) do
    case Map.fetch(mapa(), estado) do
      {:ok, conceito} -> {:veredito, conceito}
      :error -> {:error, :nao_mapeado}
    end
  end

  # Base sem o mapeamento devolve mapa vazio, e com isso TODO estado vira `:nao_mapeado`.
  # É o desfecho certo: sem a declaração, a plataforma não sabe o que os estados
  # significam, e adivinhar seria pior que recusar.
  defp mapa do
    case KnowledgeBase.mapping(@mapeamento) do
      {:ok, m} -> get_in(m, ["attributes", "state", "value_map", "values"]) || %{}
      :error -> %{}
    end
  end
end
