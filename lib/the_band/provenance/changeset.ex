defmodule TheBand.Provenance.Changeset do
  @moduledoc """
  Validação da Application Reference (FR-012).

  `source_system` + `source_instance` + `external_id` + `collected_at`. Faltando
  qualquer um, o registro é **inválido**, não incompleto — sem eles não há
  rastreabilidade, e um dado sem origem não responde a pergunta que a plataforma
  existe para responder.

  O erro é agrupado sob `:provenance` de propósito: quem chama a API pública de
  uma ontologia precisa ver que faltou proveniência, não quatro erros de campo
  soltos.
  """

  import Ecto.Changeset

  @fields [:source_system, :source_instance, :external_id, :collected_at]

  @spec validate_application_reference(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def validate_application_reference(changeset) do
    faltando = Enum.filter(@fields, &(get_field(changeset, &1) in [nil, ""]))

    case faltando do
      [] ->
        changeset

      _ ->
        add_error(
          changeset,
          :provenance,
          "Application Reference incompleta: falta #{Enum.map_join(faltando, ", ", &to_string/1)}"
        )
    end
  end
end
