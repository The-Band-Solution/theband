# Semeia duas organizações clientes.
#
# São duas de propósito: SC-008 exige provar que uma não enxerga a outra, e essa
# verificação não pode ser feita só por teste unitário — precisa das duas bases
# povoadas ao mesmo tempo, e de alguém percorrendo a interface.
#
#     mix run priv/repo/seeds.exs

alias TheBand.Tenants

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
    unless Enum.any?(Tenants.list_users(tenant), &(&1.email == email)) do
      {:ok, _} = Tenants.create_user(tenant, %{"email" => email, "role" => role})
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

A segunda existe para a verificação de isolamento entre organizações (SC-008).
""")
