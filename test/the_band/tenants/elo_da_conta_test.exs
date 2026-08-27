defmodule TheBand.Tenants.EloDaContaTest do
  @moduledoc """
  Qual pessoa observada é cada conta — issue #369, FR-012c.

  ## Por que este elo existe

  A decisão de 2026-08-26 diz quem vê o painel de quem: a própria pessoa, o líder da equipe
  dela, e o responsável da organização. **Nenhuma das três é computável sem o elo** — nem a
  primeira, que é a mais simples.

  ## Por que pelo id do GitHub, e não pelo e-mail

  Medido em 2026-08-26 sobre as 88 pessoas observadas:

      com external_id (o id do GitHub) .. 88
      com login ......................... 88
      com email .........................  0

  O GitHub não entrega e-mail. Exigir e-mail obrigaria a digitar os **dois** lados do elo; a
  identidade da origem já está gravada nas 88, e o lado observado não precisa de digitação.

  ## As asserções que carregam este arquivo

  1. **uma pessoa observada tem no máximo uma conta vigente.** Duas contas apontando para a
     mesma pessoa alcançariam o mesmo painel, e a plataforma não saberia que foi engano;
  2. **revogar preserva quem era.** Zerar `person_id` deixaria "desde quando" sem "quem", e
     é "quem" que se pergunta primeiro ao auditar acesso;
  3. **o elo revogado não resolve.** Com o id preservado na linha, é `person_revoked_at` que
     o tira de circulação — quem ler `person_id` sem conferir a revogação concede acesso
     que alguém retirou de propósito;
  4. **login não é chave.** Login é renomeável e o GitHub libera o nome antigo para outra
     pessoa; casar por ele faria a visibilidade mudar de dono sem nada ter acontecido aqui.
  """
  use TheBand.DataCase, async: false

  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants
  alias TheBand.Tenants.User

  setup do
    tenant = tenant_fixture()
    admin = user_fixture(tenant)
    %{tenant: tenant, admin: admin}
  end

  defp pessoa(tenant, login, nome) do
    {:ok, p} =
      EO.upsert_person_from_source(
        tenant,
        Map.merge(source_attrs("U_#{login}"), %{name: nome, login: login, account_type: "person"})
      )

    p
  end

  describe "a identidade vem da origem" do
    test "a pessoa observada já tem o id do GitHub — nada a digitar desse lado", ctx do
      p = pessoa(ctx.tenant, "paulossjunior", "Paulo")

      assert p.external_id == "U_paulossjunior"
      assert p.login == "paulossjunior"

      assert is_nil(p.email), """
      A pessoa observada veio com e-mail.

      Medido em 2026-08-26: das 88 pessoas, ZERO têm e-mail — o GitHub não entrega. Se este
      teste falhar porque a origem mudou, o elo por id continua correto; o que muda é que o
      e-mail deixa de ser impossível, não que passe a ser preferível.
      """
    end

    test "declarar liga a conta à pessoa", ctx do
      p = pessoa(ctx.tenant, "ana", "Ana")
      assert Tenants.user_for_person(ctx.tenant, p.id) == :not_declared

      {:ok, conta} = Tenants.declare_person(ctx.tenant, ctx.admin.id, p.id, ctx.admin.id)

      assert conta.person_id == p.id
      assert conta.person_declared_by_user_id == ctx.admin.id
      assert conta.person_declared_at

      assert {:ok, achada} = Tenants.user_for_person(ctx.tenant, p.id)
      assert achada.id == ctx.admin.id
      assert Tenants.person_of_user(conta) == {:ok, p.id}
    end

    test "sem elo é :not_declared dos dois lados, e nunca nil", ctx do
      p = pessoa(ctx.tenant, "ana", "Ana")

      assert Tenants.user_for_person(ctx.tenant, p.id) == :not_declared

      assert Tenants.person_of_user(ctx.admin) == :not_declared, """
      A ausência do elo veio como `nil`.

      A tela precisa distinguir "essa conta é a pessoa X" de "não sabemos quem essa conta
      é": a segunda tem remédio — declarar — e a primeira não.
      """
    end
  end

  describe "uma pessoa, no máximo uma conta vigente" do
    test "a segunda conta apontando para a mesma pessoa é recusada", ctx do
      p = pessoa(ctx.tenant, "ana", "Ana")
      outra = user_fixture(ctx.tenant)

      {:ok, _} = Tenants.declare_person(ctx.tenant, ctx.admin.id, p.id, ctx.admin.id)

      assert {:error, :taken} =
               Tenants.declare_person(ctx.tenant, outra.id, p.id, ctx.admin.id),
             """
             Duas contas ficaram apontando para a mesma pessoa observada.

             É o elo que concede visibilidade. Duas contas na mesma pessoa alcançariam o mesmo
             painel, e a plataforma não teria como saber que uma delas foi engano.
             """
    end

    test "uma conta trocando de pessoa encerra a anterior", ctx do
      a = pessoa(ctx.tenant, "ana", "Ana")
      b = pessoa(ctx.tenant, "bia", "Bia")

      {:ok, _} = Tenants.declare_person(ctx.tenant, ctx.admin.id, a.id, ctx.admin.id)
      {:ok, conta} = Tenants.declare_person(ctx.tenant, ctx.admin.id, b.id, ctx.admin.id)

      assert conta.person_id == b.id
      assert Tenants.user_for_person(ctx.tenant, a.id) == :not_declared
      assert {:ok, achada} = Tenants.user_for_person(ctx.tenant, b.id)
      assert achada.id == ctx.admin.id
    end

    test "a pessoa liberada por revogação aceita outra conta", ctx do
      p = pessoa(ctx.tenant, "ana", "Ana")
      outra = user_fixture(ctx.tenant)

      {:ok, _} = Tenants.declare_person(ctx.tenant, ctx.admin.id, p.id, ctx.admin.id)
      {:ok, _} = Tenants.revoke_person(ctx.tenant, ctx.admin.id, ctx.admin.id)

      assert {:ok, _} = Tenants.declare_person(ctx.tenant, outra.id, p.id, ctx.admin.id), """
      Depois de revogado, a pessoa continuou presa à primeira conta.

      É o caso de alguém trocar de conta, ou de o elo ter sido declarado na conta errada.
      Índice total impediria a correção.
      """
    end
  end

  describe "revogar marca" do
    test "revogar preserva QUEM era, e tira de circulação pela revogação", ctx do
      p = pessoa(ctx.tenant, "ana", "Ana")
      {:ok, _} = Tenants.declare_person(ctx.tenant, ctx.admin.id, p.id, ctx.admin.id)

      {:ok, revogada} = Tenants.revoke_person(ctx.tenant, ctx.admin.id, ctx.admin.id)

      assert revogada.person_revoked_by_user_id == ctx.admin.id
      assert revogada.person_revoked_at

      assert revogada.person_id == p.id, """
      Revogar apagou QUAL pessoa a conta era.

      Zerar o id deixaria "desde quando" sem "quem", e é "quem" que se pergunta primeiro ao
      auditar acesso. O índice parcial já exclui a linha revogada.
      """

      refute User.elo_vigente?(revogada), """
      O elo revogado continuou vigente.

      Com o id preservado na linha, é `person_revoked_at` que o tira de circulação — quem
      ler `person_id` sem conferir a revogação concede acesso que alguém retirou.
      """

      assert Tenants.user_for_person(ctx.tenant, p.id) == :not_declared
      assert Tenants.person_of_user(revogada) == :not_declared
    end

    test "revogar o que ninguém declarou não é sucesso silencioso", ctx do
      assert {:error, :not_declared} =
               Tenants.revoke_person(ctx.tenant, ctx.admin.id, ctx.admin.id)
    end
  end

  describe "a fronteira do tenant" do
    test "conta de outro tenant não é alcançada nem declarada", ctx do
      p = pessoa(ctx.tenant, "ana", "Ana")
      outro = tenant_fixture()
      dele = user_fixture(outro)

      assert {:error, :not_found} =
               Tenants.declare_person(ctx.tenant, dele.id, p.id, ctx.admin.id),
             """
             Uma conta de outro tenant foi ligada a uma pessoa daqui.

             Consulta sem filtro de tenant é bug de segurança — princípio V —, e aqui o que vaza é
             acesso a painel.
             """
    end

    test "o elo declarado aqui não é visto de lá", ctx do
      p = pessoa(ctx.tenant, "ana", "Ana")
      {:ok, _} = Tenants.declare_person(ctx.tenant, ctx.admin.id, p.id, ctx.admin.id)

      outro = tenant_fixture()

      assert Tenants.user_for_person(outro, p.id) == :not_declared
      assert %{declaradas: 0} = Tenants.elo_coverage(outro)
    end
  end

  describe "a lacuna é dita como lacuna" do
    test "a cobertura mostra quantas de quantas", ctx do
      p = pessoa(ctx.tenant, "ana", "Ana")
      user_fixture(ctx.tenant)

      assert %{declaradas: 0, contas: 2} = Tenants.elo_coverage(ctx.tenant)

      {:ok, _} = Tenants.declare_person(ctx.tenant, ctx.admin.id, p.id, ctx.admin.id)

      assert %{declaradas: 1, contas: 2} = Tenants.elo_coverage(ctx.tenant), """
      A cobertura não distingue declaradas de existentes.

      `1 de 2` e `1` afirmam coisas diferentes: o primeiro diz que uma conta ainda não
      alcança painel nenhum.
      """
    end
  end
end
