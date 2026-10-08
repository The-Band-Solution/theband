defmodule Mix.Tasks.Dev.Senha do
  @shortdoc "Define a senha de uma conta do banco de desenvolvimento local"

  @moduledoc """
  Define a senha de uma conta do banco de **desenvolvimento local** — issue #1410.

      mix dev.senha pessoa@exemplo.dev

  **Por que existe.** Para entrar na aplicação local é preciso a senha de uma conta, e o banco
  guarda só o hash. A regra da casa proíbe segredo em chat, commit ou log, então a senha é
  digitada aqui, sem eco, e nunca passa por argumento, variável de ambiente nem histórico do
  shell.

  **O que ela recusa**, antes de ler a senha, buscar a conta ou abrir conexão — parecer em
  `docs/seguranca/2026-10-05-1410-senha-local.md`:

  - `MIX_ENV` diferente de `dev`, inclusive `test`. O ambiente vem só de `Mix.env()`: uma opção
    para "fingir dev" seria a mesma porta para contorná-la;
  - banco que não é o local: host fora de `localhost`, `127.0.0.1`, `::1` e `the_band_postgres`
    (o contêiner do `compose.yaml`), por igualdade exata; `url`, `socket`, `socket_dir` ou
    `endpoints` configurados; host ausente (o Postgrex cairia em `PGHOST`); banco diferente de
    `the_band_dev`. Um túnel `ssh` para `localhost` com banco de mesmo nome passa — é o risco
    que sobra, e está declarado no parecer;
  - entrada que não é terminal: `:io.get_password/0` devolve `{:error, :enotsup}`, e cair em
    `IO.gets/1` ecoaria a senha.

  **Efeito colateral**: `TheBand.Tenants.Auth.set_password/3` encerra as sessões abertas da
  conta. A tarefa avisa antes de pedir a senha.

  **Limitação**: a proveniência gravada é `password_source: "self"`, a mesma da primeira
  definição pela própria pessoa — o banco não distingue esta tarefa daquele fluxo.

  A lógica vive aqui, e não num módulo `TheBand.*`, de propósito: o módulo entra no release como
  as demais tarefas, mas sem Mix ele não roda, e uma função de domínio seria chamável por `eval`
  em produção sem guarda nenhuma.
  """

  use Mix.Task

  import Ecto.Query, only: [from: 2]

  alias TheBand.Repo
  alias TheBand.Tenants.{Auth, Tenant, User}

  @hosts_locais ["localhost", "127.0.0.1", "::1", "the_band_postgres"]
  @banco_de_dev "the_band_dev"
  @chaves_que_desviam_do_host [:url, :socket, :socket_dir, :endpoints]

  @impl Mix.Task
  def run(argv) do
    email = email_do_argv(argv)

    # A configuração efetiva, depois do `runtime.exs`, sem iniciar nada.
    Mix.Task.run("app.config")

    case conferir(Mix.env(), Repo.config()) do
      :ok -> :ok
      {:error, motivo} -> Mix.raise(motivo)
    end

    # Em :debug, o log de consulta mostraria o hash Bcrypt no terminal, e dali ao chat é um
    # copiar e colar — ataque de dicionário offline (parecer, 4a).
    Logger.configure(level: :info)
    Mix.Task.run("app.start")

    case definir(email, &ler_sem_eco/1) do
      :ok -> :ok
      {:error, motivo} -> Mix.raise(motivo)
    end
  end

  defp email_do_argv([email]), do: email
  defp email_do_argv([]), do: Mix.raise("Uso: mix dev.senha <email>")

  defp email_do_argv(_),
    do: Mix.raise("Só um argumento, o e-mail. A senha nunca vem por argumento: ela é digitada.")

  @doc false
  # Pura, para o teste exercitar a guarda sem mudar MIX_ENV (parecer, R1 e R2).
  @spec conferir(atom(), keyword()) :: :ok | {:error, String.t()}
  def conferir(:dev, config), do: conferir_banco(config)

  def conferir(env, _config),
    do: {:error, "Recusada: só roda com MIX_ENV=dev, e este é #{inspect(env)}."}

  defp conferir_banco(config) do
    desvio = Enum.filter(@chaves_que_desviam_do_host, &Keyword.has_key?(config, &1))

    cond do
      desvio != [] ->
        {:error, "Recusada: o Repo usa #{inspect(desvio)}, e o banco local é por host."}

      Keyword.get(config, :hostname) not in @hosts_locais ->
        {:error,
         "Recusada: o host do banco não é local (#{inspect(Keyword.get(config, :hostname))})."}

      Keyword.get(config, :database) != @banco_de_dev ->
        {:error, "Recusada: o banco não é o #{@banco_de_dev} local."}

      true ->
        :ok
    end
  end

  @doc false
  # O efeito, depois da guarda. O leitor é injetado para o teste não depender de terminal.
  @spec definir(String.t(), (String.t() -> {:ok, String.t()} | {:error, String.t()})) ::
          :ok | {:error, String.t()}
  def definir(email, leitor) do
    with {:ok, user} <- conta(email),
         :ok <- avisar_das_sessoes(user),
         {:ok, senha} <- leitor.("Nova senha (12 a 128 caracteres): "),
         {:ok, ^senha} <- leitor.("Repita a senha: "),
         {:ok, _} <- Auth.set_password(Repo.get!(Tenant, user.tenant_id), user.id, senha) do
      IO.puts("Senha definida para #{user.email}.")
    else
      {:ok, _outra} -> {:error, "Recusada: as duas senhas não coincidem."}
      {:error, %Ecto.Changeset{} = cs} -> {:error, "Recusada: " <> erros(cs)}
      {:error, :not_found} -> {:error, "Conta não encontrada."}
      {:error, motivo} when is_binary(motivo) -> {:error, motivo}
    end
  end

  # Mesma regra do `por_email/1` da entrada: sem distinguir caixa, e ambíguo não identifica.
  defp conta(email) do
    baixo = String.downcase(email)

    case Repo.all(from u in User, where: fragment("lower(?)", u.email) == ^baixo, limit: 2) do
      [user] -> {:ok, user}
      [] -> {:error, "Conta não encontrada: #{email}."}
      _ -> {:error, "Mais de uma conta com esse e-mail, diferindo só em caixa: nada feito."}
    end
  end

  defp avisar_das_sessoes(user) do
    IO.puts("Definir a senha de #{user.email} encerra todas as sessões abertas dessa conta.")
  end

  # Só as mensagens: `changeset.params` ainda carrega a senha em claro (parecer, 4b).
  defp erros(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc -> String.replace(acc, "%{#{k}}", to_string(v)) end)
    end)
    |> Enum.map_join("; ", fn {campo, msgs} -> "#{campo}: #{Enum.join(msgs, ", ")}" end)
  end

  defp ler_sem_eco(prompt) do
    IO.write(prompt)

    case :io.get_password() do
      {:error, _} ->
        {:error, "Recusada: a entrada não é um terminal, e sem terminal a senha ecoaria."}

      senha ->
        IO.puts("")
        {:ok, senha |> List.to_string() |> String.trim_trailing("\n")}
    end
  end
end
