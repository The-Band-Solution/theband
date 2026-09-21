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

  defmodule Organization do
    @moduledoc """
    Uma organização, no recorte mínimo que a listagem de pessoas carrega.

    Não é o recurso `/organizations` — ele não existe ainda. São os três campos que a tela
    de pessoas mostra na coluna de organizações, e nada mais: alargar aqui criaria um
    segundo contrato para organização, e dois contratos divergem.
    """
    require OpenApiSpex

    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "Organization",
      description: "An organisation, as it appears beside a person.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        login: %Schema{type: :string, nullable: true},
        name: %Schema{type: :string, nullable: true}
      },
      required: [:id]
    })
  end

  defmodule Person do
    @moduledoc "Uma pessoa observada, e o que a origem chama de conta."
    require OpenApiSpex

    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "Person",
      description: "A person the platform observed at a connected tool.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        name: %Schema{type: :string, nullable: true},
        login: %Schema{type: :string, nullable: true},
        account_type: %Schema{
          type: :string,
          description:
            "What the source says this account is — `person`, `bot` or `app`. It is the " <>
              "source's word, never a guess: counting a bot as a person would inflate every " <>
              "measure of who did the work."
        },
        origin: %Schema{
          type: :string,
          enum: ["observed", "declared"],
          description: "Same mark as everywhere else — where the platform learned about it."
        },
        source_system: %Schema{type: :string, nullable: true},
        source_instance: %Schema{
          type: :string,
          nullable: true,
          description:
            "Which installation of that system — the same login can exist on two of them."
        },
        external_id: %Schema{
          type: :string,
          nullable: true,
          description: "The identifier the source itself uses. Stable across renames."
        },
        organizations: %Schema{
          type: :array,
          items: TheBandWeb.Schemas.Organization,
          description:
            "A person's organisations come from their **teams** — there is no direct link " <>
              "between person and organisation. Empty when the person is in no team, and " <>
              "then `organizations_note` says why. Someone in more than one appears once, " <>
              "with all listed, so people counted per organisation add up to more than the " <>
              "total — and that is correct."
        },
        organizations_note: %Schema{
          type: :string,
          nullable: true,
          description:
            "Why `organizations` is empty. Null when it is not. An empty list with no " <>
              "reason would read as *this person has no organisation*, when what happened " <>
              "is that the link does not exist to be looked up."
        },
        collected_at: %Schema{type: :string, format: :"date-time", nullable: true},
        no_longer_observed_at: %Schema{
          type: :string,
          format: :"date-time",
          nullable: true,
          description:
            "When the source stopped returning this person. Null means still observed — " <>
              "**not** that the person is gone. Absence written, never a silent removal."
        }
      },
      required: [:id, :account_type, :origin, :organizations]
    })
  end

  defmodule People do
    @moduledoc "A coleção de pessoas."
    require OpenApiSpex

    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "People",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: TheBandWeb.Schemas.Person},
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
