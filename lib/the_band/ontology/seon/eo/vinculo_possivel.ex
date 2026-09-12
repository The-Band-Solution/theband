defmodule TheBand.Ontology.SEON.EO.VinculoPossivel do
  @moduledoc """
  O **veredito** antes do botão — feature 055, FR-003, protótipo aprovado em 2026-09-11.

  Quem administra procura uma pessoa para vincular a uma equipe. Antes de oferecer o ato, a
  tela diz **o que aquela pessoa já tem** e **o que este ato faria** — e há seis situações
  distintas, com consequências diferentes.

  Sem o veredito, duas delas seriam erro na cara de quem clica e uma quarta seria pior: um
  vínculo direto numa equipe composta **não muda a contagem de membros**, porque a pessoa já
  era contada pela subequipe. Descobrir isso depois do ato é descobrir que o número não mexeu
  e não saber por quê.

  ## Os seis vereditos

  | veredito | quando | o ato |
  |---|---|---|
  | `:permitido` | a pessoa não tem nada nesta equipe nem nas partes dela | vincula |
  | `:recusado_ja_e_membro` | tem vínculo **vigente** aqui | **recusa**, e aponta o ato certo: declarar o papel daquele vínculo |
  | `:permitido_fato_diferente` | tem vínculo vigente numa **subequipe** desta | vincula, e a contagem de membros **não muda** |
  | `:permitido_vinculo_novo` | teve vínculo aqui e **saiu** | vincula, e os dois períodos coexistem |
  | `:permitido_equivoco_fica` | teve vínculo aqui marcado **equívoco** | vincula, e o equívoco **não** é apagado nem contradito |
  | `:permitido_leia_a_marca` | a origem **deixou de mostrar** a pessoa | vincula, e nada vai confirmar nem encerrar este vínculo |

  ## A ordem das cláusulas é a decisão

  `:recusado_ja_e_membro` vem **antes** de tudo: quem já é membro não recebe um segundo
  vínculo, e o que falta ali é o **papel**. E `:permitido_leia_a_marca` vem **por último**
  entre os permitidos — a marca de não-observada é sobre a pessoa, e o que ela tem nesta
  equipe é o fato mais específico.

  ## Uma consulta para a busca inteira

  A tela mostra até oito resultados. Um veredito por pessoa custaria oito idas ao banco por
  tecla digitada — e a busca roda no evento da digitação. Aqui são **duas**: os vínculos das
  pessoas encontradas nesta equipe e nas partes dela, e as partes.
  """

  import Ecto.Query

  alias TheBand.Ontology.SEON.EO.Queries
  alias TheBand.Ontology.SEON.EO.Schemas.TeamMembership
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @type veredito ::
          :permitido
          | :recusado_ja_e_membro
          | :permitido_fato_diferente
          | :permitido_vinculo_novo
          | :permitido_equivoco_fica
          | :permitido_leia_a_marca

  @doc """
  O veredito de cada pessoa da lista, para esta equipe.

  Devolve `%{person_id => {veredito, contexto}}`. O contexto carrega o que a tela precisa
  escrever ao lado: o id do vínculo vigente quando há um (para o *declare her role*), e o
  nome da subequipe quando o vínculo está nela.

  `pessoas` são os resultados da busca — mapas com ao menos `:id` e `:no_longer_observed_at`.
  """
  @spec vereditos(Tenant.t(), Ecto.UUID.t(), [map()]) :: %{
          Ecto.UUID.t() => {veredito(), map()}
        }
  def vereditos(%Tenant{} = tenant, team_id, pessoas) when is_list(pessoas) do
    if pessoas == [] do
      %{}
    else
      ids = Enum.map(pessoas, & &1.id)
      partes = Map.new(Queries.team_parts(tenant, team_id), &{&1.team_id, &1.name})
      escopo = [team_id | Map.keys(partes)]

      por_pessoa =
        vinculos(tenant, escopo, ids)
        |> Enum.group_by(& &1.person_id)

      Map.new(pessoas, fn pessoa ->
        {pessoa.id, decidir(pessoa, Map.get(por_pessoa, pessoa.id, []), team_id, partes)}
      end)
    end
  end

  @doc """
  Os vínculos daquelas pessoas nesta equipe e nas partes dela — **uma** consulta.

  Traz encerrados e invalidados de propósito: o veredito depende de distinguir *saiu*,
  *equívoco* e *nunca teve*, e as três são ausências diferentes.
  """
  @spec vinculos(Tenant.t(), [Ecto.UUID.t()], [Ecto.UUID.t()]) :: [map()]
  def vinculos(%Tenant{id: tenant_id}, equipes, pessoas) do
    TeamMembership
    |> where([m], m.tenant_id == ^tenant_id and m.team_id in ^equipes and m.person_id in ^pessoas)
    |> select([m], %{
      person_id: m.person_id,
      team_id: m.team_id,
      membership_id: m.id,
      started_at: m.started_at,
      ended_at: m.ended_at,
      invalidated_at: m.invalidated_at,
      papel_declarado?: not is_nil(m.organizational_role_id)
    })
    |> Repo.all()
  end

  # A ORDEM AQUI É A DECISÃO, e cada cláusula responde a uma pergunta diferente.
  defp decidir(pessoa, vinculos, team_id, partes) do
    aqui = Enum.filter(vinculos, &(&1.team_id == team_id))
    vigente_aqui = Enum.find(aqui, &vigente?/1)

    nas_partes = Enum.filter(vinculos, &(&1.team_id != team_id and vigente?(&1)))

    cond do
      # 1. JÁ É MEMBRO — recusa, e aponta o ato certo. Um segundo vínculo vigente não
      #    existe: o índice parcial o recusaria, e o que falta ali é o PAPEL.
      vigente_aqui ->
        {:recusado_ja_e_membro,
         %{
           membership_id: vigente_aqui.membership_id,
           papel_declarado?: vigente_aqui.papel_declarado?
         }}

      # 2. VÍNCULO NUMA SUBEQUIPE — permitido, e é outro fato. A contagem de membros da
      #    equipe composta NÃO muda: a pessoa já era contada pela parte.
      nas_partes != [] ->
        nomes = nas_partes |> Enum.map(&Map.get(partes, &1.team_id)) |> Enum.reject(&is_nil/1)
        {:permitido_fato_diferente, %{squads: nomes}}

      # 3. SAIU DAQUI — vínculo novo, e os dois períodos coexistem. Nada já contado muda.
      Enum.any?(aqui, &(not is_nil(&1.ended_at) and is_nil(&1.invalidated_at))) ->
        {:permitido_vinculo_novo, %{}}

      # 4. EQUÍVOCO AQUI — o equívoco fica. Ele não é apagado nem contradito pelo vínculo
      #    novo, e *equívoco* e *saída* nunca colapsam num só.
      Enum.any?(aqui, &(not is_nil(&1.invalidated_at))) ->
        {:permitido_equivoco_fica, %{}}

      # 5. A ORIGEM DEIXOU DE MOSTRAR — permitido, e é o caso para o qual a FR-003 existe.
      #    Nada vai confirmar nem encerrar este vínculo, e a tela diz isso ANTES do ato.
      not is_nil(Map.get(pessoa, :no_longer_observed_at)) ->
        {:permitido_leia_a_marca, %{desde: Map.get(pessoa, :no_longer_observed_at)}}

      true ->
        {:permitido, %{}}
    end
  end

  # Vigente é o que não terminou E não foi invalidado. Início nulo é DESCONHECIDO, e conta —
  # 87 dos 90 vínculos do banco de desenvolvimento, medido em 2026-09-10.
  defp vigente?(%{ended_at: nil, invalidated_at: nil}), do: true
  defp vigente?(_), do: false
end
