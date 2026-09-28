defmodule TheBand.Segredo.Padroes do
  @moduledoc """
  Os padrões de segredo, **em um lugar só** — feature 064, T001, FR-014.

  Padrão espalhado por script diverge, e a divergência aparece como "zero" no script que ficou
  para trás. Por isso a varredura (`mix the_band.varre_segredos`) lê **daqui**, e acrescentar um
  tipo de segredo ao sistema exige acrescentá-lo aqui antes de existir coluna para ele.

  ## `onde`: o padrão com prefixo vale em qualquer lugar, o sem prefixo só na coluna dele

  Medido em 2026-09-28 no dump de desenvolvimento: a forma do token de sessão (43 caracteres
  base64url) casou **5 928** vezes, e só **2** eram token de sessão. Por isso ele declara a
  coluna em que vive, e só ali é procurado. Os padrões com prefixo casaram **0** vezes no mesmo
  dump, e valem em qualquer lugar. Ver `contracts/varre-segredos.md`.

  ## `exemplo_valido` é material do controle positivo

  A varredura planta cada exemplo no material e confirma que o acha (T003). Por isso cada
  exemplo casa **o próprio** padrão e nenhum outro, e há teste disso.

  Os exemplos são **montados**, e não escritos por extenso: um literal com a forma de um token do
  GitHub dispara a varredura de segredos do próprio GitHub no push. Nenhum deles é credencial.
  """

  @typedoc "Onde o padrão é procurado: em qualquer texto, ou só em colunas declaradas."
  @type onde :: :qualquer | [{tabela :: String.t(), coluna :: String.t()}]

  @typedoc "Um tipo de segredo que a plataforma guarda ou manipula."
  @type t :: %{
          tipo: atom(),
          nome: String.t(),
          regex: Regex.t(),
          exemplo_valido: String.t(),
          onde: onde()
        }

  @doc "Os padrões declarados, na ordem do relatório."
  @spec todos() :: [t()]
  def todos do
    [
      %{
        tipo: :token_github,
        nome: "token do GitHub",
        # Clássico (`ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_` e 36) e de granulação fina
        # (`github_pat_` e 82). As fronteiras impedem casar dentro de um identificador maior.
        regex:
          ~r/(?<![A-Za-z0-9_])(?:gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{82})(?![A-Za-z0-9_])/,
        exemplo_valido: "gh" <> "p_" <> String.duplicate("T", 32) <> "band",
        onde: :qualquer
      },
      %{
        tipo: :chave_provedor_de_modelos,
        nome: "chave de provedor de modelos",
        regex: ~r/(?<![A-Za-z0-9_-])sk-(?:proj-)?[A-Za-z0-9_-]{20,}(?![A-Za-z0-9_-])/,
        exemplo_valido: "sk" <> "-proj-" <> String.duplicate("M", 36) <> "band",
        onde: :qualquer
      },
      %{
        tipo: :token_de_sessao,
        nome: "token de sessão (43 caracteres, em users.session_token)",
        # O CAMPO INTEIRO, e não um trecho: é a forma de `User.novo_token/0`
        # (`Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)`).
        regex: ~r/\A[A-Za-z0-9_-]{43}\z/,
        exemplo_valido: String.duplicate("S", 39) <> "band",
        onde: [{"users", "session_token"}]
      }
    ]
  end

  @doc "Se o padrão vale para aquela tabela e coluna."
  @spec vale_em?(t(), String.t(), String.t()) :: boolean()
  def vale_em?(%{onde: :qualquer}, _tabela, _coluna), do: true
  def vale_em?(%{onde: colunas}, tabela, coluna), do: {tabela, coluna} in colunas
end
