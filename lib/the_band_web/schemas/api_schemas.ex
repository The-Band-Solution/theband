defmodule TheBandWeb.Schemas do
  @moduledoc """
  As formas que a API devolve — feature 061.

  Cada uma existe como módulo para que a descrição OpenAPI saia **do código**: mudar o
  serializador sem mudar a forma aqui quebra o teste de contrato.
  """

  defmodule Team do
    @moduledoc "Uma equipe, com a marca de onde ela veio."
    require OpenApiSpex

    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "Team",
      description: "A team, and where the platform learned about it.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        name: %Schema{type: :string},
        slug: %Schema{type: :string, nullable: true},
        origin: %Schema{
          type: :string,
          enum: ["observed", "declared"],
          description:
            "`observed` came from a connected tool, and `source_system` says which. " <>
              "`declared` was stated by a person here, and `source_system` is null. " <>
              "This mark is the distinction the whole platform exists to keep."
        },
        source_system: %Schema{type: :string, nullable: true},
        collected_at: %Schema{type: :string, format: :"date-time", nullable: true}
      },
      required: [:id, :name, :origin]
    })
  end

  defmodule Page do
    @moduledoc "A paginação, e a ausência declarada do total."
    require OpenApiSpex

    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "Page",
      type: :object,
      properties: %{
        has_next: %Schema{type: :boolean},
        next_cursor: %Schema{type: :string, nullable: true},
        total: %Schema{
          type: :integer,
          nullable: true,
          description: "Always null — see `total_note`."
        },
        total_note: %Schema{
          type: :string,
          description:
            "This API does not count collections. An estimated total is worse than an " <>
              "absent one, and the note travels with the null so a raw reader understands it."
        }
      },
      required: [:has_next, :total, :total_note]
    })
  end

  defmodule Teams do
    @moduledoc "A coleção de equipes."
    require OpenApiSpex

    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "Teams",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: TheBandWeb.Schemas.Team},
        page: TheBandWeb.Schemas.Page
      },
      required: [:data, :page]
    })
  end

  defmodule Erro do
    @moduledoc "O formato único de erro — um tratador, não seis."
    require OpenApiSpex

    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "Error",
      type: :object,
      properties: %{
        error: %Schema{
          type: :object,
          properties: %{
            code: %Schema{
              type: :string,
              enum: ~w(unauthorized not_found method_not_allowed internal_error)
            },
            message: %Schema{
              type: :string,
              description:
                "Never says which cause occurred. For 401 it is identical for a token that " <>
                  "never existed, one revoked, one expired, and one whose owner account is " <>
                  "disabled — telling them apart confirms to whoever is testing a stolen " <>
                  "credential that it existed."
            },
            request_id: %Schema{
              type: :string,
              description: "Finds the real reason in the internal log."
            }
          },
          required: [:code, :message, :request_id]
        }
      },
      required: [:error]
    })
  end
end
