defmodule TheBand.Repo.Migrations.EstadoDaOrganizacaoValido do
  @moduledoc """
  `tenants.status` passa a ter `CHECK` — spec 070, T013, achado O10.

  Era texto livre: o código lia `"active"` e `"suspended"`, e qualquer outro valor entrava por
  digitação sem ninguém perceber (AGENTS §7.7, "estado como string livre"). O `up` **conta** os
  valores fora da lista e **levanta** com a contagem: nunca mapeia um valor desconhecido para um
  conhecido, porque mapear em silêncio é decidir por quem não decidiu (research R6).
  """
  use Ecto.Migration

  def up do
    execute(fn -> conferir_estados!(repo()) end)

    create constraint(:tenants, :tenants_status_valido,
             check: "status IN ('active', 'suspended')"
           )
  end

  @doc """
  Levanta com a contagem quando há estado fora da lista. Pública para o teste chamá-la sem o
  migrator, que não convive com o sandbox — o padrão de `sql_up/0` nas migrações da 064.
  """
  def conferir_estados!(repo) do
    %{rows: [[n]]} =
      repo.query!("SELECT count(*) FROM tenants WHERE status NOT IN ('active', 'suspended')")

    if n > 0 do
      raise "#{n} organização(ões) com estado fora de ('active', 'suspended'). " <>
              "Corrija à mão antes de migrar: o valor certo de cada uma é decisão, não mapeamento."
    end

    :ok
  end

  def down do
    drop constraint(:tenants, :tenants_status_valido)
  end
end
