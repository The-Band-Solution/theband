defmodule TheBand.Profiles do
  @moduledoc """
  Perfil de competências e evolução de uma pessoa — feature 026.

  ## O que este contexto faz, e o que ele recusa fazer

  Lê as tarefas designadas a alguém, monta um recorte, e pede a um modelo de linguagem que
  escreva sobre ele. **Não afirma competência**: a rede de ontologias não ganhou conceito de
  habilidade, e a razão está em `research.md` R1 da feature — criar um faria a plataforma
  dizer que a pessoa *tem* a habilidade, a partir de texto que em 44% dos casos foi escrito
  por outra pessoa.

  ## O caminho

      Material.build/2   →   Prompt   →   LLM.HTTP   →   Sanitizer   →   EO.record_profile/2
      recusa aqui,           regras       borda          limpa o        somente
      com quatro             que são      única com      resumo         acréscimo
      motivos distintos      requisito    Mox
  """

  alias TheBand.Profiles.{GenerateWorker, Material}
  alias TheBand.Tenants.Tenant

  @doc """
  Verifica se há material, sem montar o material e sem gastar chamada.

  A tela chama isto **antes** de oferecer o botão: pedir uma geração que vai ser recusada
  gasta um job e devolve a mesma recusa mais tarde, com a pessoa esperando à toa.

  Uma consulta, e ela traz só tamanho de corpo — ver `Material.check/2`. A versão anterior
  chamava `build/2` aqui, e o guard de consultas da página da pessoa pegou: quatro consultas
  e todo o texto das tarefas, a cada render, para decidir se um botão aparece.
  """
  defdelegate check(tenant, person_id), to: Material

  @doc """
  Enfileira uma geração.

  Devolve o job, e **não** o perfil: quem chama não espera. A chamada leva de 25 a 60
  segundos, medidos.
  """
  @spec request(Tenant.t(), binary(), binary() | nil) ::
          {:ok, Oban.Job.t()} | {:error, term()}
  def request(%Tenant{id: tenant_id}, person_id, user_id \\ nil) do
    %{tenant_id: tenant_id, person_id: person_id, requested_by_user_id: user_id}
    |> GenerateWorker.new()
    |> Oban.insert()
  end

  @doc """
  Há geração pendente para esta pessoa?

  É o terceiro estado da tela — *pedido, ainda não pronto* —, e ele precisa ser distinguível
  de *nunca gerado* e de *falhou*.
  """
  @spec pending?(Tenant.t(), binary()) :: boolean()
  def pending?(%Tenant{id: tenant_id}, person_id) do
    import Ecto.Query

    from(j in Oban.Job,
      where:
        j.worker == "TheBand.Profiles.GenerateWorker" and
          j.state in ["available", "scheduled", "executing", "retryable"] and
          fragment("? ->> 'tenant_id' = ?", j.args, ^tenant_id) and
          fragment("? ->> 'person_id' = ?", j.args, ^person_id)
    )
    |> TheBand.Repo.exists?()
  end
end
