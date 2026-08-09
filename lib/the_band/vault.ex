defmodule TheBand.Vault do
  @moduledoc """
  Cofre de cifragem das credenciais das ferramentas conectadas.

  AES-GCM de 256 bits, com a chave mestra vinda do ambiente (FR-005). A cifragem
  acontece no `Ecto.Type` — ver `TheBand.Encrypted.Binary` —, não no código de
  aplicação, o que remove a possibilidade de alguém gravar em claro por
  esquecimento.

  ## Rotação (FR-005b)

  O Cloak decifra com qualquer cipher configurado e cifra sempre com o marcado
  como `:default`. A rotação é: publicar a chave nova em `THE_BAND_MASTER_KEY`,
  manter a antiga em `THE_BAND_PREVIOUS_MASTER_KEY` para leitura, recifrar os
  registros com `mix the_band.rotate_key`, e então remover a antiga do ambiente.
  """

  use Cloak.Vault, otp_app: :the_band

  @impl GenServer
  def init(config) do
    {:ok, Keyword.put(config, :ciphers, ciphers())}
  end

  @doc """
  Lê a chave mestra do ambiente.

  Devolve `{:error, :missing_master_key}` quando ausente e
  `{:error, :invalid_master_key}` quando não são 32 bytes em Base64. Quem
  transforma isso em recusa de boot é `TheBand.Application` — aqui só se
  informa o estado.
  """
  @spec master_key() :: {:ok, binary()} | {:error, :missing_master_key | :invalid_master_key}
  def master_key, do: decode_key(env(:master_key))

  @doc "Chave anterior, presente apenas durante uma rotação (FR-005b)."
  @spec previous_key() :: {:ok, binary()} | {:error, :missing_master_key | :invalid_master_key}
  def previous_key, do: decode_key(env(:previous_key))

  defp ciphers do
    key =
      case master_key() do
        {:ok, key} ->
          key

        {:error, reason} ->
          raise """
          Chave mestra ausente ou inválida (#{inspect(reason)}).

          FR-005a: a plataforma recusa iniciar sem a chave mestra, em vez de
          operar gravando credenciais sem proteção. Defina THE_BAND_MASTER_KEY
          com 32 bytes em Base64 — ver .env.example.
          """
      end

    default = [default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: key, iv_length: 12}]

    case previous_key() do
      {:ok, previous} ->
        default ++
          [retired: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V0", key: previous, iv_length: 12}]

      {:error, _} ->
        default
    end
  end

  defp env(field) do
    :the_band
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(field)
  end

  defp decode_key(value) when value in [nil, ""], do: {:error, :missing_master_key}

  defp decode_key(value) when is_binary(value) do
    case Base.decode64(value) do
      {:ok, key} when byte_size(key) == 32 -> {:ok, key}
      _ -> {:error, :invalid_master_key}
    end
  end
end
