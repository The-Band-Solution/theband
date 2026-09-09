defmodule TheBand.Tenants.AccessEvents do
  @moduledoc """
  Os eventos de acesso, num lugar só — achado **H4**, 2026-09-09.

  ## O que não havia

  O `grep` por `Logger` nos oito arquivos que decidem acesso voltava **vazio**. Não
  ficava registrado: entrada aceita, entrada recusada, desaceleração acionada, recusa de
  painel, concessão criada ou revogada, elo declarado ou revogado, troca de senha, queda
  de sessão por token divergente.

  **Consequência**: com dado real em produção, a plataforma não tinha como reconstruir um
  incidente de acesso. E isso valia contra os achados H1, H2 e H3 — se qualquer um deles
  tivesse sido explorado desde que a v0.6.0 subiu, **não havia como saber**.

  ## O ponto que dava a severidade, e é específico desta implementação

  `Auth.registrar_sucesso/1` gravava `failed_attempts: 0` e `last_failed_at: nil`. Esses
  dois campos eram o **único** rastro de tentativa falha, e são um **contador de estado**,
  não um histórico.

  > **Uma campanha de adivinhação de senha que dá certo apagava a própria evidência.**

  As tentativas falhas sumiam no instante do sucesso, e não sobrava nada que dissesse que
  houve campanha. Este módulo registra **quantas foram apagadas** antes de as apagar — que
  é o que transforma o contador num rastro, sem tabela nova.

  ## A regra que a forma deste módulo obedece — L69

  A **L69** desta base diz que **defeito dentro de `Logger.info` é invisível a teste**,
  porque o nível é configuração. Então a divisão é deliberada:

  - **a decisão continua no retorno** de quem decide. `Auth.authenticate/2` devolve
    `{:error, {:throttled, s}}` distinto de `{:error, :invalid_credentials}`;
    `Access.pode_ver/3` devolve `{:nao, motivo}`. É sobre esses valores que os testes
    afirmam;
  - **este módulo é registro**, e não decisão. Nenhuma função daqui muda o que acontece —
    se todas fossem removidas, a plataforma se comportaria igual e perderia só a
    capacidade de responder *"isto já aconteceu?"*;
  - onde não havia relator, ele **nasce junto** com o log. Foi o caso da queda de sessão:
    `CurrentScope.sem_sessao/1` derrubava sem dizer por quê, e passou a devolver o motivo.

  ## O que NUNCA vai para o log

  Senha, `session_token`, senha temporária, hash. Os cinco campos sensíveis já são
  `redact: true` no schema — **e isso protege o `inspect/1`, não uma interpolação escrita à
  mão**. Por isso este módulo recebe **identificadores e motivos**, nunca credencial: não é
  uma disciplina de quem chama, é o que a assinatura das funções permite passar.

  ## Os campos, e de onde eles vêm

  `AGENTS.md` §15 lista os campos de observabilidade. Os que se aplicam a acesso —
  `tenant_id`, `user_id`, `request_id` — entram por `Logger.metadata` no plug e nas hooks,
  e valem para **toda** linha de log daquela requisição, e não só para as daqui.
  """
  require Logger

  @doc """
  Entrada aceita.

  `apagadas` é o número de tentativas falhas que o sucesso apagou, e é o campo que
  responde *"houve campanha?"*. Zero é o caso normal; qualquer número alto num sucesso é
  o sinal que não existia antes deste achado.
  """
  @spec entrada_aceita(Ecto.UUID.t(), Ecto.UUID.t() | nil, non_neg_integer()) :: :ok
  def entrada_aceita(user_id, tenant_id, apagadas) when is_integer(apagadas) do
    registrar("entrada aceita", user_id: user_id, tenant_id: tenant_id, falhas_apagadas: apagadas)
  end

  @doc """
  Entrada recusada, **com o motivo interno**.

  Na resposta HTTP a recusa é única — motivo distinto ali seria enumeração (FR-002). Aqui
  o motivo é o que permite distinguir depois *"senha errada"* de *"conta desativada"* de
  *"organização suspensa"*, que é a pergunta de quem reconstrói um incidente.

  `user_id` é `nil` quando o identificador não resolveu para conta nenhuma — e o log diz
  isso em vez de omitir a linha.
  """
  @spec entrada_recusada(Ecto.UUID.t() | nil, Ecto.UUID.t() | nil, atom()) :: :ok
  def entrada_recusada(user_id, tenant_id, motivo) when is_atom(motivo) do
    registrar("entrada recusada", user_id: user_id, tenant_id: tenant_id, motivo: motivo)
  end

  @doc "Desaceleração acionada — o `{:throttled, segundos}` que morria no retorno."
  @spec espera_acionada(Ecto.UUID.t(), Ecto.UUID.t() | nil, pos_integer()) :: :ok
  def espera_acionada(user_id, tenant_id, segundos) do
    registrar("espera acionada", user_id: user_id, tenant_id: tenant_id, segundos: segundos)
  end

  @doc """
  Acesso a dado de pessoa recusado pelo veredito.

  O motivo vem de `pode_ver/3` e é o mesmo que a tela usa para escolher a frase — então
  este log não inventa vocabulário: ele registra o veredito que já existia.
  """
  @spec painel_recusado(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t(), atom()) :: :ok
  def painel_recusado(user_id, tenant_id, alvo_person_id, motivo) do
    registrar("painel recusado",
      user_id: user_id,
      tenant_id: tenant_id,
      alvo_person_id: alvo_person_id,
      motivo: motivo
    )
  end

  @doc """
  Sessão derrubada, com o motivo.

  Os quatro motivos caem no mesmo destino na tela — `/sign-in`, sem dizer qual — e é
  deliberado: quem foi devolvido à entrada não recebe informação sobre o estado da conta.
  **No log eles se distinguem**, porque é onde a distinção serve.
  """
  @spec sessao_derrubada(Ecto.UUID.t() | nil, Ecto.UUID.t() | nil, atom()) :: :ok
  def sessao_derrubada(user_id, tenant_id, motivo) when is_atom(motivo) do
    registrar("sessão derrubada", user_id: user_id, tenant_id: tenant_id, motivo: motivo)
  end

  @doc """
  Ato administrativo sobre acesso — concessão, revogação, elo, desativação.

  `ato` é o nome do que aconteceu; `sobre` é quem sofreu. Quem executou vem do
  `Logger.metadata` da requisição, e não do argumento — passar o ator à mão convidaria a
  passar o errado.
  """
  @spec ato_administrativo(atom(), Ecto.UUID.t(), Ecto.UUID.t() | nil, keyword()) :: :ok
  def ato_administrativo(ato, sobre_user_id, tenant_id, extra \\ []) when is_atom(ato) do
    registrar(
      "ato administrativo",
      [ato: ato, sobre_user_id: sobre_user_id, tenant_id: tenant_id] ++ extra
    )
  end

  # `warning` para recusa e para ato administrativo; `info` para o resto.
  #
  # Não é estética: em produção o nível é `:info` (`config/prod.exs`), e um incidente se
  # investiga filtrando. Recusa e ato administrativo são o que se filtra primeiro.
  defp registrar(evento, campos) do
    nivel =
      if evento in ["entrada recusada", "painel recusado", "ato administrativo"],
        do: :warning,
        else: :info

    Logger.log(nivel, fn ->
      "acesso: #{evento} · " <>
        Enum.map_join(campos, " ", fn {k, v} -> "#{k}=#{inspect(v)}" end)
    end)
  end
end
