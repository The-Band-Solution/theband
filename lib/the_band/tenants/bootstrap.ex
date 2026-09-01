defmodule TheBand.Tenants.Bootstrap do
  @moduledoc """
  A primeira conta nasce do ambiente — feature 052, contrato em
  `specs/052-primeira-conta-do-ambiente/contracts/primeira-conta.md`.

  ## Por que isto existe

  Uma instalação nova sobe com o banco vazio e **ninguém consegue entrar**. Não é
  descuido: o `seeds.exs` levanta em produção de propósito — senha padrão
  conhecida seria a porta aberta que a feature 045 existe para fechar — e
  `/accounts` pressupõe que já exista alguém administrando. Numa instalação nova
  não existe.

  Sem este módulo, o caminho é abrir um console dentro do contêiner e colar
  Elixir: passo manual, sem registro, que o runbook não descreve e que ninguém
  lembra seis meses depois.

  ## Ela devolve um relator, e NÃO imprime

  Quem imprime é `TheBand.Release.semear_primeira_conta/0`. A separação é o que
  torna esta função testável sem inspecionar log — a L69 registra que defeito
  dentro de `Logger.info` é invisível a teste por configuração, e os casos que a
  spec precisa provar (variável ausente NOMEADA, regra recusada NOMEADA, "já
  existe" DITO) viram asserção sobre valor de retorno.

  ## Nenhum lock, nenhuma migração

  Duas subidas simultâneas não produzem dois administradores, e a garantia é do
  **banco**: `unique_index(:tenants, [:slug])` e `unique_index(:users, [:email])`
  existem desde a primeira migração do projeto. As duas subidas leem AS MESMAS
  variáveis, então disputam o mesmo slug e o mesmo e-mail — uma passa, e a outra
  lê a violação de unicidade como instalação já feita.

  Se alguém sentir necessidade de `pg_advisory_xact_lock` aqui, vale reler o
  `research.md` R1 antes: o mecanismo a mais protegeria contra uma corrida que os
  índices já barram.
  """

  import Ecto.Query

  alias TheBand.Repo
  alias TheBand.Tenants.Tenant
  alias TheBand.Tenants.User

  @typedoc "O que a criação devolve. A senha NUNCA aparece aqui."
  @type relator ::
          {:ok, :criada, %{email: String.t(), slug: String.t()}}
          | {:ok, :ja_existe}
          | {:error, {:faltando, [atom()]}}
          | {:error, Ecto.Changeset.t()}

  # A lista é FECHADA (contrato). Variável nova aqui é mudança de contrato.
  @obrigatorias [
    nome: "THE_BAND_TENANT_NOME",
    slug: "THE_BAND_TENANT_SLUG",
    email: "THE_BAND_ADMIN_EMAIL",
    senha: "THE_BAND_ADMIN_SENHA"
  ]

  @opcional_nome_da_pessoa "THE_BAND_ADMIN_NOME"

  @doc """
  Cria a organização e o primeiro administrador, se não houver nenhum.

  O parâmetro `ambiente` existe para o teste injetar valores sem tocar no
  ambiente do processo: `System.put_env/2` num teste assíncrono vaza para os
  outros, e o defeito aparece em outro arquivo.
  """
  @spec criar_primeira_conta((String.t() -> String.t() | nil)) :: relator()
  def criar_primeira_conta(ambiente \\ &System.get_env/1) do
    # A consulta de existência vem ANTES de ler o ambiente e de abrir transação:
    # no caminho comum — instalação já feita — a função faz uma consulta e para.
    if ja_ha_administrador?() do
      {:ok, :ja_existe}
    else
      with {:ok, valores} <- ler(ambiente) do
        criar(valores)
      end
    end
  end

  # A pergunta é "existe ALGUM administrador", nunca "existe este e-mail" —
  # FR-002. Trocar o e-mail na variável não cria uma segunda conta; para isso
  # existe `/accounts`, onde fica registrado quem criou quem.
  defp ja_ha_administrador? do
    Repo.exists?(from(u in User, where: u.role == "admin"))
  end

  defp ler(ambiente) do
    valores =
      Map.new(@obrigatorias, fn {chave, variavel} ->
        {chave, presente(ambiente.(variavel))}
      end)

    case Enum.filter(valores, fn {_chave, valor} -> is_nil(valor) end) do
      [] ->
        {:ok, Map.put(valores, :nome_da_pessoa, presente(ambiente.(@opcional_nome_da_pessoa)))}

      faltando ->
        # A lista traz TODAS as ausentes, e não a primeira: quem esqueceu duas
        # variáveis descobre as duas numa subida, e não em duas.
        {:error, {:faltando, faltando |> Enum.map(&elem(&1, 0)) |> Enum.sort()}}
    end
  end

  defp presente(nil), do: nil

  defp presente(valor) when is_binary(valor),
    do: if(String.trim(valor) == "", do: nil, else: valor)

  # Transação direta, e não `Ecto.Multi`: são três passos sequenciais em que
  # nenhum nome de etapa interessa a ninguém depois. Multi resolve o problema de
  # compor operações nomeadas e inspecionar qual falhou — problema que aqui não
  # existe, e cujo custo seria uma indireção a mais para quem lê (princípio VIII).
  defp criar(valores) do
    Repo.transaction(fn ->
      with {:ok, tenant} <- organizacao(valores),
           {:ok, user} <- Repo.insert(conta(tenant, valores)),
           {:ok, _} <- Repo.update(User.senha_changeset(user, %{password: valores.senha})) do
        %{email: valores.email, slug: valores.slug}
      else
        {:error, %Ecto.Changeset{} = changeset} -> Repo.rollback(changeset)
      end
    end)
    |> case do
      {:ok, dados} ->
        {:ok, :criada, dados}

      {:error, %Ecto.Changeset{} = changeset} ->
        # Violação de unicidade é a corrida perdida, não erro de quem configurou:
        # a outra subida criou primeiro. O relator diz o que de fato aconteceu.
        if corrida_perdida?(changeset),
          do: {:ok, :ja_existe},
          else: {:error, sem_a_senha(changeset)}
    end
  end

  # Organização com este slug já existente é REAPROVEITADA (FR-011): um banco
  # restaurado pode ter organizações e nenhum administrador, e criar uma segunda
  # deixaria a instalação sem caminho de entrada — o problema que esta feature
  # existe para eliminar.
  defp organizacao(%{slug: slug} = valores) do
    case Repo.get_by(Tenant, slug: slug) do
      %Tenant{} = existente ->
        {:ok, existente}

      nil ->
        %Tenant{}
        |> Tenant.changeset(%{"name" => valores.nome, "slug" => slug})
        |> Repo.insert()
    end
  end

  defp conta(%Tenant{id: tenant_id}, valores) do
    User.changeset(%User{}, %{
      "email" => valores.email,
      "name" => valores.nome_da_pessoa,
      "role" => "admin",
      "tenant_id" => tenant_id
    })
  end

  defp corrida_perdida?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn {campo, {_msg, opts}} ->
      campo in [:slug, :email] and Keyword.get(opts, :constraint) == :unique
    end)
  end

  # O campo virtual de senha sai do changeset devolvido. A proteção fica no
  # FORMATO do dado, e não na disciplina de quem escreve o `IO.puts` adiante —
  # FR-006.
  defp sem_a_senha(%Ecto.Changeset{data: %User{}} = changeset) do
    %{limpo(changeset) | data: %{changeset.data | password: nil}}
  end

  # A recusa pode vir do `Tenant.changeset` — slug fora do formato —, e ali o
  # `data` é um `Tenant`, que não tem campo de senha. Limpar params e changes
  # basta: a senha nunca chegou a esse changeset.
  defp sem_a_senha(%Ecto.Changeset{} = changeset), do: limpo(changeset)

  defp limpo(%Ecto.Changeset{} = changeset) do
    %{
      changeset
      | params: Map.delete(changeset.params || %{}, "password"),
        changes: Map.delete(changeset.changes, :password)
    }
  end
end
