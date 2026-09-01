defmodule TheBand.Tenants.BootstrapTest do
  @moduledoc """
  Feature 052 — contrato em `specs/052-primeira-conta-do-ambiente/contracts/primeira-conta.md`.

  Os casos estão na ordem em que a spec os prioriza, e **as violações vêm
  primeiro**: para invariante de segurança, a prova é o que não pode acontecer.
  O caminho feliz sozinho passaria mesmo numa implementação que vaza a senha.
  """
  use TheBand.DataCase, async: true

  alias Ecto.Adapters.SQL.Sandbox
  alias TheBand.Repo
  alias TheBand.Tenants
  alias TheBand.Tenants.Auth
  alias TheBand.Tenants.Bootstrap
  alias TheBand.Tenants.Tenant
  alias TheBand.Tenants.User

  import Ecto.Query

  @senha "senha-de-instalacao-longa"

  defp ambiente(valores) do
    fn nome -> Map.get(valores, nome) end
  end

  defp ambiente_completo(sobrescritas \\ %{}) do
    ambiente(
      Map.merge(
        %{
          "THE_BAND_TENANT_NOME" => "Organização de Ensaio",
          "THE_BAND_TENANT_SLUG" => "ensaio",
          "THE_BAND_ADMIN_EMAIL" => "ensaio@exemplo.test",
          "THE_BAND_ADMIN_SENHA" => @senha
        },
        sobrescritas
      )
    )
  end

  defp conta_admins, do: Repo.aggregate(from(u in User, where: u.role == "admin"), :count)

  describe "a senha não vaza (FR-006)" do
    test "o retorno de sucesso não carrega a senha" do
      assert {:ok, :criada, dados} = Bootstrap.criar_primeira_conta(ambiente_completo())

      # Não basta conferir as chaves conhecidas: um campo novo acrescentado depois
      # poderia trazer a senha sem que ninguém percebesse. A asserção é sobre o
      # mapa inteiro, serializado.
      refute inspect(dados) =~ @senha
      assert Map.keys(dados) |> Enum.sort() == [:email, :slug]
    end

    test "o changeset de recusa não carrega a senha" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               Bootstrap.criar_primeira_conta(
                 ambiente_completo(%{"THE_BAND_ADMIN_SENHA" => "curta"})
               )

      refute inspect(changeset) =~ "curta"
    end
  end

  describe "criar quando não há administrador (US1)" do
    test "cria a organização e a conta, e devolve o que identifica" do
      assert {:ok, :criada, %{email: "ensaio@exemplo.test", slug: "ensaio"}} =
               Bootstrap.criar_primeira_conta(ambiente_completo())

      assert conta_admins() == 1
      assert %{slug: "ensaio"} = Tenants.get_by_slug("ensaio")
    end

    test "a senha criada abre a sessão" do
      {:ok, :criada, _} = Bootstrap.criar_primeira_conta(ambiente_completo())

      assert {:ok, %User{}} = Auth.authenticate("ensaio@exemplo.test", @senha)
    end

    test "o nome é opcional — sem ele a conta nasce mesmo assim" do
      assert {:ok, :criada, _} = Bootstrap.criar_primeira_conta(ambiente_completo())
      assert conta_admins() == 1
    end
  end

  describe "não criar quando já há administrador (US2)" do
    setup do
      {:ok, :criada, _} = Bootstrap.criar_primeira_conta(ambiente_completo())
      :ok
    end

    test "a segunda chamada não cria nem altera nada" do
      assert {:ok, :ja_existe} = Bootstrap.criar_primeira_conta(ambiente_completo())
      assert conta_admins() == 1
    end

    test "e-mail DIFERENTE também não cria um segundo" do
      assert {:ok, :ja_existe} =
               Bootstrap.criar_primeira_conta(
                 ambiente_completo(%{"THE_BAND_ADMIN_EMAIL" => "outra@exemplo.test"})
               )

      assert conta_admins() == 1
      assert Repo.aggregate(from(u in User, where: u.email == "outra@exemplo.test"), :count) == 0
    end

    test "dez subidas seguidas produzem exatamente um administrador (SC-004)" do
      # O `setup` já é a primeira subida; faltam nove para as dez que o SC-004 conta.
      restantes = for _ <- 1..9, do: Bootstrap.criar_primeira_conta(ambiente_completo())

      assert Enum.all?(restantes, &match?({:ok, :ja_existe}, &1))
      assert conta_admins() == 1
      assert Repo.aggregate(from(t in Tenant, where: t.slug == "ensaio"), :count) == 1
    end

    test "a senha trocada pela interface sobrevive a cinco subidas (SC-005)" do
      tenant = Tenants.get_by_slug("ensaio")
      %User{} = user = Repo.get_by(User, email: "ensaio@exemplo.test")
      nova = "outra-senha-bem-longa"

      {:ok, _} = Auth.change_password(tenant, user.id, @senha, nova)

      for _ <- 1..5 do
        assert {:ok, :ja_existe} = Bootstrap.criar_primeira_conta(ambiente_completo())
      end

      # A que a pessoa escolheu continua valendo…
      assert {:ok, %User{}} = Auth.authenticate("ensaio@exemplo.test", nova)
      # …e a do ambiente NÃO voltou.
      assert {:error, _} = Auth.authenticate("ensaio@exemplo.test", @senha)
    end
  end

  describe "a ausência é dita, e nada é criado (US3)" do
    test "faltando duas variáveis, a lista traz as DUAS" do
      assert {:error, {:faltando, faltando}} =
               Bootstrap.criar_primeira_conta(
                 ambiente(%{
                   "THE_BAND_TENANT_NOME" => "Ensaio",
                   "THE_BAND_ADMIN_EMAIL" => "ensaio@exemplo.test"
                 })
               )

      assert Enum.sort(faltando) == [:senha, :slug]
    end

    test "valor vazio conta como ausente" do
      assert {:error, {:faltando, [:slug]}} =
               Bootstrap.criar_primeira_conta(ambiente_completo(%{"THE_BAND_TENANT_SLUG" => ""}))
    end

    test "falta parcial não deixa organização órfã" do
      {:error, {:faltando, _}} =
        Bootstrap.criar_primeira_conta(ambiente_completo(%{"THE_BAND_ADMIN_EMAIL" => nil}))

      assert Repo.aggregate(TheBand.Tenants.Tenant, :count) == 0
    end
  end

  describe "a recusa vem dos changesets que já existem (FR-008)" do
    test "senha de 11 caracteres é recusada pelo senha_changeset" do
      # Onze de propósito: é o valor que SÓ o `senha_changeset` recusa (mínimo 12).
      # Uma validação copiada com outro mínimo deixaria este teste passar — e é
      # exatamente isso que ele existe para impedir.
      onze = "12345678901"

      assert {:error, %Ecto.Changeset{} = changeset} =
               Bootstrap.criar_primeira_conta(
                 ambiente_completo(%{"THE_BAND_ADMIN_SENHA" => onze})
               )

      assert %{password: [_ | _]} = errors_on(changeset)
      assert conta_admins() == 0
      assert Repo.aggregate(TheBand.Tenants.Tenant, :count) == 0
    end

    test "slug com espaço é recusado pelo Tenant.changeset" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               Bootstrap.criar_primeira_conta(
                 ambiente_completo(%{"THE_BAND_TENANT_SLUG" => "com espaço"})
               )

      assert %{slug: [_ | _]} = errors_on(changeset)
      assert Repo.aggregate(TheBand.Tenants.Tenant, :count) == 0
    end
  end

  describe "organização existente é reaproveitada (FR-011)" do
    test "com o slug já presente e sem admin, a conta nasce dentro dela" do
      {:ok, _} = Tenants.create_tenant(%{"name" => "Já Existia", "slug" => "ensaio"})
      antes = Repo.aggregate(TheBand.Tenants.Tenant, :count)

      assert {:ok, :criada, %{slug: "ensaio"}} =
               Bootstrap.criar_primeira_conta(ambiente_completo())

      assert Repo.aggregate(TheBand.Tenants.Tenant, :count) == antes
      assert conta_admins() == 1
    end
  end

  describe "a corrida (FR-005)" do
    @tag :capture_log
    test "duas chamadas concorrentes produzem UM administrador" do
      # A garantia vem dos índices únicos de `tenants.slug` e `users.email`, que
      # existem desde a primeira migração — research R1. Não há lock aqui, e não
      # deve haver: este teste falha se alguém trocar a garantia do banco por uma
      # consulta prévia.
      tarefas =
        for _ <- 1..2 do
          Task.async(fn ->
            Sandbox.allow(Repo, self(), self())
            Bootstrap.criar_primeira_conta(ambiente_completo())
          end)
        end

      resultados = Task.await_many(tarefas, 10_000)

      assert conta_admins() == 1
      assert Enum.count(resultados, &match?({:ok, :criada, _}, &1)) == 1

      # E o PERDEDOR lê a violação como instalação já feita — não como erro de
      # quem configurou. Sem esta asserção, contar só o vencedor passa mesmo com
      # a leitura da corrida desligada, e o boot da segunda subida gritaria.
      assert Enum.count(resultados, &match?({:ok, :ja_existe}, &1)) == 1
    end
  end
end
