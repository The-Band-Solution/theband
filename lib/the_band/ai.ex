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
  alias TheBand.Integrations.LLM.HTTP
  alias TheBand.Repo
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
        [key: cred.secret, base_url: cred.base_url] ++
          if(cred.default_model, do: [model: cred.default_model], else: [])

      {:error, :not_found} ->
        []
    end
  end

  @doc """
  Confere a chave contra o provedor e grava. Substitui a anterior, se houver.

  Não grava chave que não passou: "configurado" precisa ser verdade no momento em que a tela
  o afirma.
  """
  @spec put(Tenant.t(), map(), binary() | nil) ::
          {:ok, ProviderCredential.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, {:rejeitada, String.t()}}
          | {:error, {:indisponivel, String.t()}}
          | {:error, {:sem_modelos, String.t()}}
          | {:error, {:modelo_desconhecido, String.t(), [String.t()]}}
  def put(%Tenant{id: tenant_id} = tenant, attrs, user_id \\ nil) do
    secret = attrs["secret"] || attrs[:secret] || ""
    provider = attrs["provider"] || attrs[:provider] || "openai"

    with {:ok, modelos} <- HTTP.impl().verify(secret, base_url: @base_url),
         {:ok, modelo} <- escolher_modelo(attrs, modelos) do
      atributos = %{
        tenant_id: tenant_id,
        provider: provider,
        base_url: @base_url,
        default_model: modelo,
        secret: secret,
        declared_by_user_id: user_id,
        validated_at: DateTime.utc_now(:second),
        last_failure_at: nil,
        last_failure_reason: nil
      }

      tenant
      |> existente(provider)
      |> ProviderCredential.changeset(atributos)
      |> Repo.insert_or_update()
    end
  end

  @doc "Apaga a credencial. O segredo some — não há histórico de segredo."
  @spec delete(Tenant.t(), String.t()) :: :ok | {:error, :not_found}
  def delete(%Tenant{} = tenant, provider \\ "openai") do
    case fetch(tenant, provider) do
      {:ok, cred} ->
        Repo.delete!(cred)
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
