defmodule TheBand.Tenants.ApiTokens do
  @moduledoc """
  O token que abre a API pública — geração, conferência, listagem e revogação.

  Implementação; a fronteira é `TheBand.Tenants`.

  ## A forma do token, e por que ela tem três partes

      tb_api_<id_publico>_<segredo>

  **O prefixo** identifica o token como desta plataforma, para que varredura de segredo em
  repositório, log e histórico de terminal reconheça o vazamento sem saber o valor. Prefixo
  certo com resto inválido recebe a **mesma recusa** de token inexistente: ele serve para
  varrer, nunca para triar validade.

  **O id público** é por onde a linha é buscada — indexado e único. Ele existe porque
  `where: t.token_hash == ^hash` entregaria a comparação ao Postgres, fora do nosso controle
  de tempo, desfazendo a garantia no mesmo gesto que parecia cumpri-la.

  **O segredo** são 32 bytes de gerador criptográfico, em Base64 sem padding e seguro para
  URL. Ele é conferido em memória, com `Plug.Crypto.secure_compare/2`.

  As três partes e o prefixo vêm da base de conhecimento — `api.access.thresholds` —, e não de
  constante de módulo: a tela imprime o prefixo e o varredor de segredo o procura, e duas
  cópias divergem.

  ## Por que `secure_compare` e não `==`

  A sessão compara com `==` e **está certa**: o valor vem de cookie assinado pelo próprio
  servidor, e sem a assinatura não se itera valor para medir tempo.

  Aqui o valor vem **cru de um cabeçalho controlado por quem chama**. O canal de tempo é
  alcançável, e a comparação tem de ser em tempo constante. Ver a ADR 0010.

  ## O que este módulo NÃO expõe

    * `update_api_token/2` — rótulo e expiração não mudam depois de criados. Estender o prazo
      de um token vivo é conceder acesso sem gerar credencial nova, e isso merece decisão
      própria;
    * `delete_api_token/2` — ausência marca, nunca apaga. Um token que sumiu da lista é um
      token que ninguém sabe que existiu;
    * qualquer caminho que devolva o valor em claro de um token já criado — ele não está no
      banco.
  """

  import Ecto.Query

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Repo
  alias TheBand.Tenants.Schemas.ApiAccessToken, as: Token
  alias TheBand.Tenants.Tenant
  alias TheBand.Tenants.User

  @regra "api.access.thresholds"

  # 32 bytes = 256 bits (FR-002). Não há dicionário a percorrer, e é o que dispensa o
  # alongamento de chave — ver a ADR 0010.
  @bytes_do_segredo 32

  # O id público é curto de propósito: ele aparece em índice e em mensagem de depuração, e
  # não carrega poder nenhum — quem o tiver ainda precisa do segredo.
  @bytes_do_id 6

  @doc "O prefixo declarado na base de conhecimento. Nunca uma constante aqui — FR-069."
  @spec prefixo() :: String.t()
  def prefixo do
    case KnowledgeBase.rule(@regra) do
      {:ok, regra} -> get_in(regra, ["vocabulary", "token_prefix", "values", "prefix"])
      _ -> raise "regra #{@regra} ausente da base de conhecimento"
    end
  end

  @doc """
  O prazo máximo, em dias, e se ele é aplicado.

  Devolve o par porque **limiar declarado e não aplicado é pior que limiar ausente se ninguém
  disser qual é qual** — e quem chama precisa saber a diferença.
  """
  @spec limiar(String.t()) :: {integer() | nil, boolean()}
  def limiar(nome) do
    case KnowledgeBase.rule(@regra) do
      {:ok, regra} ->
        r = get_in(regra, ["rules", nome]) || %{}
        valores = Map.get(r, "values", %{})
        {valores |> Map.values() |> List.first(), Map.get(r, "applied", false)}

      _ ->
        raise "regra #{@regra} ausente da base de conhecimento"
    end
  end

  # ----------------------------------------------------------------- a geração

  @doc """
  Gera um token novo e devolve `{:ok, token, valor_em_claro}`.

  **O valor em claro sai daqui e nunca mais.** Ele não é gravado, e a terceira posição da
  tupla é a única vez que ele existe fora da memória de quem chamou.
  """
  @spec criar(Tenant.t(), User.t(), map(), User.t()) ::
          {:ok, Token.t(), String.t()} | {:error, Ecto.Changeset.t()}
  def criar(%Tenant{id: tenant_id}, %User{id: dono_id}, attrs, %User{id: autor_id}) do
    id_publico = gerar(@bytes_do_id)
    segredo = gerar(@bytes_do_segredo)
    valor = prefixo() <> id_publico <> "_" <> segredo

    %Token{}
    |> Token.changeset(%{
      tenant_id: tenant_id,
      user_id: dono_id,
      label: attrs[:label] || attrs["label"],
      public_id: id_publico,
      token_hash: digestao(segredo),
      last_four: String.slice(valor, -4, 4),
      created_by_user_id: autor_id,
      expires_at: expiracao(attrs)
    })
    |> Repo.insert()
    |> case do
      {:ok, token} -> {:ok, %{token | value: valor}, valor}
      {:error, changeset} -> {:error, changeset}
    end
  end

  # O teto vem da base, e um pedido acima dele é **reduzido ao teto**, não recusado: quem
  # pede 365 dias quer o máximo que puder ter, e recusar transformaria isso em erro de
  # formulário sem informação nova.
  defp expiracao(attrs) do
    dias = attrs[:expires_in_days] || attrs["expires_in_days"]
    {maximo, aplicado?} = limiar("token_lifetime")

    cond do
      is_nil(dias) and aplicado? -> DateTime.add(agora(), maximo * 86_400, :second)
      is_nil(dias) -> nil
      aplicado? -> DateTime.add(agora(), min(dias, maximo) * 86_400, :second)
      true -> DateTime.add(agora(), dias * 86_400, :second)
    end
  end

  defp gerar(bytes), do: bytes |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

  defp digestao(segredo), do: :crypto.hash(:sha256, segredo)

  defp agora, do: DateTime.utc_now(:second)

  # ------------------------------------------------------------- a conferência

  @doc """
  Confere um valor apresentado e devolve o token, ou **uma recusa só**.

  `{:error, :recusado}` para inexistente, malformado, revogado, expirado e conta dona
  desativada — FR-016. Quem precisa do motivo real o lê no log interno; distinguir para fora
  confirmaria a quem testa credencial roubada que ela existiu.
  """
  @spec autenticar(String.t()) :: {:ok, Token.t()} | {:error, :recusado}
  def autenticar(valor) when is_binary(valor) do
    with {:ok, id_publico, segredo} <- partes(valor),
         %Token{} = token <- por_id_publico(id_publico),
         true <- confere?(token, segredo),
         :ativo <- Token.estado(token, agora()) do
      {:ok, carimbar(token)}
    else
      _ -> {:error, :recusado}
    end
  end

  def autenticar(_), do: {:error, :recusado}

  # O prefixo é conferido, e um valor sem ele é recusado como qualquer outro. A separação é
  # por `_` **depois** do prefixo, que também contém `_` — por isso o corte é por tamanho, e
  # não por `String.split/2` no valor inteiro.
  defp partes(valor) do
    p = prefixo()

    with true <- String.starts_with?(valor, p),
         resto <- String.replace_prefix(valor, p, ""),
         [id_publico, segredo] <- String.split(resto, "_", parts: 2),
         true <- id_publico != "" and segredo != "" do
      {:ok, id_publico, segredo}
    else
      _ -> :erro
    end
  end

  defp por_id_publico(id_publico) do
    Repo.one(from t in Token, where: t.public_id == ^id_publico)
  end

  # `secure_compare` e nunca `==` — ver o moduledoc.
  defp confere?(%Token{token_hash: gravado}, segredo) do
    Plug.Crypto.secure_compare(gravado, digestao(segredo))
  end

  # A escrita numa leitura é deliberada: sem ela a tela não responde *"esta integração ainda
  # é usada?"*, e token que ninguém sabe se é usado ninguém revoga. Não serializa as chamadas.
  defp carimbar(%Token{} = token) do
    instante = agora()

    from(t in Token, where: t.id == ^token.id)
    |> Repo.update_all(set: [last_used_at: instante])

    %{token | last_used_at: instante}
  end

  # -------------------------------------------------------------- as leituras

  @doc "Os tokens do tenant, com o estado já lido. Revogados INCLUSIVE — a linha fica."
  @spec listar(Tenant.t()) :: [map()]
  def listar(%Tenant{id: tenant_id}) do
    instante = agora()

    Token
    |> where([t], t.tenant_id == ^tenant_id)
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
    |> Enum.map(&%{token: &1, estado: Token.estado(&1, instante)})
  end

  @doc "Um token do tenant, pelo id. De outro tenant devolve `:not_found`, nunca 'sem permissão'."
  @spec buscar(Tenant.t(), Ecto.UUID.t()) :: {:ok, Token.t()} | {:error, :not_found}
  def buscar(%Tenant{id: tenant_id}, id) do
    case Repo.one(from t in Token, where: t.tenant_id == ^tenant_id and t.id == ^id) do
      nil -> {:error, :not_found}
      token -> {:ok, token}
    end
  end

  # ------------------------------------------------------------- a revogação

  @doc """
  Revoga, **marcando**. A linha continua, com data e autor.

  Idempotente: revogar de novo não reescreve o autor da primeira, porque quem revogou foi
  quem revogou. **Não existe reativar** — revogação é definitiva, e o caminho é gerar outro.
  """
  @spec revogar(Tenant.t(), Ecto.UUID.t(), User.t()) ::
          {:ok, Token.t()} | {:error, :not_found}
  def revogar(%Tenant{} = tenant, id, %User{id: autor_id}) do
    with {:ok, token} <- buscar(tenant, id) do
      if token.revoked_at do
        {:ok, token}
      else
        instante = agora()

        {1, _} =
          from(t in Token, where: t.id == ^token.id and is_nil(t.revoked_at))
          |> Repo.update_all(set: [revoked_at: instante, revoked_by_user_id: autor_id])

        {:ok, %{token | revoked_at: instante, revoked_by_user_id: autor_id}}
      end
    end
  end
end
