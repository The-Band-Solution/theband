defmodule TheBand.Ontology.SEON.EO.Roster do
  @moduledoc """
  O roster da equipe — **uma linha por pessoa**, com todos os vínculos dela ali dentro.

  Feature 060, FR-008 a FR-013. É o que a aba *Structure* de `/teams/:id` desenha, e substitui
  `list_team_members/3` **naquela aba** (o painel continua usando a outra, que é sobre
  evidência).

  ## Por que um módulo, e não mais uma função em `Queries`

  As duas listagens respondem perguntas diferentes sobre a mesma tela, e confundi-las é
  exatamente o defeito que a feature 060 veio corrigir:

  | | `Queries.list_team_members/3` | este módulo |
  |---|---|---|
  | a unidade | a **evidência** — o que a origem mostra | o **vínculo** — o que a organização afirma |
  | linhas por pessoa | uma por evidência | **uma**, sempre (FR-009) |
  | alcance | esta equipe | esta equipe **e** as subequipes vigentes |
  | traz `platform_access_level` | sim | **nunca** (FR-008, SC-004) |

  O `platform_access_level` é `MAINTAINER`/`MEMBER` do GitHub: permissão de plataforma, não
  papel na organização. Mostrá-lo na coluna de papel fazia a tela afirmar que a pessoa é
  "mantenedora" de uma equipe — coisa que ninguém declarou. SC-004 mede a ausência da palavra
  na página, e é por isso que ela não sai daqui.

  ## Duas consultas, e não 1 + N

  A primeira acha as **pessoas distintas** da página, já com a situação agregada; a segunda
  traz **os vínculos dessas pessoas**. O custo é o mesmo para 1 pessoa e para 11, e
  `roster_test.exs` prova isso contando consultas — porque a alternativa natural (uma consulta
  de vínculos por linha) passa em todo teste funcional e só aparece em produção.

  ## O alcance inclui as subequipes VIGENTES

  Quem gere uma equipe composta precisa ver quem está nela por dentro das partes: era isso que
  faltava para a tela responder "quem trabalha aqui". Composição **encerrada** não entra — a
  parte saiu do todo, e continuar listando os membros dela afirmaria uma estrutura que não
  existe mais.
  """

  import Ecto.Query

  alias TheBand.Ontology.SEON.EO.Schemas.OrganizationalRole
  alias TheBand.Ontology.SEON.EO.Schemas.Person
  alias TheBand.Ontology.SEON.EO.Schemas.Team
  alias TheBand.Ontology.SEON.EO.Schemas.TeamComposition
  alias TheBand.Ontology.SEON.EO.Schemas.TeamMembership
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant
  alias TheBand.Tenants.User

  @typedoc """
  A situação da PESSOA na equipe, agregada dos vínculos dela (FR-012).

  `:vigente` quando algum vínculo está vigente. `:equivoco` quando **todos** foram
  invalidados — a mesma regra de `membership_disagreements/2`, para os dois números da tela
  não se contradizerem. `:saiu` nos demais casos.
  """
  @type situacao :: :vigente | :saiu | :equivoco

  @typedoc """
  Como um vínculo terminou, ou `nil` se não terminou.

  As três formas de fim **não são** a mesma coisa, e FR-022 exige a tela dizer qual é qual:

  - `{:declarado, autor, registrado_em, quando}` — alguém afirmou que a pessoa saiu, e `quando`
    é a data da saída, possivelmente retroativa;
  - `{:coleta, quando}` — a origem deixou de mostrar a pessoa, e `quando` é **quando a
    plataforma parou de ver**, não quando a pessoa saiu. A tela precisa dizer essa diferença
    com palavras, porque a data sozinha mente;
  - `{:sem_autor, quando}` — fim gravado antes de a plataforma guardar quem o declarou. A tela
    diz "author not recorded" em vez de atribuir a alguém.
  """
  @type fim ::
          nil
          | {:declarado, String.t() | nil, DateTime.t(), DateTime.t()}
          | {:coleta, DateTime.t()}
          | {:sem_autor, DateTime.t()}

  @doc """
  As pessoas da equipe, uma linha cada, com os vínculos dentro.

  `opts`: `:search` (nome ou login), `:limit`, `:offset`, `:order_by` (`{:name, :asc | :desc}`).
  """
  @spec list_team_roster(Tenant.t(), Ecto.UUID.t(), keyword()) :: [map()]
  def list_team_roster(%Tenant{id: tenant_id} = tenant, team_id, opts \\ []) do
    equipes = opts[:escopo] || equipes_do_alcance(tenant, team_id)

    pessoas =
      tenant_id
      |> pessoas_do_roster(equipes, opts)
      |> Repo.all()

    case pessoas do
      [] -> []
      pessoas -> com_vinculos(tenant_id, team_id, equipes, pessoas)
    end
  end

  @doc """
  Quantas PESSOAS o roster tem, com as mesmas `opts` da listagem.

  A contagem e a listagem compartilham o filtro de propósito: um cabeçalho dizendo 64 sobre
  uma lista de 10 é o defeito que a paginação sempre produz quando os dois lados divergem.
  """
  @spec count_team_roster(Tenant.t(), Ecto.UUID.t(), keyword()) :: non_neg_integer()
  def count_team_roster(%Tenant{id: tenant_id} = tenant, team_id, opts \\ []) do
    equipes = opts[:escopo] || equipes_do_alcance(tenant, team_id)

    from(m in TeamMembership,
      join: p in Person,
      on: p.id == m.person_id,
      where: m.tenant_id == ^tenant_id and m.team_id in ^equipes,
      select: m.person_id,
      distinct: true
    )
    |> busca(opts[:search])
    |> subquery()
    |> Repo.aggregate(:count)
  end

  @doc """
  Os três números do cabeçalho, **por pessoa** e da mesma agregação da listagem (FR-012).

  Saem da mesma definição de `situacao` porque números que se contradizem na mesma tela são
  pior que número ausente: quem lê não sabe qual acreditar, e passa a não acreditar em nenhum.
  """
  @spec team_roster_totals(Tenant.t(), Ecto.UUID.t(), keyword()) :: %{
          vigentes: non_neg_integer(),
          sairam: non_neg_integer(),
          equivocos: non_neg_integer()
        }
  def team_roster_totals(%Tenant{id: tenant_id} = tenant, team_id, opts \\ []) do
    equipes = opts[:escopo] || equipes_do_alcance(tenant, team_id)

    tenant_id
    |> agregado_por_pessoa(equipes)
    |> Repo.all()
    |> Enum.reduce(%{vigentes: 0, sairam: 0, equivocos: 0}, fn linha, acc ->
      Map.update!(acc, chave_do_total(situacao_de(linha)), &(&1 + 1))
    end)
  end

  defp chave_do_total(:vigente), do: :vigentes
  defp chave_do_total(:saiu), do: :sairam
  defp chave_do_total(:equivoco), do: :equivocos

  @doc """
  Quantas PESSOAS desempenham cada papel — nesta equipe e na organização (FR-029).

  Devolve `%{organizational_role_id => %{nesta_equipe: n, na_organizacao: n}}`.

  ## Uma consulta, e não duas por papel

  Os dois números saem do mesmo `GROUP BY` com `FILTER`: o total é a organização, e o
  filtrado é a equipe. A alternativa natural — uma consulta por linha da tabela de papéis —
  passa em todo teste funcional com três papéis e aparece em produção com trinta.

  ## Pessoas DISTINTAS, e vigentes

  `count(distinct person_id)`, pelo mesmo motivo de `count_team_members_at/3`: a pergunta é
  quantas pessoas, e alguém pode ter o mesmo papel em duas equipes da organização — contaria
  duas vezes na coluna da organização.

  ## Papel sem ninguém não aparece no mapa

  E é intencional: a tela lê `Map.get(contagens, papel.id, %{nesta_equipe: 0, na_organizacao: 0})`,
  e o papel do **catálogo** que ainda não foi materializado não tem `id` para chavear — vale
  `0/0` por construção, sem uma linha inventada no mapa para representá-lo.
  """
  @spec role_holder_counts(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) :: %{
          Ecto.UUID.t() => %{nesta_equipe: non_neg_integer(), na_organizacao: non_neg_integer()}
        }
  def role_holder_counts(%Tenant{id: tenant_id}, organization_id, team_id) do
    Repo.all(
      from m in TeamMembership,
        join: t in Team,
        on: t.id == m.team_id,
        where:
          m.tenant_id == type(^tenant_id, :binary_id) and
            t.organization_id == type(^organization_id, :binary_id) and
            not is_nil(m.organizational_role_id) and
            is_nil(m.ended_at) and is_nil(m.invalidated_at),
        group_by: m.organizational_role_id,
        select: {
          type(m.organizational_role_id, :binary_id),
          count(m.person_id, :distinct),
          filter(
            count(m.person_id, :distinct),
            m.team_id == type(^team_id, :binary_id)
          )
        }
    )
    |> Map.new(fn {role_id, na_organizacao, nesta_equipe} ->
      {role_id, %{nesta_equipe: nesta_equipe || 0, na_organizacao: na_organizacao}}
    end)
  end

  @doc """
  O ALCANCE do roster: esta equipe e as partes com composição vigente.

  Público porque as três funções acima o precisam, e chamar cada uma sem ele custa **uma
  consulta idêntica por chamada**. Medido em 2026-09-08: a aba da estrutura fazia 9 consultas,
  e 3 eram esta mesma — a listagem, a contagem e os totais perguntando o mesmo ao banco.

  Quem desenha a tela chama isto **uma vez** e passa em `opts[:escopo]`. Quem chama de fora
  sem o `opts` continua correto, só paga a consulta: o padrão não pode ser "rápido e errado
  se você esquecer".
  """
  @spec escopo(Tenant.t(), Ecto.UUID.t()) :: [Ecto.UUID.t()]
  def escopo(%Tenant{} = tenant, team_id), do: equipes_do_alcance(tenant, team_id)

  # ------------------------------------------------------------------ o alcance

  # Esta equipe e as PARTES com composição vigente. Uma consulta, e o `team_id` primeiro para
  # a equipe própria vir antes das partes em qualquer ordenação que dependa da ordem da lista.
  defp equipes_do_alcance(%Tenant{id: tenant_id}, team_id) do
    partes =
      Repo.all(
        from c in TeamComposition,
          where:
            c.tenant_id == type(^tenant_id, :binary_id) and
              c.whole_team_id == type(^team_id, :binary_id) and is_nil(c.ended_at),
          select: c.part_team_id
      )

    [team_id | partes]
  end

  # ------------------------------------------------- consulta 1: as pessoas da página

  defp pessoas_do_roster(tenant_id, equipes, opts) do
    tenant_id
    |> agregado_por_pessoa(equipes)
    |> busca(opts[:search])
    |> ordenar(opts[:order_by])
    |> paginar(opts)
  end

  # A situação da pessoa é decidida por CONTAGEM, e no banco: quantos vínculos ela tem no
  # alcance, quantos estão vigentes, quantos foram invalidados. Trazer os vínculos para o
  # Elixir só para classificar exigiria trazer TODOS antes de paginar.
  defp agregado_por_pessoa(tenant_id, equipes) do
    from m in TeamMembership,
      join: p in Person,
      on: p.id == m.person_id,
      where: m.tenant_id == type(^tenant_id, :binary_id) and m.team_id in ^equipes,
      group_by: [m.person_id, p.name, p.login],
      select: %{
        person_id: m.person_id,
        name: p.name,
        login: p.login,
        total: count(m.id),
        vigentes: filter(count(m.id), is_nil(m.ended_at) and is_nil(m.invalidated_at)),
        equivocos: filter(count(m.id), not is_nil(m.invalidated_at))
      }
  end

  defp situacao_de(%{vigentes: v}) when v > 0, do: :vigente
  defp situacao_de(%{total: t, equivocos: e}) when t == e and t > 0, do: :equivoco
  defp situacao_de(_), do: :saiu

  defp busca(query, termo) when termo in [nil, ""], do: query

  defp busca(query, termo) do
    like = "%#{termo}%"
    where(query, [_m, p], ilike(p.name, ^like) or ilike(p.login, ^like))
  end

  # Só por nome, e por login como desempate: a tela ordena por pessoa, e um `order_by` vindo
  # de parâmetro de URL não pode virar nome de coluna.
  defp ordenar(query, {:name, dir}) when dir in [:asc, :desc],
    do: order_by(query, [_m, p], [{^dir, p.name}, asc: p.login])

  defp ordenar(query, _), do: order_by(query, [_m, p], asc: p.name, asc: p.login)

  defp paginar(query, opts) do
    case {opts[:limit], opts[:offset]} do
      {nil, nil} -> query
      {limite, nil} -> limit(query, ^limite)
      {nil, salto} -> offset(query, ^salto)
      {limite, salto} -> query |> limit(^limite) |> offset(^salto)
    end
  end

  # -------------------------------------- consulta 2: os vínculos DESSAS pessoas

  defp com_vinculos(tenant_id, team_id, equipes, pessoas) do
    ids = Enum.map(pessoas, & &1.person_id)

    por_pessoa =
      Repo.all(
        from m in TeamMembership,
          join: t in Team,
          on: t.id == m.team_id,
          left_join: r in OrganizationalRole,
          on: r.id == m.organizational_role_id,
          left_join: autor in User,
          on: autor.id == m.declared_by_user_id,
          left_join: quem_encerrou in User,
          on: quem_encerrou.id == m.ended_by_user_id,
          left_join: quem_invalidou in User,
          on: quem_invalidou.id == m.invalidated_by_user_id,
          where:
            m.tenant_id == type(^tenant_id, :binary_id) and m.person_id in ^ids and
              m.team_id in ^equipes,
          order_by: [asc: t.name, asc: m.inserted_at],
          select: %{
            membership_id: m.id,
            person_id: m.person_id,
            team_id: m.team_id,
            team_name: t.name,
            role_id: r.id,
            role_code: r.code,
            role_name: r.name,
            declared_by_user_id: m.declared_by_user_id,
            declared_by: autor.email,
            declared_at: m.declared_at,
            started_at: m.started_at,
            ended_at: m.ended_at,
            ended_by: quem_encerrou.email,
            end_declared_at: m.end_declared_at,
            invalidated_at: m.invalidated_at,
            invalidated_by: quem_invalidou.email,
            invalidation_reason: m.invalidation_reason
          }
      )
      |> Enum.group_by(& &1.person_id)

    Enum.map(pessoas, fn pessoa ->
      vinculos =
        por_pessoa
        |> Map.get(pessoa.person_id, [])
        |> Enum.map(&linha_do_vinculo(&1, team_id))

      %{
        person_id: pessoa.person_id,
        name: pessoa.name,
        login: pessoa.login,
        situacao: situacao_de(pessoa),
        vinculos: vinculos,
        # Os chips de subequipe da tela: o nome das PARTES onde a pessoa tem vínculo
        # vigente. A equipe da própria tela não é chip — ela é a tela.
        squads:
          vinculos
          |> Enum.filter(&(&1.vigente? and not &1.direta?))
          |> Enum.map(& &1.team_name)
          |> Enum.uniq(),
        direta?: Enum.any?(vinculos, &(&1.vigente? and &1.direta?))
      }
    end)
  end

  defp linha_do_vinculo(v, team_id) do
    %{
      membership_id: v.membership_id,
      team_id: v.team_id,
      team_name: v.team_name,
      direta?: v.team_id == team_id,
      role: papel(v),
      # A ORIGEM sai de `declared_by_user_id`, e não do papel. Vínculo com autor é declaração;
      # sem autor é a coleta afirmando participação e nada mais (ADR 0008).
      origem: if(v.declared_by_user_id, do: :declarado, else: :observado),
      declared_by: v.declared_by,
      declared_at: v.declared_at,
      started_at: v.started_at,
      fim: fim(v),
      equivoco: equivoco(v),
      vigente?: is_nil(v.ended_at) and is_nil(v.invalidated_at)
    }
  end

  defp papel(%{role_id: nil}), do: nil
  defp papel(v), do: %{id: v.role_id, code: v.role_code, name: v.role_name}

  defp fim(%{ended_at: nil}), do: nil

  defp fim(%{ended_at: quando, ended_by: autor, end_declared_at: registrado})
       when not is_nil(autor),
       do: {:declarado, autor, registrado, quando}

  # Fim SEM autor, e a distinção é pela ORIGEM do vínculo — não há outra.
  #
  # Vínculo observado (sem autor de declaração) que ganhou fim: foi a coleta, quando a origem
  # deixou de mostrar a pessoa. A data é **quando a plataforma parou de ver**, e a tela tem de
  # dizer isso com palavras, porque a data sozinha se passa por data de saída (FR-022).
  #
  # Vínculo declarado que ganhou fim sem autor: é registro anterior a
  # `20260908010000_saida_declarada_com_autor`, quando `record_team_departure/5` descartava
  # quem declarava. Não há autor a recuperar, e inventar um seria pior que a lacuna.
  defp fim(%{ended_at: quando, declared_by_user_id: nil}), do: {:coleta, quando}

  defp fim(%{ended_at: quando}), do: {:sem_autor, quando}

  defp equivoco(%{invalidated_at: nil}), do: nil

  defp equivoco(v),
    do: %{razao: v.invalidation_reason, por: v.invalidated_by, em: v.invalidated_at}
end
