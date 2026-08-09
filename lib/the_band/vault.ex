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

  @doc """
  Rótulo do cipher, derivado da **própria chave**.

  É o detalhe de que a rotação depende. O Cloak escolhe com qual cipher decifrar
  pelo rótulo gravado no início do valor cifrado; se a chave nova e a antiga
  compartilhassem rótulo, ele escolheria pela ordem e usaria a chave errada — e o
  erro apareceria como "não consigo decifrar", sem dizer por quê.

  Derivando o rótulo da chave, cada valor cifrado carrega qual chave o cifrou.
  Durante a rotação as duas convivem sem ambiguidade, e depois dela os registros
  novos já apontam para a chave nova.

  Oito caracteres do SHA-256 identificam a chave sem revelá-la: são 32 bits de um
  digest, insuficientes para reconstruir os 256 bits de entrada.
  """
  @spec tag_for(binary()) :: String.t()
  def tag_for(key) when is_binary(key) do
    "AES.GCM." <> (:crypto.hash(:sha256, key) |> Base.encode16(case: :lower) |> binary_part(0, 8))
  end

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

    default = [default: {Cloak.Ciphers.AES.GCM, tag: tag_for(key), key: key, iv_length: 12}]

    case previous_key() do
      {:ok, previous} ->
        # A chave anterior só decifra. Nunca vira padrão, então nada novo é
        # gravado com ela — que é o ponto de estar aposentando-a.
        default ++
          [retired: {Cloak.Ciphers.AES.GCM, tag: tag_for(previous), key: previous, iv_length: 12}]

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
