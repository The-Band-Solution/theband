# Semeia duas organizações clientes.
#
# São duas de propósito: SC-008 exige provar que uma não enxerga a outra, e essa
# verificação não pode ser feita só por teste unitário — precisa das duas bases
# povoadas ao mesmo tempo, e de alguém percorrendo a interface.
#
#     mix run priv/repo/seeds.exs
#
# ## A senha padrão é de DESENVOLVIMENTO, e o seed recusa produção
#
# Feature 045: a entrada exige senha. O seed dá aos admins uma senha padrão
# conhecida para o ambiente local funcionar sem cerimônia — e por isso mesmo
# ele LEVANTA em :prod. Produção nasce sem senha e usa o reinício por quem
# administra (FR-013/014); senha padrão em produção seria a porta aberta que a
# feature existe para fechar.

if Application.get_env(:the_band, :env, :dev) == :prod or
     (function_exported?(Mix, :env, 0) and Mix.env() == :prod) do
  raise "seeds.exs não roda em produção: a senha padrão é de desenvolvimento."
end

alias TheBand.Tenants

senha_padrao = "the-band-dev-123"

seed = fn slug, name, users ->
  tenant =
    case Tenants.get_by_slug(slug) do
      nil ->
        {:ok, tenant} = Tenants.create_tenant(%{"name" => name, "slug" => slug})
        tenant

      tenant ->
        tenant
    end

  Enum.each(users, fn {email, role} ->
    user =
      case Enum.find(Tenants.list_users(tenant), &(&1.email == email)) do
        nil ->
          {:ok, user} = Tenants.create_user(tenant, %{"email" => email, "role" => role})
          user

        user ->
          user
      end

    # Só quem ainda não tem senha ganha a padrão: rodar o seed de novo não
    # sobrescreve uma senha que a pessoa já trocou.
    if role == "admin" and is_nil(user.password_hash) do
      {:ok, _} = Tenants.set_password(tenant, user.id, senha_padrao)
    end
  end)

  tenant
end

seed.("the-band-solution", "The Band Solution", [
  {"admin@the-band-solution.example", "admin"},
  {"consulta@the-band-solution.example", "member"}
])

seed.("outra-org", "Outra Organização", [
  {"admin@outra-org.example", "admin"}
])

IO.puts("""

Organizações semeadas:

  The Band Solution   admin@the-band-solution.example      (admin)
                      consulta@the-band-solution.example   (member)
  Outra Organização   admin@outra-org.example              (admin)

Entrada de DESENVOLVIMENTO (feature 045):

  login  admin@the-band-solution.example
  senha  #{senha_padrao}     (admins sem senha recebem esta; troque em /profile)

member continua sem senha de propósito: o caminho dele é o reinício em /accounts
(FR-013). A segunda organização existe para a verificação de isolamento (SC-008).
""")
