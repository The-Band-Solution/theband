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
  O valor declarado de um limiar, **nomeado**, e se o limiar é aplicado.

  Devolve o par porque **limiar declarado e não aplicado é pior que limiar ausente se ninguém
  disser qual é qual** — e quem chama precisa saber a diferença.

  ## A chave é obrigatória, e isso é conserto

  Até 2026-09-23 esta função lia `values |> Map.values() |> List.first()` — o **primeiro**
  valor do mapa. Mapa pequeno em Elixir devolve os valores na ordem dos termos das chaves, o
  que não é a ordem do YAML: acrescentar um valor cuja chave ordene antes troca, em silêncio,
  o número que a tela imprime.

  Não é hipótese. Ao declarar o alcance do aviso de vencimento — `reach: tela` ao lado de
  `warning_days: 14` —, `"reach"` ordena antes de `"warning_days"`, e a tela passaria a
  imprimir **"tela days"**. As outras quatro regras vinham acertando por acaso.

  Chave ausente **levanta**. Devolver `nil` aqui produziria "nil days" numa tela, e um limiar
  que some sem barulho é pior do que um que reprova o boot.
  """
  @spec limiar(String.t(), String.t()) :: {term(), boolean()}
  def limiar(nome, chave) do
    case KnowledgeBase.rule(@regra) do
      {:ok, regra} ->
        r = get_in(regra, ["rules", nome]) || raise "limiar #{nome} ausente de #{@regra}"
        valores = Map.get(r, "values", %{})

        unless Map.has_key?(valores, chave) do
          raise "limiar #{nome} não declara o valor #{chave} em #{@regra} — " <>
                  "declarados: #{valores |> Map.keys() |> Enum.sort() |> Enum.join(", ")}"
        end

        {Map.fetch!(valores, chave), Map.get(r, "applied", false)}

      _ ->
        raise "regra #{@regra} ausente da base de conhecimento"
    end
  end

  @doc """
  As cláusulas de revogação, **na ordem declarada** na base de conhecimento.

  A ordem importa: é a ordem do select na tela, e a primeira é a que alguém escolhe sem
  pensar. `integracao_encerrada` vem primeiro porque é o caso comum e o mais barato de errar;
  `suspeita_de_vazamento` vem em seguida porque é a que muda o próximo ato.
  """
  @spec clausulas_de_revogacao() :: [String.t()]
  def clausulas_de_revogacao do
    valores_da_revogacao()["clausulas"] ||
      raise "regra #{@regra} não declara as cláusulas de revogação"
  end

  @doc """
  As cláusulas com o texto da tela, na ordem declarada: `[{id, rótulo}]`.

  O rótulo vem da base pela mesma razão que a lista: a opção do select, a cláusula gravada e
  a linha do relatório têm de ser **a mesma coisa**. Cláusula sem rótulo declarado imprime o
  identificador — feio de propósito, porque é assim que alguém repara e declara o que falta,
  em vez de a tela inventar uma tradução.
  """
  @spec clausulas_com_rotulo(String.t()) :: [{String.t(), String.t()}]
  def clausulas_com_rotulo(idioma \\ "en") do
    rotulos = valores_da_revogacao()["rotulos"] || %{}

    Enum.map(clausulas_de_revogacao(), fn id ->
      {id, get_in(rotulos, [id, idioma]) || id}
    end)
  end

  defp valores_da_revogacao do
    case KnowledgeBase.rule(@regra) do
      {:ok, regra} ->
        get_in(regra, ["rules", "token_revocation_reason", "values"]) || %{}

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
    id_publico = gerar_id_publico(@bytes_do_id)
    segredo = gerar_segredo(@bytes_do_segredo)
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
  #
  # ## Não pedir e pedir "sem prazo" são coisas diferentes — 2026-09-23
  #
  # Desde que "sem expiração" passou a ser oferecido (Q1), `nil` é uma **escolha**, e não
  # mais "não informou". Colapsar as duas faria toda chamada que omite o campo — a API
  # interna, um seed, um teste — gerar token eterno **em silêncio**, que é exatamente o
  # estrago que a regra anterior existia para evitar.
  #
  # Por isso a pergunta é `Map.has_key?`, e não `is_nil`: **chave ausente** cai no teto, como
  # sempre caiu; **chave presente com nada dentro** é a escolha explícita de não expirar.
  defp expiracao(attrs) do
    {maximo, aplicado?} = limiar("token_lifetime", "max_days")

    case dias_pedidos(attrs) do
      :nao_pediu when aplicado? -> DateTime.add(agora(), maximo * 86_400, :second)
      :nao_pediu -> nil
      :sem_prazo -> nil
      dias when aplicado? -> DateTime.add(agora(), min(dias, maximo) * 86_400, :second)
      dias -> DateTime.add(agora(), dias * 86_400, :second)
    end
  end

  defp dias_pedidos(attrs) do
    cond do
      Map.has_key?(attrs, :expires_in_days) -> vazio_e_sem_prazo(attrs[:expires_in_days])
      Map.has_key?(attrs, "expires_in_days") -> vazio_e_sem_prazo(attrs["expires_in_days"])
      true -> :nao_pediu
    end
  end

  defp vazio_e_sem_prazo(nil), do: :sem_prazo
  defp vazio_e_sem_prazo(""), do: :sem_prazo
  defp vazio_e_sem_prazo(dias), do: dias

  # O SEGREDO em Base64 seguro para URL — alfabeto largo, cabe num cabeçalho sem escape.
  defp gerar_segredo(bytes),
    do: bytes |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

  # O ID PÚBLICO em hexadecimal, e a diferença de alfabeto é a correção de um defeito real.
  #
  # Ele usava o mesmo Base64 seguro para URL do segredo — cujo alfabeto **contém `_`**, que é
  # justamente o separador das três partes do token. Quando o `_` caía dentro do id, o parser
  # cortava no lugar errado, a busca não achava a linha, e o token nascia inválido.
  #
  # **Medido em 2026-09-20: 1 150 de 10 000 ids continham `_` — 11,5%, um em cada nove.**
  # Passou nos meus gates locais por sorte e reprovou no CI, que é o que a aleatoriedade faz
  # com quem confia numa execução só.
  #
  # Hexadecimal não tem `_` nem `-`, e é o que torna o corte impossível de errar. Doze
  # caracteres para seis bytes.
  defp gerar_id_publico(bytes),
    do: bytes |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower)

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
      # **O MOTIVO É DEVOLVIDO, e não descartado.**
      #
      # A versão anterior tinha `_ -> {:error, :recusado}`, e com isso token inexistente,
      # revogado e expirado produziam a MESMA entrada no log: `motivo=credencial_recusada`.
      # É o SC-004 da spec 061, e ele reprovou na aceitação de 2026-09-23.
      #
      # A informação já existia: `Token.estado/2` calcula `:revogado` e `:expirado`, e o
      # `_` a jogava fora uma linha antes de chegar a quem opera.
      #
      # **A resposta ao cliente NÃO muda, e isso é obrigatório**: o SC-003 exige que as três
      # produzam respostas byte a byte idênticas. Distinguir ali confirmaria a quem testa
      # uma credencial roubada que ela um dia existiu. A distinção serve a quem investiga,
      # e é por isso que ela vive no log interno e não no corpo.
      :erro -> {:error, :malformado}
      nil -> {:error, :inexistente}
      false -> {:error, :segredo_errado}
      estado when is_atom(estado) -> {:error, estado}
    end
  end

  def autenticar(_), do: {:error, :malformado}

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
  Revoga, **marcando**, com a razão. A linha continua, com data, autor e cláusula.

  Idempotente: revogar de novo não reescreve o autor nem a razão da primeira, porque quem
  revogou foi quem revogou e pelo motivo que disse. **Não existe reativar** — revogação é
  definitiva, e o caminho é gerar outro.

  A cláusula é **obrigatória** desde 2026-09-23 (Q4) e casada contra a lista fechada da base
  de conhecimento; a nota é livre e opcional. `{:error, changeset}` quando a cláusula não está
  na lista — recusa, nunca gravação silenciosa de uma razão que ninguém vai conseguir contar.
  """
  @spec revogar(Tenant.t(), Ecto.UUID.t(), User.t(), map()) ::
          {:ok, Token.t()} | {:error, :not_found} | {:error, Ecto.Changeset.t()}
  def revogar(%Tenant{} = tenant, id, %User{id: autor_id}, razao) do
    with {:ok, token} <- buscar(tenant, id) do
      if token.revoked_at do
        {:ok, token}
      else
        attrs =
          Map.merge(
            %{revoked_at: agora(), revoked_by_user_id: autor_id},
            Map.take(razao, [:revocation_clause, :revocation_note])
          )

        token
        |> Token.revogacao_changeset(attrs, clausulas_de_revogacao())
        |> Ecto.Changeset.apply_action(:update)
        |> gravar_revogacao(tenant, token)
      end
    end
  end

  # **A condição fica no `WHERE`, e não numa leitura anterior.** Duas revogações simultâneas
  # passam as duas pelo `if token.revoked_at` acima — a leitura é de antes —, e sem o
  # `is_nil` aqui a segunda reescreveria o autor e a razão da primeira.
  #
  # Zero linhas afetadas é resposta, não erro: alguém revogou primeiro. Devolvemos o que
  # **está** gravado, relendo, porque quem revogou foi quem revogou.
  defp gravar_revogacao({:error, %Ecto.Changeset{}} = erro, _tenant, _token), do: erro

  defp gravar_revogacao({:ok, revogado}, tenant, token) do
    campos = [
      revoked_at: revogado.revoked_at,
      revoked_by_user_id: revogado.revoked_by_user_id,
      revocation_clause: revogado.revocation_clause,
      revocation_note: revogado.revocation_note
    ]

    case Repo.update_all(
           from(t in Token, where: t.id == ^token.id and is_nil(t.revoked_at)),
           set: campos
         ) do
      {1, _} -> {:ok, revogado}
      {0, _} -> buscar(tenant, token.id)
    end
  end
end
