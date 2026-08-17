defmodule TheBand.Profiles.Regeneration do
  @moduledoc """
  Quem entra na rodada, e — para quem não entra — **qual** dos motivos. Feature 027.

  Este módulo não gera nada: decide. E decide devolvendo o motivo junto, porque a `FR-014`
  conta por motivo. Um booleano obrigaria quem chama a redescobrir o porquê, que é o
  antipadrão "booleano no lugar do relator" de `AGENTS.md` §7.7.

  ## Os dois ramos da `FR-006` alcançam gente diferente

  N alcança quem trabalhou muito e cujo texto ficou para trás. M alcança quem trabalhou pouco
  e cujo texto ficaria parado para sempre se só N valesse. Medido em 2026-08-16: 14 de 34
  pessoas não fecharam **nenhuma** tarefa em 30 dias.
  """

  import Ecto.Query

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO.Profiles, as: EOProfiles
  alias TheBand.Ontology.SEON.EO.Schemas.Person
  alias TheBand.Profiles.Material
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @type veredito :: :generate | {:skip, :no_material | :no_new_work | :observation_ended}
  @type limiares :: %{n: pos_integer(), m_months: pos_integer()}

  @doc """
  Os limiares N e M, lidos da base de conhecimento.

  **Não há padrão embutido** — `FR-009`. Ausente ou inválido devolve erro, e a rodada não
  executa. Um padrão silencioso faria a plataforma decidir sobre quem escrever com um número
  que ninguém escolheu.

  Lido a cada chamada, e não em atributo de módulo: atributo é avaliado em compilação, e a
  mudança no YAML não teria efeito sem recompilar — que é justamente o que a US3 recusa.
  """
  @spec thresholds() :: {:ok, limiares()} | {:error, term()}
  def thresholds do
    case KnowledgeBase.rule("profile.thresholds") do
      {:ok, regra} -> thresholds_de(regra)
      :error -> {:error, :regra_ausente}
    end
  end

  @doc """
  Os limiares a partir de uma regra já lida — a costura que torna o ramo do erro testável.

  Sem ela, provar que a ausência do limiar **reprova** exigiria mexer na base carregada em
  ETS, que é global ao nó. E o ramo do erro é justamente o que a `FR-009` existe para
  garantir: um padrão embutido faria a rodada usar um número que ninguém escolheu.
  """
  @spec thresholds_de(map()) :: {:ok, limiares()} | {:error, term()}
  def thresholds_de(regra) do
    with %{"values" => valores} <- get_in(regra, ["rules", "regeneration"]),
         n when is_integer(n) and n > 0 <- valores["min_new_closed_tasks"],
         m when is_integer(m) and m > 0 <- valores["max_profile_age_months"] do
      {:ok, %{n: n, m_months: m}}
    else
      nil -> {:error, :regeneration_ausente}
      outro -> {:error, {:limiar_invalido, outro}}
    end
  end

  @doc """
  A lista completa de pessoas **consideradas**, cada uma com o veredito.

  Inclui quem será pulado: a `FR-014` conta por motivo, e um `select` que devolvesse só quem
  gera não teria como alimentar a contagem.

  A ordem é declarada — mais tarefas novas primeiro. Se a rodada morrer no meio, terá gerado
  quem tinha mais o que dizer de novo.

  ## O escopo, e por que ele existe — emenda de 2026-08-16 à `FR-004`

  `:mudou` é a rodada automática: a regra de mudança da `FR-006` decide, porque texto que
  ninguém pediu só se justifica quando o material mudou. `:todas` é a rodada manual: pedir a
  mão **já é** a decisão de escrever, e a regra de mudança deixaria de fora exatamente quem a
  pessoa administradora quer ver escrito. Os pulos que sobram em `:todas` são de fato, não de
  critério — sem material e observação encerrada.
  """
  @spec select(Tenant.t(), :mudou | :todas) ::
          {:ok, [{Person.t(), veredito()}]} | {:error, term()}
  def select(%Tenant{} = tenant, escopo \\ :mudou) when escopo in [:mudou, :todas] do
    with {:ok, limiares} <- thresholds() do
      vereditos =
        tenant
        |> pessoas()
        |> Enum.map(&{&1, due?(tenant, &1, limiares, escopo), novas(tenant, &1)})
        |> Enum.sort_by(fn {_p, _v, novas} -> -novas end)
        |> Enum.map(fn {pessoa, veredito, _novas} -> {pessoa, veredito} end)

      {:ok, vereditos}
    end
  end

  @doc """
  O veredito de uma pessoa, na ordem em que os motivos se excluem.

  1. observação encerrada (`FR-008`);
  2. não passa nos pisos da feature 026 (`FR-005`);
  3. sem perfil anterior — gera, porque não há recorte contra o qual comparar (`FR-007`);
  4. tarefas concluídas **depois do fim do recorte** ≥ N;
  5. perfil vigente **gerado** há mais de M meses;
  6. caso contrário, não há trabalho novo que justifique texto novo.

  Os dois extremos dos passos 4 e 5 são diferentes de propósito: a contagem parte do fim do
  recorte, que é a última data que o texto alcança; a idade parte da data de geração, que é a
  data que a tela exibe.

  Com escopo `:todas`, os passos 4 a 6 não existem: quem chegou ao passo 3 gera, com ou sem
  perfil anterior. Os dois primeiros continuam valendo — são fato, não critério.
  """
  @spec due?(Tenant.t(), Person.t(), limiares(), :mudou | :todas) :: veredito()
  def due?(%Tenant{} = tenant, %Person{} = pessoa, limiares, escopo \\ :mudou) do
    if pessoa.no_longer_observed_at != nil do
      {:skip, :observation_ended}
    else
      decidir(tenant, pessoa, limiares, escopo)
    end
  end

  # O perfil anterior decide o MODO do material antes de decidir a geração: a primeira
  # vez pega tudo que tem texto (decisão de 2026-08-16 — os pisos protegem a comparação,
  # e não há o que comparar); da segunda em diante, os pisos inteiros.
  defp decidir(tenant, pessoa, %{n: n, m_months: m}, escopo) do
    case EOProfiles.current(tenant, pessoa.id) do
      {:error, :not_found} -> primeira_geracao(tenant, pessoa)
      {:ok, perfil} -> geracao_seguinte(tenant, pessoa, perfil, n, m, escopo)
    end
  end

  defp primeira_geracao(tenant, pessoa) do
    if Material.check(tenant, pessoa.id, :primeira) == :ok,
      do: :generate,
      else: {:skip, :no_material}
  end

  defp geracao_seguinte(tenant, pessoa, perfil, n, m, escopo) do
    cond do
      Material.check(tenant, pessoa.id) != :ok -> {:skip, :no_material}
      escopo == :todas -> :generate
      true -> comparar(tenant, pessoa, perfil, n, m)
    end
  end

  defp comparar(tenant, pessoa, perfil, n, m) do
    cond do
      fechadas_apos(tenant, pessoa.id, perfil.period_to) >= n -> :generate
      envelheceu?(perfil.generated_at, m) -> :generate
      true -> {:skip, :no_new_work}
    end
  end

  # `nil` em `period_to` é perfil gerado antes de o recorte virar coluna. Sem a data não há
  # como contar "depois do recorte", e o ramo do M é quem decide — nunca zero, que faria a
  # pessoa parecer sem trabalho novo quando o que falta é a data.
  defp fechadas_apos(_tenant, _person_id, nil), do: 0

  defp fechadas_apos(%Tenant{id: tenant_id}, person_id, %Date{} = fim) do
    {:ok, corte} = DateTime.new(fim, ~T[23:59:59], "Etc/UTC")

    from(i in "collected_issues",
      join: a in "issue_assignees",
      on: a.collected_issue_id == i.id and is_nil(a.no_longer_observed_at),
      where:
        i.tenant_id == type(^tenant_id, :binary_id) and
          a.person_id == type(^person_id, :binary_id) and
          i.state == "CLOSED" and i.external_closed_at > ^corte,
      select: count(i.id)
    )
    |> Repo.one()
  end

  defp envelheceu?(nil, _m), do: false

  defp envelheceu?(%DateTime{} = gerado_em, m) do
    DateTime.compare(gerado_em, meses_atras(m)) == :lt
  end

  defp meses_atras(m) do
    DateTime.utc_now(:second)
    |> DateTime.to_date()
    |> Date.add(-30 * m)
    |> DateTime.new!(~T[00:00:00], "Etc/UTC")
  end

  # Quantas tarefas novas a pessoa tem desde o recorte — só para ordenar. Quem não tem perfil
  # vai para o fim da ordenação por este número, e para o começo pelo veredito: `select/1`
  # ordena por trabalho novo, e sem perfil não há "novo" contra o que medir.
  defp novas(tenant, %Person{} = pessoa) do
    case EOProfiles.current(tenant, pessoa.id) do
      {:ok, perfil} -> fechadas_apos(tenant, pessoa.id, perfil.period_to)
      {:error, :not_found} -> 0
    end
  end

  defp pessoas(%Tenant{id: tenant_id}) do
    Repo.all(
      from p in Person,
        where: p.tenant_id == ^tenant_id and p.account_type == "person",
        order_by: [asc: p.login]
    )
  end
end
