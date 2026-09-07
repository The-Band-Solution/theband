defmodule TheBand.Ontology.SEON.EO.StructureGrants do
  @moduledoc """
  Quem pode **declarar a estrutura** de uma equipe — spec 060, FR-080 a FR-082.

  Irmã de `TheBand.Ontology.SEON.EO.Visibility`, com o verbo trocado. Aquela responde *quem
  vê o painel de trabalho de quem*; esta responde *quem pode mexer na estrutura de qual
  equipe* — o papel de cada pessoa, a saída, o equívoco, a composição de subequipes, os
  papéis da organização e a ligação a projeto.

  ## A diferença que justifica um módulo próprio

  A spec 045 (FR-022) separa **ver** de **mexer** de propósito, e as duas decisões não se
  implicam: quem coordena pode precisar declarar sem enxergar o painel de ninguém, e quem
  audita pode precisar do contrário.

  ## O alvo aqui é uma EQUIPE, e não uma pessoa

  É a segunda diferença, e ela muda a consulta. Em `Visibility`, os dois lados do elo
  precisam de vínculo vigente — o meu e o da pessoa que quero ver. Aqui **só o meu lado**
  tem vigência a exigir: a equipe alvo é uma linha, não alguém que possa ter saído. Quem
  gere a estrutura de uma equipe **vazia** continua podendo geri-la — aliás, é justamente
  quem precisa.

  ## Nada vem por nome

  `Tech Leader` parece liderança e `Coordenador` também; a mesma organização pode ter um
  `Tech Lead` que é senioridade técnica e não coordena ninguém. A concessão é declarada, com
  autor e data, e o erro por padrão de nome aqui é mais caro que na irmã: excesso de
  visibilidade concedido ninguém reclama; excesso de gestão concedido **reescreve a
  estrutura** de quem não deveria.
  """

  import Ecto.Query

  alias TheBand.Ontology.SEON.EO.Schemas.RoleStructureManagementGrant, as: Grant
  alias TheBand.Ontology.SEON.EO.Schemas.TeamMembership
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @escopos Grant.escopos()

  @typedoc "O veredito, com o motivo — nunca um booleano."
  @type alcance ::
          {:ok, :gestor_da_equipe | :gestor_da_organizacao}
          | {:nao, :vinculo_encerrado | :sem_concessao}

  @doc """
  Esta pessoa pode declarar a estrutura desta equipe?

  O motivo mais específico vence: `:vinculo_encerrado` é dito no lugar de `:sem_concessao`
  quando existe um vínculo **encerrado ou invalidado** com um papel que alcançaria a equipe.
  As duas frases levam a ações diferentes — renovar o vínculo, ou pedir a concessão —, e
  colapsá-las manda a pessoa procurar a administradora quando o problema era outro.
  """
  @spec alcance(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) :: alcance()
  def alcance(%Tenant{} = tenant, person_id, team_id) do
    cond do
      alcanca?(tenant, person_id, team_id, "team") -> {:ok, :gestor_da_equipe}
      alcanca?(tenant, person_id, team_id, "organization") -> {:ok, :gestor_da_organizacao}
      alcancaria_com_vinculo_vigente?(tenant, person_id, team_id) -> {:nao, :vinculo_encerrado}
      true -> {:nao, :sem_concessao}
    end
  end

  @doc """
  As concessões de gestão vigentes deste tenant, por papel — para a tela dos papéis.

  Devolve `%{organizational_role_id => [escopo]}`. Uma consulta só: a tela desenha a coluna
  inteira com ela, e nunca uma consulta por linha.
  """
  @spec grants_by_role(Tenant.t()) :: %{Ecto.UUID.t() => [String.t()]}
  def grants_by_role(%Tenant{id: tenant_id}) do
    Repo.all(
      from g in Grant,
        where: g.tenant_id == type(^tenant_id, :binary_id) and is_nil(g.revoked_at),
        select: {type(g.organizational_role_id, :binary_id), g.scope}
    )
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  @doc """
  Declara que este papel gere a estrutura, neste alcance.

  `{:error, :already_granted}` quando já existe uma vigente para o par — a garantia é do
  índice parcial no banco, e o changeset a traduz. Escopo fora dos dois valores é
  `:invalid_scope`, nunca ignorado.
  """
  @spec declare_grant(Tenant.t(), Ecto.UUID.t(), String.t(), Ecto.UUID.t()) ::
          {:ok, Grant.t()} | {:error, :already_granted | :invalid_scope | Ecto.Changeset.t()}
  def declare_grant(%Tenant{}, _role_id, escopo, _actor_id) when escopo not in @escopos,
    do: {:error, :invalid_scope}

  def declare_grant(%Tenant{id: tenant_id}, role_id, escopo, actor_id) do
    %Grant{}
    |> Grant.changeset(%{
      tenant_id: tenant_id,
      organizational_role_id: role_id,
      scope: escopo,
      declared_by_user_id: actor_id,
      declared_at: DateTime.utc_now(:second)
    })
    |> Repo.insert()
    |> case do
      {:ok, concessao} -> {:ok, concessao}
      {:error, changeset} -> {:error, motivo_da_recusa(changeset)}
    end
  end

  @doc """
  Revoga a concessão vigente deste papel neste alcance.

  **Marca, nunca apaga**: grava `revoked_at` e o autor, e a linha continua. Retirar poder de
  escrita é exatamente o que se audita, e "desde quando esse papel geria" só tem resposta se
  o encerramento preservar o começo.

  Revogar o que não está concedido é `{:error, :not_declared}` — nunca sucesso silencioso.
  """
  @spec revoke_grant(Tenant.t(), Ecto.UUID.t(), String.t(), Ecto.UUID.t()) ::
          {:ok, Grant.t()} | {:error, :not_declared}
  def revoke_grant(%Tenant{id: tenant_id}, role_id, escopo, actor_id) do
    consulta =
      from g in Grant,
        where:
          g.tenant_id == type(^tenant_id, :binary_id) and
            g.organizational_role_id == type(^role_id, :binary_id) and
            g.scope == ^escopo and is_nil(g.revoked_at)

    case Repo.one(consulta) do
      nil ->
        {:error, :not_declared}

      concessao ->
        concessao
        |> Grant.changeset(%{
          revoked_at: DateTime.utc_now(:second),
          revoked_by_user_id: actor_id
        })
        |> Repo.update()
    end
  end

  # ------------------------------------------------------------------ o alcance

  # `team`: a pessoa tem vínculo VIGENTE, nesta equipe, com um papel cuja concessão vigente
  # tem alcance `team`.
  defp alcanca?(%Tenant{id: tenant_id}, person_id, team_id, "team") do
    from(m in TeamMembership,
      join: g in Grant,
      on:
        g.organizational_role_id == m.organizational_role_id and
          g.tenant_id == m.tenant_id and is_nil(g.revoked_at) and g.scope == "team",
      where:
        m.tenant_id == type(^tenant_id, :binary_id) and
          m.person_id == type(^person_id, :binary_id) and
          m.team_id == type(^team_id, :binary_id)
    )
    |> vigente()
    |> Repo.exists?()
  end

  # `organization`: a pessoa tem vínculo VIGENTE em ALGUMA equipe da mesma organização da
  # equipe alvo, com um papel cuja concessão vigente tem alcance `organization`.
  #
  # A organização vem da equipe, e não do trabalho: "é membro" e "trabalhou lá" são
  # afirmações diferentes, e só a primeira é declaração.
  defp alcanca?(%Tenant{id: tenant_id}, person_id, team_id, "organization") do
    from(m in TeamMembership,
      join: g in Grant,
      on:
        g.organizational_role_id == m.organizational_role_id and
          g.tenant_id == m.tenant_id and is_nil(g.revoked_at) and g.scope == "organization",
      join: minha_equipe in "eo_teams",
      on: minha_equipe.id == m.team_id,
      join: alvo in "eo_teams",
      on:
        alvo.id == type(^team_id, :binary_id) and
          alvo.organization_id == minha_equipe.organization_id,
      where:
        m.tenant_id == type(^tenant_id, :binary_id) and
          m.person_id == type(^person_id, :binary_id)
    )
    |> vigente()
    |> Repo.exists?()
  end

  # A mesma pergunta das duas acima, SEM a exigência de vigência do meu vínculo. Só serve
  # para escolher a frase da recusa: existe um vínculo com papel que alcançaria, e ele
  # acabou. Sem isto, quem saiu da equipe ouviria "peça a concessão" — e ela já foi
  # concedida.
  defp alcancaria_com_vinculo_vigente?(%Tenant{id: tenant_id}, person_id, team_id) do
    from(m in TeamMembership,
      join: g in Grant,
      on:
        g.organizational_role_id == m.organizational_role_id and
          g.tenant_id == m.tenant_id and is_nil(g.revoked_at),
      join: minha_equipe in "eo_teams",
      on: minha_equipe.id == m.team_id,
      join: alvo in "eo_teams",
      on: alvo.id == type(^team_id, :binary_id),
      where:
        m.tenant_id == type(^tenant_id, :binary_id) and
          m.person_id == type(^person_id, :binary_id)
    )
    |> where([m], not is_nil(m.ended_at) or not is_nil(m.invalidated_at))
    |> onde_a_concessao_alcancaria(team_id)
    |> Repo.exists?()
  end

  # O alcance de cada escopo, na forma de condição — extraído porque somar os dois ramos à
  # consulta acima passava do limite de complexidade que o credo aceita, e porque a regra é
  # uma só: `team` olha a própria equipe, `organization` olha a organização dela.
  defp onde_a_concessao_alcancaria(query, team_id) do
    where(
      query,
      [m, g, minha_equipe, alvo],
      (g.scope == "team" and m.team_id == type(^team_id, :binary_id)) or
        (g.scope == "organization" and alvo.organization_id == minha_equipe.organization_id)
    )
  end

  # Vigente são DUAS condições — sem fim registrado E sem invalidação. Só o lado de quem
  # age: a equipe alvo é uma linha, não alguém que possa ter saído.
  defp vigente(query) do
    where(query, [m], is_nil(m.ended_at) and is_nil(m.invalidated_at))
  end

  defp motivo_da_recusa(%Ecto.Changeset{errors: erros} = changeset) do
    if Enum.any?(erros, fn {_campo, {_msg, opts}} ->
         Keyword.get(opts, :constraint) == :unique
       end),
       do: :already_granted,
       else: changeset
  end
end
