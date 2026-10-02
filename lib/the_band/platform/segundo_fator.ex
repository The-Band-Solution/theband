defmodule TheBand.Platform.SegundoFator do
  @moduledoc """
  O segundo fator TOTP do operador da plataforma — spec 070, T022 (FR-016). Contrato em
  `specs/070-operador-da-plataforma/contracts/segundo-fator-do-operador.md`.

  Depende de: nenhuma ontologia. Usa `NimbleTOTP` (`== 1.0.0`, escolhida na T009).

  **Funções puras.** Nada aqui lê ou grava o banco, nem o relógio: `agora` é argumento, para o
  teste fixar a hora (lição L46). Quem grava o passo aceito, com a linha travada, é `Credentials`.

  Todo valor que é segredo entra e sai como `TheBand.Segredo`: o código digitado, o segredo, a URI
  que o carrega e os códigos de recuperação. Só `resumo/1` devolve binário cru, e é um `sha256`.
  """

  alias TheBand.Segredo

  @emissor "The Band Platform"
  @passo 30
  @bytes_do_segredo 20
  @codigos_de_recuperacao 10
  # 16 bytes = 128 bits por código, que em base32 sem padding são 26 caracteres. ASVS V2.6.2 pede
  # ≥112 bits para dispensar o sal (seguranca-totp.md, T2; eram 10 bytes, 80 bits).
  @bytes_por_codigo 16

  @doc "Um segredo novo de 20 bytes (RFC 4226 §4)."
  @spec gerar_segredo() :: Segredo.t()
  def gerar_segredo, do: Segredo.novo(NimbleTOTP.secret(@bytes_do_segredo))

  @doc "A URI `otpauth://` para o aplicativo autenticador. Volta como `Segredo`, porque o carrega."
  @spec uri(Segredo.t(), String.t()) :: Segredo.t()
  def uri(segredo, email) when is_binary(email) do
    segredo
    |> Segredo.expor()
    |> then(&NimbleTOTP.otpauth_uri("#{@emissor}:#{email}", &1, issuer: @emissor))
    |> Segredo.novo()
  end

  @doc """
  Confere o código contra o segredo, na janela de ±1 passo, recusando reuso.

  A janela é feita aqui, com três chamadas a `NimbleTOTP.valid?/3`, que confere um instante só e
  compara em tempo constante. Devolve o passo da chamada que aceitou. Um código cujo passo seja
  `<= ultimo_passo` é `:reusado`, mesmo correto: `valid?/3` devolve só `false` nos dois casos, e os
  dois se distinguem refazendo as chamadas sem `since`.
  """
  @spec conferir(Segredo.t(), Segredo.t(), non_neg_integer() | nil, DateTime.t()) ::
          {:ok, non_neg_integer()} | {:error, :codigo_errado | :reusado}
  def conferir(segredo, codigo, ultimo_passo, %DateTime{} = agora) do
    chave = Segredo.expor(segredo)
    digitado = codigo |> Segredo.expor() |> sem_separadores()
    t = DateTime.to_unix(agora)
    instantes = [t - @passo, t, t + @passo]

    case aceito(chave, digitado, instantes, contra_reuso(ultimo_passo)) do
      {:ok, instante} ->
        {:ok, div(instante, @passo)}

      :error ->
        case aceito(chave, digitado, instantes, []) do
          {:ok, _} -> {:error, :reusado}
          :error -> {:error, :codigo_errado}
        end
    end
  end

  # `since` é um INSTANTE, e não um passo: o último passo aceito vezes o período.
  defp contra_reuso(nil), do: []
  defp contra_reuso(ultimo_passo), do: [since: ultimo_passo * @passo]

  defp aceito(chave, digitado, instantes, opcoes) do
    case Enum.find(instantes, &NimbleTOTP.valid?(chave, digitado, [time: &1] ++ opcoes)) do
      nil -> :error
      instante -> {:ok, instante}
    end
  end

  @doc """
  A forma do que foi digitado: seis dígitos são `:totp`, vinte e seis caracteres base32 são
  `:recuperacao`, e o resto é `:malformado`.

  **Só ASCII, e conferido antes de normalizar** (seguranca-totp.md, T6): sem a flag `u` e sem `\\d`,
  que com `u` aceitaria dígitos não ASCII; `\\z`, e não `$`, que casa antes de um `\\n` final. A
  retirada é só de espaço e hífen ASCII.
  """
  @spec classificar(Segredo.t()) :: :totp | :recuperacao | :malformado
  def classificar(texto) do
    limpo = texto |> Segredo.expor() |> sem_separadores()

    cond do
      Regex.match?(~r/\A[0-9]{6}\z/, limpo) -> :totp
      Regex.match?(~r/\A[A-Za-z2-7]{26}\z/, limpo) -> :recuperacao
      true -> :malformado
    end
  end

  @doc """
  Dez códigos de recuperação, cada um com 16 bytes aleatórios em base32 minúsculo sem padding, e um
  hífen a cada quatro caracteres para leitura. Mostrados uma vez; guardados só pelo `resumo/1`.
  """
  @spec gerar_codigos_de_recuperacao() :: [Segredo.t()]
  def gerar_codigos_de_recuperacao do
    for _ <- 1..@codigos_de_recuperacao do
      @bytes_por_codigo
      |> :crypto.strong_rand_bytes()
      |> Base.encode32(case: :lower, padding: false)
      |> String.graphemes()
      |> Enum.chunk_every(4)
      |> Enum.map_join("-", &Enum.join/1)
      |> Segredo.novo()
    end
  end

  @doc """
  O `sha256` do código **normalizado** (sem separador, minúsculo), que é o que vai para
  `platform_operator_recovery_codes.code_hash`. Sem sal porque são 128 bits aleatórios (T2).

  A minúscula é `:ascii`, **depois** da forma conferida por `classificar/1`: o `downcase` Unicode
  levaria o sinal de Kelvin (`U+212A`) a `"k"`, e um código fora do alfabeto viraria um do alfabeto.
  """
  @spec resumo(Segredo.t()) :: binary()
  def resumo(codigo) do
    normalizado = codigo |> Segredo.expor() |> sem_separadores() |> String.downcase(:ascii)
    :crypto.hash(:sha256, normalizado)
  end

  defp sem_separadores(texto), do: String.replace(texto, [" ", "-"], "")
end
