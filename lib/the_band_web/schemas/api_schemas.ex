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

  defmodule Work do
    @moduledoc """
    O painel de trabalho de uma pessoa — só existe quando o veredito de acesso é favorável.

    Nenhum par de números aqui se soma. Cada leitura responde uma pergunta, e juntá-las
    faria a resposta afirmar medida onde não há.
    """
    require OpenApiSpex

    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "Work",
      description: "What a person did, as far as it was observed.",
      type: :object,
      properties: %{
        assigned: %Schema{type: :integer, description: "Issues assigned to this person."},
        authored: %Schema{type: :integer, description: "Issues this person opened."},
        counts_note: %Schema{
          type: :string,
          description:
            "Says in the body that `assigned` and `authored` are never summed. Opening an " <>
              "issue and working on it are different acts."
        },
        open_assigned: %Schema{type: :integer},
        timeline_coverage: %Schema{
          type: :object,
          description: "How much of the work has an observed timeline. Never a bare ratio.",
          properties: %{
            observed: %Schema{type: :integer},
            total: %Schema{type: :integer}
          }
        },
        scale: %Schema{
          type: :string,
          enum: ["monthly"],
          description:
            "The scale of `series_by_period` and `burn`. Fixed for now, and always stated: " <>
              "a series without its scale means different things without saying so."
        },
        series_by_period: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              period: %Schema{type: :string},
              created: %Schema{type: :integer},
              closed: %Schema{type: :integer}
            }
          }
        },
        burn: %Schema{
          type: :array,
          description: "Burn-up and burn-down, derived from the series — no extra reading.",
          items: %Schema{
            type: :object,
            properties: %{
              period: %Schema{type: :string},
              scope: %Schema{type: :integer},
              done: %Schema{type: :integer},
              open: %Schema{type: :integer}
            }
          }
        },
        projection: %Schema{
          type: :object,
          description:
            "Where the current pace leads. `type` is one of `converges`, " <>
              "`does_not_converge`, `beyond_observed`, `no_open_work`, `no_data` or " <>
              "`too_close_to_call`, each carrying the numbers that hold it up.",
          properties: %{type: %Schema{type: :string}}
        },
        deadline: %Schema{
          type: :object,
          description:
            "**Declared, not projected** — it comes from the end of the time box. " <>
              "`without_time_box` counts the open issues in no box at all, and it is the " <>
              "number that says how much the date is worth.",
          properties: %{
            date: %Schema{type: :string, format: :date, nullable: true},
            source: %Schema{type: :string, nullable: true},
            without_time_box: %Schema{type: :integer}
          }
        },
        age_buckets: %Schema{
          type: :array,
          description:
            "How old the open work is. `label` is the screen's own, in Portuguese; sort " <>
              "and compare by `min_days`/`max_days`, because a label is not a stable key.",
          items: %Schema{
            type: :object,
            properties: %{
              label: %Schema{type: :string},
              min_days: %Schema{type: :integer},
              max_days: %Schema{type: :integer, nullable: true},
              count: %Schema{type: :integer}
            }
          }
        },
        lead_time: %Schema{
          type: :object,
          nullable: true,
          description:
            "Time from creation to closing. **Lead time, not cycle time**: it includes the " <>
              "time nobody touched the issue. Median and p85, never mean — one issue parked " <>
              "for 422 days moves the mean and not the median. `null` when nothing closed, " <>
              "and `null` is not zero days.",
          properties: %{
            count: %Schema{type: :integer},
            median_days: %Schema{type: :integer},
            p85_days: %Schema{type: :integer}
          }
        },
        verification: %Schema{
          type: :object,
          description:
            "Runs over this person's commits. `unattributed_in_tenant` stays apart and is " <>
              "**not** one of the first three: those runs match no person at all, and " <>
              "adding them would claim a measure that does not exist.",
          properties: %{
            passed: %Schema{type: :integer},
            broke: %Schema{type: :integer},
            other: %Schema{type: :integer},
            unattributed_in_tenant: %Schema{type: :integer}
          }
        },
        change_participation: %Schema{
          type: :object,
          description: "Six readings, never summed.",
          properties: %{
            opened: %Schema{type: :integer},
            merged: %Schema{type: :integer},
            reviewed: %Schema{type: :integer},
            endorsed: %Schema{type: :integer},
            objected: %Schema{type: :integer},
            abstained: %Schema{type: :integer}
          }
        },
        antipatterns: %Schema{
          type: :object,
          description:
            "`not_assessed` is here so it never becomes zero: three issues not assessed " <>
              "are not three issues without an antipattern.",
          properties: %{
            findings: %Schema{
              type: :array,
              items: %Schema{
                type: :object,
                properties: %{id: %Schema{type: :string}, count: %Schema{type: :integer}}
              }
            },
            assessed: %Schema{type: :integer},
            not_assessed: %Schema{type: :integer}
          }
        },
        repositories: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              repository_id: %Schema{type: :string, format: :uuid},
              name: %Schema{type: :string, nullable: true},
              qualified_name: %Schema{type: :string, nullable: true},
              assigned: %Schema{type: :integer},
              authored: %Schema{type: :integer}
            }
          }
        }
      }
    })
  end

  defmodule PersonFull do
    @moduledoc "Uma pessoa com tudo o que a tela dela mostra."
    require OpenApiSpex

    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "PersonFull",
      description: "One person, with everything the person's screen shows.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        name: %Schema{type: :string, nullable: true},
        login: %Schema{type: :string, nullable: true},
        account_type: %Schema{type: :string},
        origin: %Schema{type: :string, enum: ["observed", "declared"]},
        provenance: %Schema{
          type: :object,
          description: "Where this record came from, and when it was last seen there.",
          properties: %{
            source_system: %Schema{type: :string, nullable: true},
            source_instance: %Schema{type: :string, nullable: true},
            external_id: %Schema{type: :string, nullable: true},
            first_observed_at: %Schema{type: :string, format: :"date-time", nullable: true},
            last_observed_at: %Schema{type: :string, format: :"date-time", nullable: true},
            no_longer_observed_at: %Schema{type: :string, format: :"date-time", nullable: true}
          }
        },
        organizations: %Schema{
          type: :object,
          description:
            "**Two different claims, side by side and never summed.** `by_membership` " <>
              "climbs person → team → organisation. `by_work` is observed end to end: " <>
              "person → issue → repository → organisation, and it lists only organisations " <>
              "the person is not already a member of — repeating one in both lists would " <>
              "read as two pieces of evidence when it is one.",
          properties: %{
            by_membership: %Schema{type: :array, items: TheBandWeb.Schemas.Organization},
            by_work: %Schema{
              type: :array,
              items: %Schema{
                type: :object,
                properties: %{
                  organization: TheBandWeb.Schemas.Organization,
                  repositories: %Schema{type: :integer}
                }
              }
            },
            note: %Schema{type: :string}
          }
        },
        teams: %Schema{
          type: :array,
          description: "What the source declares. `promoted` marks evidence turned binding.",
          items: %Schema{
            type: :object,
            properties: %{
              team_id: %Schema{type: :string, format: :uuid},
              team_name: %Schema{type: :string, nullable: true},
              organization_login: %Schema{type: :string, nullable: true},
              platform_access_level: %Schema{type: :string, nullable: true},
              observed_at: %Schema{type: :string, format: :"date-time", nullable: true},
              last_observed_at: %Schema{type: :string, format: :"date-time", nullable: true},
              no_longer_observed_at: %Schema{
                type: :string,
                format: :"date-time",
                nullable: true
              },
              promoted: %Schema{type: :boolean}
            }
          }
        },
        roles: %Schema{
          type: :array,
          description:
            "Roles **declared** on this platform, current and ended. An ended role stays: " <>
              "whoever left it still held it, and hiding it would erase history. Who " <>
              "declared it is not returned — that field is an e-mail address, and e-mail " <>
              "is what this route excludes on purpose.",
          items: %Schema{
            type: :object,
            properties: %{
              id: %Schema{type: :string, format: :uuid},
              role_code: %Schema{type: :string, nullable: true},
              role_name: %Schema{type: :string, nullable: true},
              team_id: %Schema{type: :string, format: :uuid, nullable: true},
              team_name: %Schema{type: :string, nullable: true},
              started_at: %Schema{type: :string, format: :"date-time", nullable: true},
              ended_at: %Schema{type: :string, format: :"date-time", nullable: true},
              current: %Schema{type: :boolean}
            }
          }
        },
        roles_note: %Schema{
          type: :string,
          nullable: true,
          description: "Why `roles` is empty. Null when it is not."
        },
        account: %Schema{
          type: :object,
          description:
            "Which account on this platform is declared to be this observed person. " <>
              "`link_coverage` says how many accounts exist and how many were declared — " <>
              "a link that does not exist is a gap, not a zero.",
          properties: %{
            linked_user_id: %Schema{type: :string, format: :uuid, nullable: true},
            note: %Schema{type: :string, nullable: true},
            link_coverage: %Schema{
              type: :object,
              properties: %{
                accounts: %Schema{type: :integer},
                declared: %Schema{type: :integer}
              }
            }
          }
        },
        profile: %Schema{
          type: :object,
          nullable: true,
          description:
            "**Derived** — written by a language model from the collected record. It is " <>
              "never an observation, and the mark travels in the body because the expected " <>
              "consumer is another model, which would otherwise assert it as fact.",
          properties: %{
            origin: %Schema{type: :string, enum: ["derived"]},
            origin_note: %Schema{type: :string},
            generated_at: %Schema{type: :string, format: :"date-time", nullable: true},
            model: %Schema{type: :string, nullable: true},
            period: %Schema{
              type: :object,
              properties: %{
                from: %Schema{type: :string, format: :date, nullable: true},
                to: %Schema{type: :string, format: :date, nullable: true}
              }
            },
            content: %Schema{type: :object, additionalProperties: true}
          }
        },
        profile_note: %Schema{type: :string, nullable: true},
        access: %Schema{
          type: :object,
          description:
            "The verdict of `pode_ver/3` — the union of the floor, the derived scopes, the " <>
              "grants and the declared leadership. The reach is **whoever created the " <>
              "token's**, not the token's own. A refusal is recorded, exactly as the " <>
              "screen records it.",
          properties: %{
            can_see_work: %Schema{type: :boolean},
            reason: %Schema{
              type: :string,
              nullable: true,
              description:
                "Which refusal it is. Not disposable: *nobody declared who you are* and " <>
                  "*nobody was declared a leader* have different remedies, and whoever " <>
                  "integrates has to send the person to the right place."
            }
          }
        },
        work: %Schema{
          allOf: [TheBandWeb.Schemas.Work],
          nullable: true,
          description: "`null` when `access.can_see_work` is false. Not an empty panel."
        }
      },
      required: [:id, :account_type, :origin, :access]
    })
  end

  defmodule PersonDetail do
    @moduledoc "O envelope do detalhe — um objeto, e não uma coleção."
    require OpenApiSpex

    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "PersonDetail",
      type: :object,
      properties: %{data: TheBandWeb.Schemas.PersonFull},
      required: [:data]
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
