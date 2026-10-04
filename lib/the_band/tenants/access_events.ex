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

  # ------------------------------------------------- o passo de jornada (spec 074)
  #
  # Contrato em `specs/074-jornada-entrar-e-sair/contracts/jornada.md` §1–2. Esta função é **só de
  # emissão**: não loga — as funções de log abaixo não mudam — e não decide nada. O evento é
  # traduzido em span por `TheBand.Telemetria.Jornada`, fora do domínio.
  #
  # **As guardas são a terceira camada de S1** (seguranca.md): só passam átomo da lista, id
  # binário e o correlator. Struct de conta, `conn`, changeset e texto livre não cabem na
  # assinatura — e por isso nenhum handler anexado ao mesmo evento os recebe.

  @passos [
    :abrir_a_entrada,
    :entrar_com_senha,
    :sair,
    :sessao_derrubada,
    :definir_a_senha,
    :trocar_a_senha
  ]

  @type passo ::
          :abrir_a_entrada
          | :entrar_com_senha
          | :sair
          | :sessao_derrubada
          | :definir_a_senha
          | :trocar_a_senha

  # As guardas de `passo/1`, nomeadas. Juntas na cabeça, eram uma expressão só que ninguém lia.
  # `motivo` é `nil` se e só se o desfecho é `:concluiu`; um booleano não é motivo.
  defguardp e_desfecho(desfecho, motivo)
            when (desfecho == :concluiu and is_nil(motivo)) or
                   (desfecho == :falhou and is_atom(motivo) and not is_nil(motivo) and
                      not is_boolean(motivo))

  defguardp e_id(valor) when is_nil(valor) or is_binary(valor)

  # As cinco chaves obrigatórias, e no máximo `jornada_id` além delas: um mapa com qualquer
  # outra chave — `senha`, `email`, `conn` — não passa.
  defguardp so_as_chaves(dados)
            when map_size(dados) == 5 or
                   (map_size(dados) == 6 and is_map_key(dados, :jornada_id) and
                      e_id(:erlang.map_get(:jornada_id, dados)))

  @doc """
  Emite um passo da jornada de entrar e sair, como evento `[:the_band, :jornada, :passo]`.

  `motivo` é `nil` **se e só se** `desfecho` é `:concluiu`. `jornada_id` é opcional, e só vem em
  `abrir_a_entrada` e `entrar_com_senha`. Qualquer outra forma levanta `FunctionClauseError`:
  é bug de quem chama, e a régua (`test/the_band/telemetria/regua_test.exs`) o pega.
  """
  @spec passo(%{
          required(:passo) => passo(),
          required(:desfecho) => :concluiu | :falhou,
          required(:motivo) => atom() | nil,
          required(:tenant_id) => Ecto.UUID.t() | nil,
          required(:user_id) => Ecto.UUID.t() | nil,
          optional(:jornada_id) => String.t() | nil
        }) :: :ok
  def passo(
        %{
          passo: passo,
          desfecho: desfecho,
          motivo: motivo,
          tenant_id: tenant_id,
          user_id: user_id
        } =
          dados
      )
      when passo in @passos and e_desfecho(desfecho, motivo) and e_id(tenant_id) and
             e_id(user_id) and so_as_chaves(dados) do
    :telemetry.execute([:the_band, :jornada, :passo], %{}, %{
      jornada: :entrar_e_sair,
      passo: passo,
      desfecho: desfecho,
      motivo: motivo,
      tenant_id: tenant_id,
      user_id: user_id,
      jornada_id: Map.get(dados, :jornada_id)
    })
  end

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
  Recusa de **equipe** — feature 062, T022, e o achado N6 do inventário de 2026-09-24.

  `painel_recusado/4` é por **pessoa**. A recusa de equipe não deixava rastro em lugar nenhum:
  a API caía num `404` sem registro, a tela também, e o `ApiReadLog` só grava sucesso. A
  pergunta *"esta credencial tentou ler o painel de qual equipe?"* não tinha resposta, e é a
  que a FR-024 da 045 aponta como o caminho para perceber agregação.

  É chamada nas três portas: a tela da equipe, `GET /api/v1/teams/:id` e o registro de
  ferramentas do MCP. `motivo` fica no vocabulário da regra (`fora_do_alcance`), o mesmo da
  resposta. Equipe inexistente e de outro tenant também chegam aqui, com o mesmo motivo que a
  resposta dá, porque é a mesma recusa.
  """
  @spec equipe_recusada(Ecto.UUID.t(), Ecto.UUID.t(), String.t(), atom()) :: :ok
  def equipe_recusada(user_id, tenant_id, alvo_team_id, motivo) when is_atom(motivo) do
    registrar("equipe recusada",
      user_id: user_id,
      tenant_id: tenant_id,
      alvo_team_id: alvo_team_id,
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

  @doc """
  A conta da organização declarada ou revogada, ou a recusa — feature 076, T025 (R14; A20).

  `ato` é o que se tentou; `resultado` é `:ok` ou o motivo da recusa (`:not_admin`, `:not_found`,
  `:own_person`, `:linked_to_platform_account`, `:invalid`). Quem agiu vai explícito, e não só no
  `Logger.metadata`: a declaração tira uma pessoa das duas redes, e o rastro precisa dizer quem o
  fez mesmo fora de uma requisição. Só ids e átomos cabem na assinatura.
  """
  @spec conta_da_organizacao(
          :conta_da_organizacao_declarada | :conta_da_organizacao_revogada,
          Ecto.UUID.t(),
          Ecto.UUID.t(),
          Ecto.UUID.t() | nil,
          atom()
        ) :: :ok
  def conta_da_organizacao(ato, tenant_id, actor_user_id, person_id, resultado)
      when ato in [:conta_da_organizacao_declarada, :conta_da_organizacao_revogada] and
             is_binary(tenant_id) and is_binary(actor_user_id) and
             (is_binary(person_id) or is_nil(person_id)) and is_atom(resultado) do
    registrar("ato administrativo",
      ato: ato,
      tenant_id: tenant_id,
      actor_user_id: actor_user_id,
      person_id: person_id,
      resultado: resultado
    )
  end

  # ------------------------------------------------- o operador da plataforma (spec 070)
  #
  # Contrato em `specs/070-operador-da-plataforma/contracts/eventos-de-acesso.md` (FR-010, O14,
  # A7). Todos em `:warning`. O ator vem do `Logger.metadata(operator_id: …)` do plug da área do
  # operador, e nunca de `user_id`, que significa `users.id` em toda linha (research R12).
  #
  # **As guardas são a proteção**: cada função aceita só id, átomo e contagem. Código de
  # definição, de cadastro, de guarda, de recuperação, código TOTP, senha e segredo não cabem em
  # nenhuma assinatura, e um teste confere que nenhum aparece numa linha capturada (A7).

  @doc "Suspensão ou reativação de uma organização. `tenant_id` é o da organização **afetada**."
  @spec ato_de_plataforma(
          :organizacao_suspensa | :organizacao_reativada,
          Ecto.UUID.t(),
          keyword()
        ) ::
          :ok
  def ato_de_plataforma(ato, tenant_id, extra)
      when ato in [:organizacao_suspensa, :organizacao_reativada] and is_list(extra) do
    registrar_operador("ato de plataforma", [ato: ato, tenant_id: tenant_id] ++ extra)
  end

  @doc "O papel de operador concedido pelo comando de release."
  @spec operador_concedido(Ecto.UUID.t(), String.t()) :: :ok
  def operador_concedido(operator_id, declarado_por) when is_binary(declarado_por),
    do:
      registrar_operador("operador concedido",
        operator_id: operator_id,
        declarado_por: declarado_por,
        via: :release_command
      )

  @doc "O papel de operador revogado pelo comando de release, com quantas sessões caíram."
  @spec operador_revogado(Ecto.UUID.t(), String.t(), non_neg_integer()) :: :ok
  def operador_revogado(operator_id, declarado_por, sessoes)
      when is_binary(declarado_por) and is_integer(sessoes),
      do:
        registrar_operador("operador revogado",
          operator_id: operator_id,
          declarado_por: declarado_por,
          sessoes_encerradas: sessoes,
          via: :release_command
        )

  @doc "A credencial do operador reiniciada pelo comando de release."
  @spec operador_credencial_reiniciada(Ecto.UUID.t(), String.t()) :: :ok
  def operador_credencial_reiniciada(operator_id, declarado_por) when is_binary(declarado_por),
    do:
      registrar_operador("operador credencial reiniciada",
        operator_id: operator_id,
        declarado_por: declarado_por,
        via: :release_command
      )

  @doc "Entrada do operador aceita, com quantas tentativas falhas o sucesso apagou."
  @spec operador_entrada_aceita(Ecto.UUID.t(), non_neg_integer()) :: :ok
  def operador_entrada_aceita(operator_id, apagadas) when is_integer(apagadas),
    do:
      registrar_operador("operador entrada aceita",
        operator_id: operator_id,
        falhas_apagadas: apagadas
      )

  @doc "Entrada do operador recusada, com o motivo interno de `Credentials`."
  @spec operador_entrada_recusada(Ecto.UUID.t() | nil, atom()) :: :ok
  def operador_entrada_recusada(operator_id, motivo) when is_atom(motivo),
    do: registrar_operador("operador entrada recusada", operator_id: operator_id, motivo: motivo)

  @doc "O primeiro passo da definição aceito: a senha definida (A7)."
  @spec operador_senha_definida(Ecto.UUID.t()) :: :ok
  def operador_senha_definida(operator_id),
    do: registrar_operador("operador senha definida", operator_id: operator_id)

  @doc "A definição de senha recusada, com o motivo (A7, A14)."
  @spec operador_definicao_recusada(Ecto.UUID.t() | nil, atom()) :: :ok
  def operador_definicao_recusada(operator_id, motivo) when is_atom(motivo),
    do:
      registrar_operador("operador definição recusada", operator_id: operator_id, motivo: motivo)

  @doc "O terceiro passo do cadastro aceito: é aqui que o segundo fator passa a valer."
  @spec operador_segundo_fator_cadastrado(Ecto.UUID.t()) :: :ok
  def operador_segundo_fator_cadastrado(operator_id),
    do: registrar_operador("operador segundo fator cadastrado", operator_id: operator_id)

  @doc "Um passo do cadastro do segundo fator recusado, com o motivo."
  @spec operador_cadastro_recusado(Ecto.UUID.t() | nil, atom()) :: :ok
  def operador_cadastro_recusado(operator_id, motivo) when is_atom(motivo),
    do: registrar_operador("operador cadastro recusado", operator_id: operator_id, motivo: motivo)

  @doc "Um código de recuperação consumido, com quantos restam."
  @spec operador_recuperacao_usada(Ecto.UUID.t(), non_neg_integer()) :: :ok
  def operador_recuperacao_usada(operator_id, restantes) when is_integer(restantes),
    do:
      registrar_operador("operador recuperação usada",
        operator_id: operator_id,
        restantes: restantes
      )

  @doc "O segundo fator travou no limite (T1). Sai uma vez, na transição."
  @spec operador_segundo_fator_travado(Ecto.UUID.t()) :: :ok
  def operador_segundo_fator_travado(operator_id),
    do: registrar_operador("operador segundo fator travado", operator_id: operator_id)

  @doc "A espera crescente do operador acionada."
  @spec operador_espera_acionada(Ecto.UUID.t(), pos_integer()) :: :ok
  def operador_espera_acionada(operator_id, segundos) when is_integer(segundos),
    do:
      registrar_operador("operador espera acionada", operator_id: operator_id, segundos: segundos)

  @doc "A sessão do operador derrubada, com o motivo de `Platform.Sessions.conferir/2`."
  @spec operador_sessao_derrubada(Ecto.UUID.t() | nil, atom()) :: :ok
  def operador_sessao_derrubada(operator_id, motivo) when is_atom(motivo),
    do: registrar_operador("operador sessão derrubada", operator_id: operator_id, motivo: motivo)

  @doc "Um ato de suspender ou reativar recusado. `tenant_id` é nil quando o slug não resolveu."
  @spec operador_ato_recusado(Ecto.UUID.t(), Ecto.UUID.t() | nil, atom()) :: :ok
  def operador_ato_recusado(operator_id, tenant_id, motivo) when is_atom(motivo),
    do:
      registrar_operador("operador ato recusado",
        operator_id: operator_id,
        tenant_id: tenant_id,
        motivo: motivo
      )

  defp registrar_operador(evento, campos) do
    Logger.warning(fn ->
      "acesso: #{evento} · " <> Enum.map_join(campos, " ", fn {k, v} -> "#{k}=#{inspect(v)}" end)
    end)
  end

  # `warning` para recusa, ato administrativo, espera acionada — e para **entrada aceita
  # que apagou tentativa falha**. `info` para o resto.
  #
  # Não é estética: um incidente se investiga **filtrando**, e o que se filtra primeiro é
  # recusa, ato administrativo e sucesso que apagou rastro.
  #
  # A última é a que dá severidade ao achado H4: um sucesso com `falhas_apagadas=0` é o
  # login de todos os dias; com `falhas_apagadas=17` é uma campanha que deu certo. Deixar
  # os dois no mesmo nível faria a linha que importa afogar-se nas que não importam.
  #
  # **E há uma razão de teste, que a L69 explica**: no ambiente de teste o nível é
  # `:warning` (`config/test.exs`), e um evento em `:info` **não é observável por teste
  # nenhum**. A primeira versão deste módulo punha a entrada aceita em `:info`, e o teste
  # que assere `falhas_apagadas` reprovava com o log vazio — não por o registro faltar, mas
  # por o nível o esconder. Elevar o que importa é o que o torna verificável.
  defp registrar(evento, campos) do
    nivel =
      cond do
        evento in [
          "entrada recusada",
          "painel recusado",
          "equipe recusada",
          "ato administrativo",
          "espera acionada"
        ] ->
          :warning

        evento == "entrada aceita" and Keyword.get(campos, :falhas_apagadas, 0) > 0 ->
          :warning

        true ->
          :info
      end

    Logger.log(nivel, fn ->
      "acesso: #{evento} · " <>
        Enum.map_join(campos, " ", fn {k, v} -> "#{k}=#{inspect(v)}" end)
    end)
  end
end
