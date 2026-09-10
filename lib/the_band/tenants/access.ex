defmodule TheBand.Tenants.Access do
  @moduledoc """
  O veredito único do acesso — contrato em
  `specs/045-autenticacao-e-acesso/contracts/access-scopes.md`.

  ## O axioma, executável

  **A pessoa tem acesso aos dados com os quais está relacionada.** O elo diz quem
  a conta é; vínculo e ligação declarada dizem com o que ela se relaciona; a
  concessão cobre o que a relação não cobre. A visão é a UNIÃO — escopos somam,
  nunca subtraem (FR-006/018).

  ## Derivado não se grava

  `scopes/2` LÊ as relações vigentes a cada chamada: elo → pessoa → vínculos →
  equipes → ligações declaradas → projetos. Encerrou o fato, fechou o escopo —
  sem job, sem coluna, sem segunda verdade (FR-020/021). Só a concessão vira
  linha, com proveniência e revogação por marca.

  ## Administrar VÊ, desde 2026-09-09 — a FR-022 foi emendada

  Este cabeçalho dizia *"nenhum ramo aqui olha `users.role` para conceder visão"*, e
  **deixou de ser verdade** quando `pode_ver/3` ganhou a cláusula do admin. A recusa do
  papel Product Owner na avaliação da v0.7.0 apanhou-o, e com a observação que dói: era o
  **H6 dentro do arquivo que o H6 corrigiu** — antes uma função desmentia o cabeçalho,
  depois duas, e uma delas é a que o cabeçalho nomeia.

  **O que vale agora**: administração **do próprio tenant** abre painel de pessoa
  (`pode_ver/3`) e alcança a quebra por pessoa na equipe (`pode_ver_equipe/3`). As duas,
  e pela mesma razão.

  A emenda está na **FR-022 da spec 045**, com o texto original preservado riscado. A razão
  não foi conveniência: `pode_ver_equipe/3` já concedia ao admin, e o booleano dela libera a
  quebra por pessoa nomeada na tela da equipe. **Administração já lia pessoa nomeada pela
  porta da equipe** enquanto a tela da pessoa a recusava — a plataforma afirmava um regime
  que não aplicava, o que é pior que qualquer dos dois regimes.

  **O que continua valendo da FR-022 original**: administrar **outro** tenant não abre
  nada, e a FR-023 segue intacta — ver não exige administrar, e escopo continua sendo o
  caminho de quem não administra.

  ## O motivo importa

  `pode_ver/3` devolve `{:ok, motivo}`/`{:nao, motivo}` — booleano no lugar de
  relator é antipadrão da casa. O mais específico vence, e a liderança declarada
  (#369) continua valendo por delegação, somada por último (FR-018).
  """

  import Ecto.Query

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.EO.StructureGrants
  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Repo
  alias TheBand.Tenants
  alias TheBand.Tenants.Access.ScopeGrant
  alias TheBand.Tenants.Tenant
  alias TheBand.Tenants.User

  @type scope :: %{
          level: :person | :team | :project | :organization,
          target_id: Ecto.UUID.t() | nil,
          target_name: String.t() | nil,
          origin: :floor | :derived_team | :derived_project | :granted,
          grant: ScopeGrant.t() | nil
        }

  @doc "A união vigente, com a origem de cada escopo — a tela pinta hachura por ela."
  @spec scopes(Tenant.t(), User.t()) :: [scope()]
  def scopes(%Tenant{} = tenant, %User{} = user) do
    {piso, equipes} =
      case Tenants.person_of_user(user) do
        {:ok, person_id} -> {[floor_scope()], EO.person_active_teams(tenant, person_id)}
        :not_declared -> {[], []}
      end

    derivados_team =
      for e <- equipes do
        %{
          level: :team,
          target_id: e.team_id,
          target_name: e.team_name,
          origin: :derived_team,
          grant: nil
        }
      end

    derivados_project =
      for p <- projetos_das_equipes(tenant, equipes),
          uniq: true do
        %{
          level: :project,
          target_id: p.project_id,
          target_name: p.project_name,
          origin: :derived_project,
          grant: nil
        }
      end

    piso ++ derivados_team ++ derivados_project ++ granted_scopes(tenant, user)
  end

  defp floor_scope,
    do: %{level: :person, target_id: nil, target_name: nil, origin: :floor, grant: nil}

  # Sem equipe não há consulta: `in []` ainda é uma ida ao banco (L38).
  defp projetos_das_equipes(_tenant, []), do: []

  defp projetos_das_equipes(tenant, equipes),
    do: SPO.projects_of_teams(tenant, Enum.map(equipes, & &1.team_id))

  defp granted_scopes(%Tenant{id: tenant_id} = tenant, %User{id: user_id}) do
    grants =
      Repo.all(
        from g in ScopeGrant,
          where: g.tenant_id == ^tenant_id and g.user_id == ^user_id and is_nil(g.revoked_at),
          order_by: [asc: g.granted_at]
      )

    nomes = target_names(tenant, grants)

    for g <- grants do
      %{
        level: String.to_existing_atom(g.level),
        target_id: g.target_id,
        # nil = alvo que não existe mais: a concessão ficou órfã, e a tela diz.
        target_name: Map.get(nomes, {g.level, g.target_id}),
        origin: :granted,
        grant: g
      }
    end
  end

  # Três consultas no máximo — uma por nível presente (L38), nunca por concessão;
  # e ZERO quando não há concessão nenhuma, que é o caso comum.
  defp target_names(_tenant, []), do: %{}

  defp target_names(tenant, grants) do
    por_nivel = Enum.group_by(grants, & &1.level, & &1.target_id)

    equipes = nomes_ou_nada(por_nivel, "team", &EO.teams_by_ids(tenant, &1))
    projetos = nomes_ou_nada(por_nivel, "project", &SPO.projects_by_ids(tenant, &1))

    organizacoes =
      case Map.get(por_nivel, "organization", []) do
        [] -> %{}
        ids -> tenant |> EO.list_organizations() |> Map.new(&{&1.id, &1.name}) |> Map.take(ids)
      end

    %{}
    |> juntar("team", equipes)
    |> juntar("project", projetos)
    |> juntar("organization", organizacoes)
  end

  defp juntar(acc, nivel, mapa),
    do: Enum.into(mapa, acc, fn {id, nome} -> {{nivel, id}, nome} end)

  defp nomes_ou_nada(por_nivel, nivel, buscar) do
    case Map.get(por_nivel, nivel, []) do
      [] -> %{}
      ids -> buscar.(ids)
    end
  end

  @doc """
  Esta conta pode **declarar a estrutura desta equipe**? — feature 060, FR-006 e FR-080 a
  FR-082.

  ## Por que é uma pergunta diferente de `pode_ver_equipe/3`

  Aquela responde sobre **ler** as medidas da equipe; esta, sobre **escrever** a estrutura
  dela: o papel de cada pessoa, a saída, o equívoco, a composição de subequipes, os papéis
  da organização e a ligação a projeto. A spec 045 (FR-022) separa ver de mexer de
  propósito, e as duas decisões não se implicam.

  ## A lista é fechada: administrador, ou papel com concessão

  Decisão da pessoa mantenedora em 2026-09-07. Substitui `pode_declarar_estrutura/4`, que
  autorizava também pelo escopo `organization`/`project` **da conta** — e escopo de conta é
  concedido para **ver**. Medido antes de trocar, no banco de desenvolvimento: **zero**
  contas não-administradoras escreviam por esse caminho, e as duas administradoras
  continuam escrevendo sem concessão nenhuma. A troca não tirou poder de ninguém.

  A concessão é do **papel**, e a pessoa a alcança pelo vínculo vigente com ele — nunca da
  conta, que sobreviveria à troca de papel, e nunca pelo nome do papel.

  ## Os motivos, e por que são quatro e não um `false`

  `:conta_sem_pessoa_declarada` — a conta não tem elo com pessoa, e a concessão fala de
  papéis de pessoas. `:vinculo_encerrado` — existe um papel concedido que alcançaria esta
  equipe, e o vínculo com ele acabou. `:sem_concessao` — nenhum papel vigente alcança.

  As três levam a ações diferentes: ligar a conta a uma pessoa, renovar o vínculo, pedir a
  concessão. Colapsá-las num `false` manda quem foi recusado procurar a administradora com
  a pergunta errada.
  """
  @spec pode_gerir_estrutura(Tenant.t(), User.t(), Ecto.UUID.t()) ::
          {:ok, :admin | :gestor_da_equipe | :gestor_da_organizacao}
          | {:nao, :conta_sem_pessoa_declarada | :vinculo_encerrado | :sem_concessao}
  def pode_gerir_estrutura(%Tenant{} = tenant, %User{} = user, team_id) do
    if User.admin?(user) and user.tenant_id == tenant.id do
      {:ok, :admin}
    else
      case Tenants.person_of_user(user) do
        {:ok, pessoa_id} -> StructureGrants.alcance(tenant, pessoa_id, team_id)
        :not_declared -> {:nao, :conta_sem_pessoa_declarada}
      end
    end
  end

  # O escopo da CONTA continua decidindo **visão** — `pode_ver/3` e `pode_ver_equipe/3` o
  # usam. O que ele deixou de decidir, em 2026-09-07, é **escrita** na estrutura: aquilo
  # passou a ser concessão a papel (`pode_gerir_estrutura/3`).
  defp tem_escopo?(tenant, user, nivel, alvo_id) do
    tenant
    |> scopes(user)
    |> Enum.any?(fn e -> e.level == nivel and e.target_id == alvo_id end)
  end

  @doc """
  Esta conta pode ver o painel desta pessoa? O motivo mais específico vence.
  """
  @spec pode_ver(Tenant.t(), User.t(), Ecto.UUID.t()) ::
          {:ok, atom()} | {:nao, atom()}
  def pode_ver(%Tenant{} = tenant, %User{} = user, alvo_person_id) do
    cond do
      # A própria pessoa decide em memória, ANTES de montar a união: é o caso mais
      # comum da página da pessoa, e o teto de consultas dela é guardado por teste
      # (L38 — o guardião reprovou a primeira versão, que montava tudo sempre).
      propria_pessoa?(user, alvo_person_id) ->
        {:ok, :propria_pessoa}

      # ADMINISTRAÇÃO ALCANÇA — achado H6, decisão da pessoa mantenedora em 2026-09-09.
      #
      # ## A contradição que esta cláusula fecha, e ela era de COMPORTAMENTO
      #
      # `pode_ver_equipe/3` já concedia ao admin explicitamente, e o booleano que ela
      # produz (`ve_por_pessoa?` em `teams_live/show.ex`) libera
      # `Quality.agrupar_por_pessoa/1` — **a quebra por pessoa nomeada**: login, itens
      # abertos e mediana individual de cada uma.
      #
      # Então administração já lia pessoa nomeada pela tela da EQUIPE, enquanto a tela
      # da PESSOA a recusava afirmando que *"being an administrator manages the
      # platform, it does not open panels"*. A frase era falsa — e não por um furo: o
      # mesmo dado saía pela porta ao lado, por decisão explícita do outro veredito.
      #
      # Não era inconsistência a arrumar: era a plataforma **afirmando um regime que
      # ela não aplicava**, que é pior que qualquer dos dois regimes.
      #
      # ## O que esta cláusula emenda
      #
      # A spec 023, FR-012, dizia deliberadamente que administrar não abre painel. A
      # emenda é da pessoa mantenedora, registrada em 2026-09-09, e o texto da recusa na
      # tela mudou junto — deixar a frase para trás seria trocar uma mentira por outra.
      #
      # `user.tenant_id == tenant.id` está aqui pela mesma razão de `pode_ver_equipe/3`:
      # administração de OUTRO tenant não é administração deste.
      User.admin?(user) and user.tenant_id == tenant.id ->
        {:ok, :admin}

      true ->
        pela_uniao(tenant, user, alvo_person_id)
    end
  end

  defp pela_uniao(tenant, user, alvo_person_id) do
    meus = scopes(tenant, user)

    if motivo = alcanca_por_escopo(tenant, meus, alvo_person_id) do
      {:ok, motivo}
    else
      # A liderança declarada (#369) soma por último — FR-018.
      case EO.Visibility.pode_ver(tenant, user, alvo_person_id) do
        {:ok, motivo} -> {:ok, motivo}
        {:nao, _} -> {:nao, motivo_da_recusa(meus)}
      end
    end
  end

  @doc """
  As pessoas que esta conta alcança — decisão da pessoa mantenedora, 2026-09-09.

  > *"Quem tem o escopo de team, organization e admin podem ver. E a pessoa vê o seu
  > perfil."*

  É o mesmo regime que `pode_ver/3` já aplica, respondido para um **conjunto** em vez
  de para um alvo. Existe porque `pode_ver/3` consulta as equipes do alvo — perguntar
  por linha numa lista de pessoas é a **L38**, o antipadrão que este módulo existe para
  evitar.

  ## O que devolve

  - `:todas` — administração do tenant. FR-023 continua de pé: ver não exige
    administrar, mas administrar alcança;
  - `{:algumas, MapSet}` — a união das pessoas das equipes em escopo, das equipes das
    organizações em escopo, e **a própria pessoa**, sempre.

  O conjunto pode vir **vazio** para conta sem elo declarado e sem concessão. Vazio não
  é erro nem é zero: é *nenhuma pessoa alcançada*, e quem apresenta MUST dizer isso em
  palavras.

  ## O custo

  Três consultas, e não uma por pessoa: as equipes das organizações em escopo numa
  consulta por organização em escopo (são poucas, e vêm de `scopes/2`), e os
  integrantes de **todas** as equipes numa só, via `escopo:` de
  `team_member_ids_at/4`.

  ## O que NÃO entra

  O escopo `project` — pela mesma razão de `pode_ver_equipe/3`: ele nomeia um projeto,
  e uma equipe pode trabalhar em vários. Deixá-lo passar faria autoridade subir de
  lado, e este documento prefere repetir a razão a deixá-la implícita.
  """
  @spec pessoas_alcancadas(Tenant.t(), User.t()) :: :todas | {:algumas, MapSet.t()}
  def pessoas_alcancadas(%Tenant{} = tenant, %User{} = user) do
    if User.admin?(user) do
      :todas
    else
      meus = scopes(tenant, user)
      agora = DateTime.utc_now()

      equipes_diretas = for s <- meus, s.level == :team, s.target_id, do: s.target_id

      equipes_das_orgs =
        for s <- meus,
            s.level == :organization,
            s.target_id,
            t <- EO.list_teams(tenant, organization_id: s.target_id),
            do: t.id

      equipes = Enum.uniq(equipes_diretas ++ equipes_das_orgs)

      pessoas =
        case equipes do
          [] -> []
          _ -> EO.team_member_ids_at(tenant, hd(equipes), agora, escopo: equipes)
        end

      # A PRÓPRIA PESSOA ENTRA SEMPRE, e não pelo escopo: quem não tem escopo nenhum
      # continua vendo o seu — é a segunda metade da decisão, e sem esta linha ela
      # ficaria por escrever.
      propria =
        case Tenants.person_of_user(user) do
          {:ok, person_id} -> [person_id]
          _ -> []
        end

      {:algumas, MapSet.new(pessoas ++ propria)}
    end
  end

  @doc """
  Esta conta alcança **esta equipe**? — feature 058, FR-024.

  A pergunta é da equipe, e não de cada pessoa dentro dela. A tela mostra a quebra
  por pessoa nomeada de uma seção inteira, e perguntar `pode_ver/3` por linha
  produziria consulta por linha — a L38, o antipadrão que este módulo existe para
  evitar.

  ## Por que ela existe

  A decisão registrada em 2026-08-26 (spec 023, FR-012) é que o painel de uma
  pessoa é visível para **a própria pessoa, o líder da equipe dela, e o responsável
  da organização** — e não para qualquer conta autenticada, que era o regime que
  vigorava **por omissão**.

  A tela da equipe passou a oferecer a mesma classe de leitura pela porta ao lado:
  login, solicitações abertas por pessoa nomeada e a mediana individual. Sem este
  veredito, a decisão de 2026-08-26 valeria numa rota e não na outra — e a rota é
  artefato do roteador, não fronteira do domínio.

  ## O que ela NÃO fecha

  O **agregado** da equipe — mediana, espera em curso, a ausência dita e as
  limitações — continua legível por qualquer conta do tenant. FR-023 segue de pé:
  ver não exige administrar. O que muda é que estranho deixa de ser tratado como
  colega.

  ## Os caminhos que abrem

  Admin do tenant; escopo `team` naquela equipe; escopo `organization` na
  organização dela; e o vínculo vigente — quem está na equipe vê o trabalho dela.
  O escopo `project` **não** entra: ele nomeia um projeto, e uma equipe pode
  trabalhar em vários; deixá-lo passar faria autoridade subir de lado.
  """
  @spec pode_ver_equipe(Tenant.t(), User.t(), Ecto.UUID.t()) ::
          {:ok, atom()} | {:nao, atom()}
  def pode_ver_equipe(%Tenant{} = tenant, %User{} = user, team_id) do
    cond do
      User.admin?(user) and user.tenant_id == tenant.id -> {:ok, :admin}
      tem_escopo?(tenant, user, :team, team_id) -> {:ok, :escopo_de_equipe}
      escopo_na_organizacao_da_equipe?(tenant, user, team_id) -> {:ok, :escopo_da_organizacao}
      membro_da_equipe?(tenant, user, team_id) -> {:ok, :vinculo_vigente}
      true -> {:nao, :fora_do_alcance}
    end
  end

  defp escopo_na_organizacao_da_equipe?(tenant, user, team_id) do
    orgs = for s <- scopes(tenant, user), s.level == :organization, s.target_id, do: s.target_id

    # A equipe só é lida quando há escopo de organização — sem ele a consulta não
    # decidiria nada (L38).
    orgs != [] and organizacao_da_equipe(tenant, team_id) in orgs
  end

  defp organizacao_da_equipe(tenant, team_id) do
    case Enum.find(EO.list_teams(tenant), &(&1.id == team_id)) do
      %{organization_id: org_id} -> org_id
      _ -> nil
    end
  end

  # O vínculo vigente é o que faz colega ver colega sem ninguém conceder nada.
  defp membro_da_equipe?(tenant, user, team_id) do
    case Tenants.person_of_user(user) do
      {:ok, person_id} ->
        tenant
        |> EO.person_active_teams(person_id)
        |> Enum.any?(&(&1.team_id == team_id))

      _ ->
        false
    end
  end

  defp propria_pessoa?(%User{} = user, alvo_person_id) do
    match?({:ok, ^alvo_person_id}, Tenants.person_of_user(user))
  end

  # Devolve o motivo (:escopo_de_equipe | :escopo_da_organizacao) — projeto NÃO entra,
  # e a razão está na cláusula que o recusa.
  # ou nil. Uma leitura das relações do ALVO, comparada aos meus alvos por nível —
  # e nenhuma leitura quando não tenho alvo nenhum (L38: o lado do alvo custa
  # duas consultas, e sem escopo com alvo elas não decidem nada).
  defp alcanca_por_escopo(tenant, meus, alvo_person_id) do
    if Enum.any?(meus, & &1.target_id) do
      comparar_com_alvo(tenant, meus, alvo_person_id)
    else
      nil
    end
  end

  defp comparar_com_alvo(tenant, meus, alvo_person_id) do
    alvo_equipes = EO.person_active_teams(tenant, alvo_person_id)
    alvo_team_ids = MapSet.new(alvo_equipes, & &1.team_id)

    # A organização do alvo vem por DOIS fatos: a equipe com vínculo promovido, e a
    # evidência vigente da origem. Só o primeiro deixava organization alcançar 4 de
    # 88 pessoas no dado real — o vínculo promovido quase não existe (101 evidências,
    # 0 promoções), e "pessoa da organização" na spec é quem a organização observa.
    alvo_org_ids =
      alvo_equipes
      |> MapSet.new(& &1.organization_id)
      |> MapSet.delete(nil)
      |> MapSet.union(MapSet.new(observed_orgs(tenant, meus, alvo_person_id)))

    # E A CONSULTA DOS PROJETOS DO ALVO SAIU JUNTO.
    #
    # Ela existia só para o ramo do escopo de projeto, que deixou de abrir painel. Uma
    # consulta por veredito de pessoa, removida — e `projetos_das_equipes/2` continua
    # servindo `scopes/2`, onde o escopo derivado de projeto **continua existindo** para o
    # que ele nomeia: o trabalho daquele projeto.

    alvos = fn nivel ->
      for s <- meus, s.level == nivel, s.target_id, into: MapSet.new(), do: s.target_id
    end

    cond do
      not MapSet.disjoint?(alvos.(:team), alvo_team_ids) ->
        :escopo_de_equipe

      # ESCOPO DE PROJETO **NÃO** ABRE PAINEL DE PESSOA — decisão da pessoa mantenedora
      # em 2026-09-09, e a razão já estava escrita no veredito ao lado.
      #
      # `pode_ver_equipe/3` recusava este mesmo escopo, com estas palavras: *"ele nomeia
      # um projeto, e uma equipe pode trabalhar em vários; deixá-lo passar faria
      # autoridade subir de lado"*.
      #
      # A razão vale igual aqui, e aqui vale MAIS: quem tinha escopo de um projeto
      # alcançava o painel **completo** de qualquer pessoa cuja equipe tocasse aquele
      # projeto — incluindo o trabalho dela em **outros** projetos, que aquele escopo não
      # nomeia. Era exactamente a autoridade subindo de lado, com um alcance maior que o
      # que o outro veredito recusava.
      #
      # **Não havia teste afirmando este caminho.** Ele existia sem ninguém o ter medido —
      # e é por isso que a correção vem com o teste que o guarda fechado.
      #
      # Quem tem escopo de projeto continua vendo **o trabalho daquele projeto**. O que
      # deixa de alcançar é a pessoa.
      not MapSet.disjoint?(alvos.(:organization), alvo_org_ids) ->
        :escopo_da_organizacao

      true ->
        nil
    end
  end

  # A evidência só é consultada quando tenho escopo organization — para os demais
  # é uma ida ao banco que não decide nada (L38).
  defp observed_orgs(tenant, meus, alvo_person_id) do
    if Enum.any?(meus, &(&1.level == :organization)),
      do: EO.person_observed_organization_ids(tenant, alvo_person_id),
      else: []
  end

  # Recusa com remédio certo: sem elo E sem escopo é um pedido de declaração;
  # concessões todas órfãs são outro; fora do alcance é o caso geral.
  defp motivo_da_recusa(meus) do
    cond do
      meus == [] ->
        :sem_elo_declarado

      Enum.all?(meus, &(&1.origin == :granted and is_nil(&1.target_name))) ->
        :alvo_da_concessao_nao_existe_mais

      true ->
        :fora_dos_escopos
    end
  end

  @doc "Concede escopo — só administrador, alvo obrigatório e existente (FR-007/008)."
  @spec grant(
          Tenant.t(),
          Ecto.UUID.t(),
          :team | :project | :organization,
          Ecto.UUID.t(),
          User.t()
        ) ::
          {:ok, ScopeGrant.t()} | {:error, :not_admin | :target_not_found | Ecto.Changeset.t()}
  def grant(%Tenant{} = tenant, user_id, level, target_id, %User{} = actor)
      when level in [:team, :project, :organization] do
    cond do
      # Administrador DESTE tenant: a marca é da conta, e a conta é de um tenant —
      # um admin de fora não concede aqui, seja lá como a chamada chegou.
      not (User.admin?(actor) and actor.tenant_id == tenant.id) ->
        {:error, :not_admin}

      # A CONTA também é conferida contra o tenant, e aqui — não só na tela. Uma
      # função que decide acesso não pode depender de quem a chama ter conferido
      # (a mesma doutrina que valia para o ramo do admin no Visibility). Sem esta
      # linha, um admin gravaria concessão para conta de OUTRO tenant — órfã e
      # inerte, mas linha de acesso errada é linha de acesso errada.
      not user_do_tenant?(tenant, user_id) ->
        {:error, :target_not_found}

      not target_exists?(tenant, level, target_id) ->
        {:error, :target_not_found}

      true ->
        %ScopeGrant{}
        |> ScopeGrant.changeset(%{
          tenant_id: tenant.id,
          user_id: user_id,
          level: Atom.to_string(level),
          target_id: target_id,
          granted_by_user_id: actor.id,
          granted_at: DateTime.utc_now(:second)
        })
        |> Repo.insert()
    end
  end

  @doc "Revoga por marca — só administrador (FR-008); derivado nunca passa por aqui."
  @spec revoke(Tenant.t(), Ecto.UUID.t(), User.t()) ::
          {:ok, ScopeGrant.t()} | {:error, :not_admin | :not_found}
  def revoke(%Tenant{id: tenant_id}, grant_id, %User{} = actor) do
    cond do
      not (User.admin?(actor) and actor.tenant_id == tenant_id) ->
        {:error, :not_admin}

      grant =
          Repo.one(
            from g in ScopeGrant,
              where: g.id == ^grant_id and g.tenant_id == ^tenant_id and is_nil(g.revoked_at)
          ) ->
        grant |> ScopeGrant.revoke_changeset(actor.id) |> Repo.update()

      true ->
        {:error, :not_found}
    end
  end

  @doc """
  FR-023: quem alcança as telas operacionais, e com que recorte.

  Uma consulta só, e direto nas concessões: organization NÃO tem caminho
  derivado (contrato), então a união inteira não precisa ser montada — e isso
  importa porque o menu pergunta isto a cada tela.
  """
  @spec operacional?(Tenant.t(), User.t()) ::
          {true, :admin | {:organizations, [Ecto.UUID.t()]}} | false
  def operacional?(%Tenant{id: tenant_id}, %User{} = user) do
    cond do
      User.admin?(user) ->
        {true, :admin}

      (orgs =
         Repo.all(
           from g in ScopeGrant,
             where:
               g.tenant_id == ^tenant_id and g.user_id == ^user.id and
                 g.level == "organization" and is_nil(g.revoked_at),
             select: g.target_id
         )) != [] ->
        {true, {:organizations, orgs}}

      true ->
        false
    end
  end

  defp user_do_tenant?(%Tenant{id: tenant_id}, user_id) do
    Repo.exists?(from u in User, where: u.id == ^user_id and u.tenant_id == ^tenant_id)
  end

  defp target_exists?(tenant, :team, id), do: EO.teams_by_ids(tenant, [id]) != %{}
  defp target_exists?(tenant, :project, id), do: SPO.projects_by_ids(tenant, [id]) != %{}

  defp target_exists?(tenant, :organization, id),
    do: Enum.any?(EO.list_organizations(tenant), &(&1.id == id))
end
