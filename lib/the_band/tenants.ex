defmodule TheBand.Tenants do
  @moduledoc """
  Organizações clientes e suas pessoas usuárias.

  Toda função de leitura de dado coletado, em qualquer módulo, recebe um
  `%Tenant{}` — nunca o busca do dicionário de processo. É o que torna o filtro
  de tenant verificável em revisão em vez de presumido (constituição, princípio V).
  """

  import Ecto.Query

  alias TheBand.Repo
  alias TheBand.Tenants.Access
  alias TheBand.Tenants.Access.ScopeGrant
  alias TheBand.Tenants.AccessEvents
  alias TheBand.Tenants.AccountDisablement
  alias TheBand.Tenants.AccountLifecycle
  alias TheBand.Tenants.Auth
  alias TheBand.Tenants.Tenant
  alias TheBand.Tenants.User

  # Feature 045 — contratos em specs/045-autenticacao-e-acesso/contracts/.
  defdelegate authenticate(identificador, senha), to: Auth
  defdelegate set_password(tenant, user_id, senha), to: Auth
  defdelegate change_password(tenant, user_id, atual, nova), to: Auth
  defdelegate reset_password(tenant, user_id, actor_id), to: Auth
  defdelegate cadastrar_conta(tenant, attrs, actor), to: Auth

  defdelegate scopes(tenant, user), to: Access
  defdelegate pode_gerir_estrutura(tenant, user, team_id), to: Access
  defdelegate pode_ver(tenant, user, person_id), to: Access
  defdelegate pessoas_alcancadas(tenant, user), to: Access
  defdelegate pode_ver_equipe(tenant, user, team_id), to: Access
  defdelegate grant_scope(tenant, user_id, level, target_id, actor), to: Access, as: :grant
  defdelegate revoke_scope(tenant, grant_id, actor), to: Access, as: :revoke
  defdelegate operacional?(tenant, user), to: Access

  @spec list_tenants() :: [Tenant.t()]
  def list_tenants, do: Repo.all(from t in Tenant, order_by: t.name)

  @spec fetch(Ecto.UUID.t()) :: {:ok, Tenant.t()} | {:error, :not_found}
  def fetch(id) do
    case Repo.get(Tenant, id) do
      nil -> {:error, :not_found}
      tenant -> {:ok, tenant}
    end
  end

  @spec get_by_slug(String.t()) :: Tenant.t() | nil
  def get_by_slug(slug), do: Repo.get_by(Tenant, slug: slug)

  @spec create_tenant(map()) :: {:ok, Tenant.t()} | {:error, Ecto.Changeset.t()}
  def create_tenant(attrs) do
    %Tenant{} |> Tenant.changeset(attrs) |> Repo.insert()
  end

  @spec list_users(Tenant.t()) :: [User.t()]
  def list_users(%Tenant{id: tenant_id}) do
    Repo.all(from u in User, where: u.tenant_id == ^tenant_id, order_by: u.email)
  end

  @doc """
  As pessoas do tenant, por id.

  Existe para a tela resolver **quem** tomou uma decisão registrada — encerrar uma
  sincronização presa, por exemplo — sem uma consulta por linha.
  """
  @spec users_by_id(Tenant.t()) :: %{Ecto.UUID.t() => User.t()}
  def users_by_id(%Tenant{} = tenant), do: Map.new(list_users(tenant), &{&1.id, &1})

  @spec list_all_users() :: [User.t()]
  def list_all_users do
    Repo.all(from u in User, order_by: u.email, preload: [:tenant])
  end

  @spec fetch_user(Ecto.UUID.t()) :: {:ok, User.t()} | {:error, :not_found}
  def fetch_user(id) do
    case Repo.get(User, id) |> Repo.preload(:tenant) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  @spec create_user(Tenant.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def create_user(%Tenant{id: tenant_id}, attrs) do
    %User{}
    |> User.changeset(Map.put(attrs, "tenant_id", tenant_id))
    |> Repo.insert()
  end

  @doc """
  A própria pessoa edita o próprio nome (feature 045, FR-012). SÓ o nome: e-mail
  identifica a entrada, papel é gestão, elo é acesso — cada um tem o seu ato.
  """
  @spec update_name(Tenant.t(), Ecto.UUID.t(), String.t()) ::
          {:ok, User.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_name(%Tenant{id: tenant_id}, user_id, nome) do
    with {:ok, user} <- usuaria_do_tenant(tenant_id, user_id) do
      user
      |> Ecto.Changeset.cast(%{name: nome}, [:name])
      |> Repo.update()
      |> case do
        {:ok, atualizada} -> {:ok, Repo.preload(atualizada, :tenant)}
        erro -> erro
      end
    end
  end

  @doc """
  A conta com elo VIGENTE para esta pessoa, ou nil — feature 051, contrato
  `contas-e-elo.md`. Leitura estreita chamada SÓ no caminho do `{:error, :taken}`
  de `declare_person/4`, para a recusa nomear a conta dona (cenário 3 da US2);
  zero custo no caminho feliz. A corrida continua segura pelo índice único parcial
  — esta função dá o NOME, o banco dá a garantia.
  """
  @spec user_of_person(Tenant.t(), Ecto.UUID.t()) :: User.t() | nil
  def user_of_person(%Tenant{id: tenant_id}, person_id) do
    Repo.one(
      from u in User,
        where:
          u.tenant_id == ^tenant_id and u.person_id == ^person_id and
            is_nil(u.person_revoked_at)
    )
  end

  @doc """
  Declara qual pessoa observada é esta conta — issue #369, FR-012c.

  O elo é o que permite a plataforma responder "esse painel é o seu" e "essa pessoa é da
  equipe que você lidera". Sem ele, nenhum dos três casos da regra de visibilidade é
  computável — nem o da própria pessoa.

  ## Quem pode chamar

  Esta função NÃO verifica papel de plataforma. Quem chama é responsável por exigir admin, e
  a tela exige — a verificação vive lá porque é lá que a pessoa está, e um segundo lugar de
  autorização é um lugar a mais para divergir.

  **O elo concede visibilidade.** Apontar a própria conta para outra pessoa observada é
  passar a ver o painel dela. Não é campo de cadastro: é ato de acesso.

  ## Substituir revoga antes

  Declarar sobre um elo vigente encerra o anterior e grava o novo na mesma transação. Sem
  isso, uma falha entre as duas deixaria a conta sem elo algum, e ela perderia o próprio
  painel sem nada ter sido pedido.
  """
  @spec declare_person(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, User.t()} | {:error, :not_found | :taken | Ecto.Changeset.t()}
  def declare_person(%Tenant{id: tenant_id}, user_id, person_id, actor_id) do
    with {:ok, user} <- usuaria_do_tenant(tenant_id, user_id) do
      user
      |> gravar_elo(person_id, actor_id)
      |> desfecho_do_elo()
    end
  end

  defp gravar_elo(user, person_id, actor_id),
    do: Repo.transaction(fn -> aplicar_elo(user, person_id, actor_id) end)

  defp aplicar_elo(user, person_id, actor_id) do
    agora = DateTime.utc_now(:second)
    user = encerrar_elo_vigente(user, actor_id, agora)

    user
    |> User.elo_da_pessoa_changeset(%{
      person_id: person_id,
      person_declared_by_user_id: actor_id,
      person_declared_at: agora,
      person_revoked_by_user_id: nil,
      person_revoked_at: nil
    })
    |> Repo.update()
    |> case do
      {:ok, atualizada} -> atualizada
      {:error, erro} -> Repo.rollback(erro)
    end
  end

  # Recarregar entre revogar e declarar não é zelo: `revogar_elo/3` escreve por
  # `update_all`, e a struct em memória fica velha. Um campo cujo valor novo é igual ao da
  # struct velha NÃO entra nas mudanças do changeset — enquanto o banco já o mudou. É assim
  # que `person_declared_by_user_id` ficaria nulo com `person_id` preenchido, violando a
  # CHECK que existe justamente para impedir isso.
  defp encerrar_elo_vigente(user, actor_id, agora) do
    if User.elo_vigente?(user) do
      revogar_elo(user, actor_id, agora)
      Repo.get!(User, user.id)
    else
      user
    end
  end

  defp desfecho_do_elo({:ok, atualizada}), do: {:ok, atualizada}
  defp desfecho_do_elo({:error, %Ecto.Changeset{} = cs}), do: {:error, conflito(cs)}
  defp desfecho_do_elo(outro), do: outro

  @doc """
  Revoga o elo. Marca, e nunca apaga.

  "Desde quando essa conta via esse painel" só tem resposta se o encerramento preservar o
  começo — e retirar acesso é justamente o que se audita. Por isso `person_id` FICA, e é
  `person_revoked_at` que o tira de circulação.
  """
  @spec revoke_person(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, User.t()} | {:error, :not_found | :not_declared}
  def revoke_person(%Tenant{id: tenant_id}, user_id, actor_id) do
    with {:ok, user} <- usuaria_do_tenant(tenant_id, user_id) do
      if User.elo_vigente?(user) do
        revogar_elo(user, actor_id, DateTime.utc_now(:second))
        {:ok, Repo.get!(User, user.id)}
      else
        {:error, :not_declared}
      end
    end
  end

  @doc """
  Desativa uma conta — achado **H3, parte B**, 2026-09-09.

  ## O que este ato é, e o que ele NÃO é

  É *"esta conta não entra mais"*. **Não** é `revoke_person/3`, que significa *"não
  sabemos mais qual pessoa observada é esta conta"* — e o H3 mediu que aquele **não
  remove acesso**: com o elo revogado, o login por e-mail continua funcionando e as
  telas do tenant continuam abrindo.

  Juntar os dois seria o erro que a FR-012f já separou.

  ## Episódio, e nunca marca solta

  Abre uma linha em `account_disablements` com autor, instante, **razão** e nota; a
  reativação **fecha** a mesma linha, sem tocar na abertura. `users.disabled_at`
  continua existindo como a resposta rápida a *"pode entrar?"*, lida a cada entrada —
  as duas escritas acontecem na mesma transação, e por isso não podem discordar.

  O par de colunas sozinho cabia **um** episódio, e a reativação o **apagava**.

  ## A razão é exigida, e vem do vocabulário declarado

  `razao` é um mapa com `"reason"` e `"note"`. A cláusula tem de estar em
  `access.account_lifecycle`, e a nota é obrigatória para as que aquele arquivo declara —
  hoje `suspected_compromise` e `other`. Sem o vocabulário carregado, o ato recusa com
  `{:error, :vocabulario_nao_declarado}` em vez de gravar razão nenhuma.

  ## E gira o token de sessão

  Sem o giro, a sessão aberta continuaria servindo até expirar por inatividade, e
  "desativar" significaria "desativar daqui a sete dias".

  ## Quem não pode ser desativada

  **A própria conta que executa o ato** — desativar-se a si é ficar de fora sem ter a
  quem pedir de volta, e num tenant com uma administração só isso tranca a organização
  inteira. Devolve `{:error, :nao_pode_desativar_a_si}`.
  """
  @spec disable_user(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t(), map()) ::
          {:ok, User.t()}
          | {:error,
             :not_found
             | :ja_desativada
             | :nao_pode_desativar_a_si
             | :vocabulario_nao_declarado
             | Ecto.Changeset.t()}
  def disable_user(%Tenant{id: tenant_id}, user_id, actor_id, razao) when is_map(razao) do
    with {:ok, user} <- usuaria_do_tenant(tenant_id, user_id),
         :ok <- nao_e_a_si(user_id, actor_id),
         :ok <- ainda_ativa(user),
         :ok <- vocabulario_declarado() do
      desativar_na_transacao(user, tenant_id, actor_id, razao)
    end
  end

  # As duas escritas na MESMA transação, e é o que impede o estado inválido: `disabled_at`
  # nulo com episódio aberto, ou episódio nenhum com a conta desativada. A coluna é a
  # resposta rápida a *"pode entrar?"*; o episódio é o registro.
  defp desativar_na_transacao(user, tenant_id, actor_id, razao) do
    Repo.transaction(fn ->
      episodio =
        AccountDisablement.abrir_changeset(%{
          "tenant_id" => tenant_id,
          "user_id" => user.id,
          "disabled_by_user_id" => actor_id,
          "disable_reason" => razao["reason"],
          "disable_note" => razao["note"]
        })

      with {:ok, _episodio} <- Repo.insert(episodio),
           {:ok, desativada} <- user |> User.desativar_changeset(actor_id) |> Repo.update() do
        # O ATO REGISTRADO — achado H4. `ScopeGrant` guarda o ESTADO da concessão; nenhum
        # ato de acesso guardava o EVENTO. A pergunta *"quem desativou esta conta, e
        # quando"* tem resposta na linha; *"quantas contas foram desativadas esta semana,
        # e por quê"* não tinha, e é a que se faz num incidente.
        AccessEvents.ato_administrativo(:conta_desativada, user.id, tenant_id,
          razao: razao["reason"]
        )

        desativada
      else
        {:error, erro} -> Repo.rollback(erro)
      end
    end)
  end

  @doc """
  Reativa uma conta desativada — com ator e razão, e **fechando** o episódio.

  ## O que mudou, e por que era defeito

  A versão anterior recebia tenant e id, e nada mais: reativar era o ato mais sensível dos
  dois e o que tinha **menos** registro. E `reativar_changeset/1` fazia
  `disabled_at: nil, disabled_by_user_id: nil` — um `delete` escrito como `update`: depois
  dele, ninguém desativou aquela conta nunca.

  Agora a reativação **fecha** o episódio com nome, instante e razão, e a abertura fica
  exatamente como estava.

  ## `disabled_by_mistake`

  Marca o episódio como equívoco: ele **deixa de contar** como desligamento e continua
  visível, na forma de `TeamMembership.invalidated_at`. Equívoco é dito, não removido.

  ## E não devolve a senha

  Se a desativação foi feita junto de um reinício — o caminho que
  `docs/producao/desligar-alguem.md` descrevia antes da coluna existir —, a senha continua
  sendo a temporária que ninguém entregou, e quem administra reinicia **depois**. Fazer as
  duas coisas num ato só juntaria decisões diferentes.
  """
  @spec enable_user(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t(), map()) ::
          {:ok, User.t()}
          | {:error, :not_found | :ja_ativa | :sem_episodio_aberto | Ecto.Changeset.t()}
  def enable_user(%Tenant{id: tenant_id}, user_id, actor_id, razao) when is_map(razao) do
    with {:ok, user} <- usuaria_do_tenant(tenant_id, user_id),
         :ok <- ja_desativada(user),
         {:ok, episodio} <- episodio_aberto(tenant_id, user_id) do
      reativar_na_transacao(user, episodio, tenant_id, actor_id, razao)
    end
  end

  defp reativar_na_transacao(user, episodio, tenant_id, actor_id, razao) do
    Repo.transaction(fn ->
      fechamento =
        AccountDisablement.fechar_changeset(episodio, %{
          "enabled_by_user_id" => actor_id,
          "enable_reason" => razao["reason"],
          "enable_note" => razao["note"]
        })

      with {:ok, _fechado} <- Repo.update(fechamento),
           {:ok, reativada} <- user |> User.reativar_changeset() |> Repo.update() do
        AccessEvents.ato_administrativo(:conta_reativada, user.id, tenant_id,
          razao: razao["reason"]
        )

        reativada
      else
        {:error, erro} -> Repo.rollback(erro)
      end
    end)
  end

  @doc """
  O episódio aberto de uma conta, se houver.

  Recusa quando não há: uma conta com `disabled_at` e sem episódio aberto é o estado que a
  transação de `disable_user/4` existe para impedir, e reativar sem fechar nada deixaria a
  marca contradizendo o registro. Só o backfill da migração pode tê-lo criado, e ele criou.
  """
  @spec episodio_aberto(Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, AccountDisablement.t()} | {:error, :sem_episodio_aberto}
  def episodio_aberto(tenant_id, user_id) do
    AccountDisablement
    |> where([e], e.tenant_id == ^tenant_id and e.user_id == ^user_id and is_nil(e.enabled_at))
    |> Repo.one()
    |> case do
      nil -> {:error, :sem_episodio_aberto}
      episodio -> {:ok, episodio}
    end
  end

  @doc """
  O histórico de acesso das contas — o episódio aberto, o último fechado, e a contagem
  do resto.

  **Uma consulta para todas as contas da página**, e nunca uma por linha (L38). A forma é
  a de `esperas_dos_cartoes/3`: quem chama passa o conjunto, e recebe um mapa por
  `user_id`.

  Mostra o aberto mais o último fechado, com a contagem do que não é mostrado sempre
  escrita — *"2 earlier disablements"*. É a recomendação (b) da pergunta 15 do protótipo:
  quatro episódios leem bem, e uma conta de cinco anos com uma dúzia abriria a tabela ao
  meio; o que não aparece continua sendo **dito**.
  """
  @spec historico_de_acesso(Tenant.t(), [Ecto.UUID.t()]) :: %{
          optional(Ecto.UUID.t()) => %{
            aberto: AccountDisablement.t() | nil,
            ultimo_fechado: AccountDisablement.t() | nil,
            anteriores: non_neg_integer(),
            desligamentos: non_neg_integer()
          }
        }
  def historico_de_acesso(%Tenant{id: tenant_id}, user_ids) when is_list(user_ids) do
    if user_ids == [] do
      %{}
    else
      AccountDisablement
      |> where([e], e.tenant_id == ^tenant_id and e.user_id in ^user_ids)
      |> order_by([e], desc: e.disabled_at)
      |> Repo.all()
      |> Enum.group_by(& &1.user_id)
      |> Map.new(fn {user_id, episodios} -> {user_id, resumir(episodios)} end)
    end
  end

  # `desligamentos` EXCLUI os equívocos: a desativação não devia ter acontecido, e contá-la
  # faria a medida afirmar um desligamento que ninguém decidiu. O episódio continua na
  # lista — o que muda é a contagem, não a visibilidade.
  defp resumir(episodios) do
    aberto = Enum.find(episodios, &AccountDisablement.aberto?/1)
    fechados = Enum.reject(episodios, &AccountDisablement.aberto?/1)

    %{
      aberto: aberto,
      ultimo_fechado: List.first(fechados),
      anteriores: max(length(fechados) - 1, 0),
      desligamentos: Enum.count(episodios, &(not AccountDisablement.equivoco?(&1)))
    }
  end

  @doc """
  Quantas concessões de escopo **vigentes** cada conta tem — uma consulta, nunca uma por
  linha (L38).

  A tela da conta desativada precisa do número para dizer o que a conta alcançava, e que
  aquilo ficou **mantido e inerte**: desativar não remove escopo nenhum, e é por isso que
  reativar devolve exatamente o que havia. Sem o número, a frase seria promessa.
  """
  @spec concessoes_vigentes_por_conta(Tenant.t(), [Ecto.UUID.t()]) :: %{
          optional(Ecto.UUID.t()) => non_neg_integer()
        }
  def concessoes_vigentes_por_conta(%Tenant{id: tenant_id}, user_ids) when is_list(user_ids) do
    if user_ids == [] do
      %{}
    else
      ScopeGrant
      |> where([g], g.tenant_id == ^tenant_id and g.user_id in ^user_ids)
      |> where([g], is_nil(g.revoked_at))
      |> group_by([g], g.user_id)
      |> select([g], {g.user_id, count(g.id)})
      |> Repo.all()
      |> Map.new()
    end
  end

  # Sem o vocabulário declarado, o ato RECUSA — é a forma de `ProblemsNow.issue_open_days/0`.
  # A alternativa seria uma lista de reserva no código, que é a duplicata silenciosa que a
  # FR-069 proíbe e faria a plataforma continuar afirmando com a base fora do ar.
  defp vocabulario_declarado do
    if AccountLifecycle.vocabulario_declarado?(),
      do: :ok,
      else: {:error, :vocabulario_nao_declarado}
  end

  # A recusa vira cláusula do `with` em vez de `else` de um `if` — o Credo reprovou a
  # primeira versão por profundidade 3, e tinha razão: a leitura de cima para baixo é
  # "acha a conta, confere que está desativada, reativa", e era isso que o aninhamento
  # escondia.
  defp ja_desativada(user) do
    if User.ativa?(user), do: {:error, :ja_ativa}, else: :ok
  end

  defp nao_e_a_si(user_id, actor_id) when user_id == actor_id,
    do: {:error, :nao_pode_desativar_a_si}

  defp nao_e_a_si(_user_id, _actor_id), do: :ok

  defp ainda_ativa(user) do
    if User.ativa?(user), do: :ok, else: {:error, :ja_desativada}
  end

  @doc """
  Qual conta é esta pessoa observada — issue #369.

  Devolve `{:ok, user}` ou `:not_declared`, e **nunca `nil`**: a tela precisa distinguir
  "essa pessoa é a conta X" de "não sabemos quem essa pessoa é", porque a segunda tem
  remédio — declarar — e a primeira não.
  """
  @spec user_for_person(Tenant.t(), Ecto.UUID.t()) :: {:ok, User.t()} | :not_declared
  def user_for_person(%Tenant{id: tenant_id}, person_id) do
    case Repo.one(
           from u in User,
             where:
               u.tenant_id == ^tenant_id and u.person_id == type(^person_id, :binary_id) and
                 is_nil(u.person_revoked_at)
         ) do
      nil -> :not_declared
      user -> {:ok, user}
    end
  end

  @doc """
  Qual pessoa observada é esta conta — o outro lado do elo.

  Devolve o `person_id`, ou `:not_declared`. É por aqui que a regra de visibilidade começa:
  sem esta resposta, nem o painel da própria pessoa é alcançável.
  """
  @spec person_of_user(User.t()) :: {:ok, Ecto.UUID.t()} | :not_declared
  def person_of_user(%User{} = user) do
    if User.elo_vigente?(user), do: {:ok, user.person_id}, else: :not_declared
  end

  @doc """
  Quantas contas têm elo declarado, e quantas existem — a lacuna, dita como lacuna.

  `1 de 2` e `1` afirmam coisas diferentes: o primeiro diz que uma conta ainda não alcança
  painel nenhum.
  """
  @spec elo_coverage(Tenant.t()) :: %{declaradas: non_neg_integer(), contas: non_neg_integer()}
  def elo_coverage(%Tenant{id: tenant_id}) do
    Repo.one(
      from u in User,
        where: u.tenant_id == ^tenant_id,
        select: %{
          contas: count(u.id),
          declaradas: filter(count(u.id), not is_nil(u.person_id) and is_nil(u.person_revoked_at))
        }
    )
  end

  # O `person_id` FICA na linha revogada, e é `revoked_at` que o tira de circulação. Zerar
  # perderia QUAL pessoa a conta era — sobraria "desde quando" e sumiria "quem", que é a
  # metade que se pergunta primeiro. O índice parcial já exclui a linha revogada.
  defp revogar_elo(user, actor_id, agora) do
    Repo.update_all(
      from(u in User, where: u.id == type(^user.id, :binary_id)),
      set: [
        person_revoked_by_user_id: actor_id,
        person_revoked_at: agora,
        updated_at: agora
      ]
    )
  end

  defp usuaria_do_tenant(tenant_id, user_id) do
    case Repo.get_by(User, id: user_id, tenant_id: tenant_id) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  defp conflito(%Ecto.Changeset{errors: erros} = cs) do
    if match?({_, [constraint: :unique, constraint_name: _]}, erros[:person_id]),
      do: :taken,
      else: cs
  end
end
