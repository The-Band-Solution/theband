defmodule TheBand.AI do
  @moduledoc """
  O provedor de modelo de linguagem do tenant — feature 027.

  ## A chave é conferida antes de ser aceita

  Gravar sem conferir produz o pior estado possível: a tela diz que está configurado, e a
  primeira geração falha meia hora depois, para outra pessoa, num job de fundo. A conferência
  é uma chamada barata a `/models`, e ela transforma "configurado" numa afirmação.

  ## O ambiente continua valendo, e a tela diz isso

  `API_KEY` no ambiente segue funcionando quando não há credencial gravada — é como o
  desenvolvimento roda. Mas ela é **do processo**, e não do tenant: numa instalação com dois
  tenants, os dois usariam a mesma chave, e a conta de um pagaria pelo outro. A tela nomeia
  qual das duas está em uso.
  """

  import Ecto.Query

  alias TheBand.AI.ProviderCredential
  alias TheBand.Credenciais.Idade
  alias TheBand.Integrations.LLM.HTTP
  alias TheBand.Repo
  alias TheBand.Segredo
  alias TheBand.Tenants.AccessEvents
  alias TheBand.Tenants.Tenant

  @base_url "https://api.openai.com"

  @doc "A credencial gravada do tenant, se houver."
  @spec fetch(Tenant.t(), String.t()) :: {:ok, ProviderCredential.t()} | {:error, :not_found}
  def fetch(%Tenant{id: tenant_id}, provider \\ "openai") do
    case Repo.one(
           from c in ProviderCredential,
             where: c.tenant_id == ^tenant_id and c.provider == ^provider
         ) do
      nil -> {:error, :not_found}
      cred -> {:ok, cred}
    end
  end

  @doc """
  A credencial gravada do tenant **sem o segredo** (`secret: nil`) — 064/T018.

  Para quem só precisa das datas, como a marca da aba em `/tools`. `fetch/2` decifra o segredo,
  e com a chave mestra perdida o tipo levanta ao carregar: a tela que nem mostra a chave cairia
  por causa dela. O `select` não traz a coluna cifrada, e por isso não há o que decifrar.
  """
  @spec fetch_sem_segredo(Tenant.t(), String.t()) ::
          {:ok, ProviderCredential.t()} | {:error, :not_found}
  def fetch_sem_segredo(%Tenant{id: tenant_id}, provider \\ "openai") do
    case Repo.one(
           from c in ProviderCredential,
             where: c.tenant_id == ^tenant_id and c.provider == ^provider,
             select:
               struct(c, [
                 :id,
                 :tenant_id,
                 :provider,
                 :base_url,
                 :default_model,
                 :last_four,
                 :declared_by_user_id,
                 :validated_at,
                 :secret_set_at,
                 :previous_secret_set_at,
                 :last_failure_at,
                 :last_failure_reason,
                 :inserted_at,
                 :updated_at
               ])
         ) do
      nil -> {:error, :not_found}
      cred -> {:ok, cred}
    end
  end

  @doc """
  De onde a chave em uso vem, para a tela poder dizer.

  Três estados, e são três fatos diferentes: gravada para este tenant, herdada do ambiente
  do processo, ou inexistente. A tela que mostrasse os dois primeiros como "configurado"
  esconderia que um deles é compartilhado entre tenants.
  """
  @spec origem_da_chave(Tenant.t()) ::
          {:tenant, ProviderCredential.t()} | {:ambiente, String.t()} | :nenhuma
  def origem_da_chave(%Tenant{} = tenant) do
    case fetch(tenant) do
      {:ok, cred} ->
        {:tenant, cred}

      {:error, :not_found} ->
        case System.get_env("API_KEY") do
          nil -> :nenhuma
          "" -> :nenhuma
          chave -> {:ambiente, String.slice(chave, -4, 4)}
        end
    end
  end

  @doc """
  As opções de chamada deste tenant, para quem for gerar.

  Lista vazia quando não há credencial gravada — e vazia é o que faz a borda cair no
  `API_KEY` do ambiente, que é como o desenvolvimento roda. Quem chama não decide de onde a
  chave vem; **isto** decide, e num lugar só.
  """
  @spec opcoes(Tenant.t()) :: keyword()
  def opcoes(%Tenant{} = tenant) do
    case fetch(tenant) do
      {:ok, cred} ->
        # Fechada aqui, na borda em que a credencial decifrada é lida (064/T006).
        [key: Segredo.novo(cred.secret), base_url: cred.base_url] ++
          if(cred.default_model, do: [model: cred.default_model], else: [])

      {:error, :not_found} ->
        []
    end
  end

  @doc """
  Confere a chave contra o provedor e grava. Substitui a anterior, se houver.

  Não grava chave que não passou: "configurado" precisa ser verdade no momento em que a tela
  o afirma.

  **O ator é obrigatório** (#1387, R-a do parecer da #1221). Com `nil` aceito, a assinatura
  deixava passar uma gravação sem autor, e o declarante ficava nulo. Toda gravação tem quem a
  fez, e a guarda faz da ausência um erro de quem chama, e não uma linha sem nome no log.

  **A recusa deixa rastro** (#1388, R-b). Sem ele, o formulário servia para conferir chaves
  alheias sem que uma série de tentativas de um mesmo ator aparecesse em lugar nenhum. O evento
  leva só o átomo do motivo: a string vem do provedor e pode citar a chave mascarada por ele.
  """
  @spec put(Tenant.t(), map(), Ecto.UUID.t()) ::
          {:ok, ProviderCredential.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, {:rejeitada, String.t()}}
          | {:error, {:indisponivel, String.t()}}
          | {:error, {:sem_modelos, String.t()}}
          | {:error, {:modelo_desconhecido, String.t(), [String.t()]}}
  def put(%Tenant{id: tenant_id} = tenant, attrs, user_id) when is_binary(user_id) do
    secret = attrs["secret"] || attrs[:secret] || ""
    provider = attrs["provider"] || attrs[:provider] || "openai"

    with {:ok, modelos} <- HTTP.impl().verify(Segredo.novo(secret), base_url: @base_url),
         {:ok, modelo} <- escolher_modelo(attrs, modelos) do
      agora = DateTime.utc_now(:second)
      anterior = existente(tenant, provider)

      # Uma classificação só, e ela decide as datas, o declarante e o evento (#1221, condição 7).
      ato = classificar(anterior, secret)

      atributos = %{
        tenant_id: tenant_id,
        provider: provider,
        base_url: @base_url,
        default_model: modelo,
        secret: secret,
        validated_at: agora,
        last_failure_at: nil,
        last_failure_reason: nil
      }

      # As datas da troca e o declarante são calculados aqui e postos fora do `cast`. Vindas de
      # quem chama, uma data recente forjada esconderia uma credencial vencida (achado 2 da
      # avaliação).
      # A defesa contra a chave sair em claro no log da consulta é `TheBand.Repo.LogDaConsulta`
      # (#1222): o log embutido do Repo está desligado, e o handler redige os parâmetros de toda
      # consulta que toca tabela com campo cifrado. O `log: false` ficou redundante e não faz
      # mal (#1391, R-e do parecer da #1221). Não o troque por um nível, como `log: :debug`, que
      # contornaria o handler (`segredo_fora_do_log_test.exs` reprova).
      resultado =
        anterior
        |> ProviderCredential.changeset(atributos)
        |> Ecto.Changeset.change(campos_do_ato(ato, anterior, agora, user_id))
        |> Repo.insert_or_update(log: false)

      # Só depois do commit: erro de changeset não deixa evento de gravação (condição 4). A
      # recusa do provedor tem o evento dela, no `else`.
      with {:ok, _} <- resultado, do: AccessEvents.chave_do_modelo(ato, tenant_id, user_id)

      resultado
    else
      # Só o átomo sai daqui: o segundo elemento é texto do provedor (#1388). Um quinto formato
      # de recusa levanta na guarda do evento, que é onde ele precisa ser visto.
      {:error, recusa} = erro ->
        AccessEvents.chave_do_modelo_recusada(elem(recusa, 0), tenant_id, user_id)
        erro
    end
  end

  defp classificar(%ProviderCredential{id: nil}, _secret), do: :primeira

  defp classificar(%ProviderCredential{secret: gravado}, secret),
    do: if(mesma_chave?(gravado, secret), do: :mesma_chave, else: :troca)

  # 064/T019, FR-018: trocar o segredo zera a contagem da idade e guarda desde quando valia o
  # anterior. Regravar a mesma chave (para trocar o modelo, por exemplo) **não** é troca, e não
  # zera nada — senão a cobrança acharia atendida uma troca que não aconteceu.
  #
  # #1221: o declarante é quem pôs a chave em uso. Na mesma chave, fica o anterior. É
  # `Ecto.Changeset.change/2`, e **nunca** `force_change/3`: com o valor igual ao do registro
  # lido, o Ecto descarta a mudança. Por isso, sob concorrência, uma `:mesma_chave` obsoleta não
  # regrava o declarante antigo por cima de uma troca recém-commitada (parecer, S4).
  defp campos_do_ato(:primeira, _anterior, agora, user_id),
    do: %{secret_set_at: agora, previous_secret_set_at: nil, declared_by_user_id: user_id}

  defp campos_do_ato(:mesma_chave, anterior, _agora, _user_id) do
    # Não é troca, mas `validated_at` vai ser reescrito com `agora`. Numa linha anterior à
    # migração (`secret_set_at` nulo) a idade cai em `validated_at`, e voltaria a zero sem
    # troca nenhuma. Fixar aqui o início que valia antes da gravação o impede.
    %{
      secret_set_at: Idade.em_uso_desde(anterior),
      declared_by_user_id: anterior.declared_by_user_id
    }
  end

  defp campos_do_ato(:troca, anterior, agora, user_id) do
    %{
      secret_set_at: agora,
      previous_secret_set_at: Idade.em_uso_desde(anterior),
      declared_by_user_id: user_id
    }
  end

  # Comparação em memória e em tempo constante; nenhuma das duas sai daqui, e o resultado não é
  # registrado em lugar nenhum.
  defp mesma_chave?(gravado, novo) when is_binary(gravado) and is_binary(novo),
    do: Plug.Crypto.secure_compare(gravado, novo)

  defp mesma_chave?(_gravado, _novo), do: false

  @doc """
  Apaga a credencial. O segredo some, e não há histórico de segredo.

  Quem apagou fica no evento `:removida` (#1221, condição 1). Sem ele, apagar e gravar de novo
  apareceria no log como `:primeira`, sem ninguém para a remoção. Nesse intervalo o tenant cai
  no `API_KEY` do ambiente, que é compartilhado. Sem linha a remover, não há evento.

  O ator é obrigatório, como em `put/3` (#1387).
  """
  @spec delete(Tenant.t(), Ecto.UUID.t(), String.t()) :: :ok | {:error, :not_found}
  def delete(%Tenant{id: tenant_id} = tenant, actor_user_id, provider \\ "openai")
      when is_binary(actor_user_id) do
    case fetch(tenant, provider) do
      {:ok, cred} ->
        Repo.delete!(cred)
        AccessEvents.chave_do_modelo(:removida, tenant_id, actor_user_id)
        :ok

      erro ->
        erro
    end
  end

  defp existente(tenant, provider) do
    case fetch(tenant, provider) do
      {:ok, cred} -> cred
      {:error, :not_found} -> %ProviderCredential{}
    end
  end

  # O modelo escolhido só é aceito se o provedor o listou: guardar um nome que a conta não
  # atende adiaria a falha para o job de fundo, longe de quem digitou.
  #
  # **E a recusa é dita.** Trocar em silêncio o modelo pedido pelo padrão é a forma exata do
  # defeito que mais reincidiu aqui: a tela diz "gravado", e o que foi gravado não é o que a
  # pessoa pediu. Vazio é escolha legítima — é "o padrão do provedor" —, nome errado não é.
  defp escolher_modelo(attrs, modelos) do
    case attrs["default_model"] || attrs[:default_model] do
      vazio when vazio in [nil, ""] -> {:ok, nil}
      pedido -> if pedido in modelos, do: {:ok, pedido}, else: recusar(pedido, modelos)
    end
  end

  defp recusar(pedido, modelos), do: {:error, {:modelo_desconhecido, pedido, modelos}}
end
