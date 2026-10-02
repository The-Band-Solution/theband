defmodule TheBand.Platform do
  @moduledoc """
  API pública do operador da plataforma — spec 070. Contrato em
  `specs/070-operador-da-plataforma/contracts/suspensao.md`.

  Depende de: nenhuma ontologia.

  O que a tela do operador chama passa por aqui. A concessão do papel **não**: ela é só do comando
  de release (`TheBand.Platform.Grants`, FR-001).
  """
  alias TheBand.Platform.Suspensions

  defdelegate listar_organizacoes(sessao), to: Suspensions
  defdelegate suspender(sessao, slug, attrs), to: Suspensions
  defdelegate reativar(sessao, slug, attrs), to: Suspensions
end
