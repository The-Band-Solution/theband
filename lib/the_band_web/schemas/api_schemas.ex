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

  defmodule Competency do
    @moduledoc """
    Uma competência demonstrada, e as tarefas concluídas que a sustentam.

    A célula é `completed_tasks`: tarefa **concluída**. Entrega, nunca promessa — tarefa
    aberta é intenção e não demonstra nada.
    """
    require OpenApiSpex

    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "Competency",
      description: "A domain the record shows this person working in, and its evidence.",
      type: :object,
      properties: %{
        domain: %Schema{type: :string},
        completed_tasks: %Schema{
          type: :integer,
          description:
            "**Completed** tasks that evidence the domain. Delivery, never promise — an " <>
              "open task is intent and demonstrates nothing, so a highlight with zero " <>
              "completed tasks is not a competency and does not appear here."
        },
        demonstrated: %Schema{type: :string, nullable: true},
        evidence_issue_numbers: %Schema{
          type: :array,
          items: %Schema{type: :integer},
          description: "So each competency walks down to the record that holds it up."
        },
        periods: %Schema{type: :array, items: %Schema{type: :integer}},
        most_recent_period: %Schema{type: :string, nullable: true}
      },
      required: [:domain, :completed_tasks]
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
        competencies: %Schema{
          type: :array,
          nullable: true,
          items: %Schema{
            type: :object,
            properties: %{
              domain: %Schema{type: :string},
              completed_tasks: %Schema{type: :integer}
            }
          },
          description:
            "The short form — domain and completed tasks. **`null` and `[]` are different " <>
              "claims**: `null` means no profile was generated, so nothing was read; `[]` " <>
              "means the record was read and nothing was demonstrated. Flattening the two " <>
              "would turn a gap in the record into a judgement of the person. The " <>
              "evidence, issue by issue, is in the detail."
        },
        competencies_note: %Schema{
          type: :string,
          nullable: true,
          description: "Why `competencies` is `null`. Absent when it is a list."
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
        },
        stale_open: %Schema{
          type: :object,
          description:
            "Assigned and open past the declared threshold. `stale_after_days` travels " <>
              "along because *stale* is not an adjective, it is a cut in days — without it " <>
              "the count says nothing.\n\n" <>
              "`conversation` separates four cases a plain list would flatten: " <>
              "`nao_coletada` (the repository has had no comment collected — a gap in the " <>
              "**collection**), `silencio` (collected, and nobody spoke), `recente` and " <>
              "`antiga`. Without the first two apart, a gap in collection would read as " <>
              "silence from the team, and someone would hold a person to account for a " <>
              "conversation the platform never looked at.",
          properties: %{
            stale_after_days: %Schema{type: :integer},
            items: %Schema{type: :array, items: %Schema{type: :object}}
          }
        },
        issues: %Schema{
          type: :object,
          description:
            "The screen's first page of the assigned list. Searching and paging the whole " <>
              "list is its own resource, and does not exist yet.",
          properties: %{
            items: %Schema{type: :array, items: %Schema{type: :object}},
            limit: %Schema{type: :integer},
            note: %Schema{type: :string}
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
            tasks_closed_since: %Schema{
              type: :integer,
              description:
                "How many tasks closed since this profile was generated. Without it, a " <>
                  "profile written in December looks current in June, and whoever reads it " <>
                  "decides on old text without knowing it is old."
            },
            regeneration_pending: %Schema{type: :boolean},
            citations_removed: %Schema{type: :integer},
            competencies: %Schema{
              type: :array,
              items: TheBandWeb.Schemas.Competency,
              description: "With the evidence, issue by issue."
            },
            skills: %Schema{
              type: :array,
              items: %Schema{type: :string},
              description:
                "Labels the model wrote. **Not the competencies**: no count, no evidence. " <>
                  "Treating them as equivalent would give the same authority to a domain " <>
                  "with 18 completed tasks and to a loose word."
            },
            gaps: %Schema{type: :array, items: %Schema{type: :string}},
            summary: %Schema{
              type: :object,
              description:
                "The order is content, not alphabet: strengths, evolution, attention. " <>
                  "Swapping attention for strengths changes what a manager reads first.",
              properties: %{
                strengths: %Schema{type: :string, nullable: true},
                evolution: %Schema{type: :string, nullable: true},
                attention: %Schema{type: :string, nullable: true}
              }
            },
            allocation: %Schema{type: :array, items: %Schema{type: :object}},
            trajectory: %Schema{type: :array, items: %Schema{type: :object}},
            recommendations: %Schema{type: :array, items: %Schema{type: :string}},
            limits: %Schema{
              type: :object,
              description:
                "What the profile says about **itself**: what the record does not reach, " <>
                  "what belongs to the team rather than the person, and whether there is " <>
                  "evidence of writing for others. Returning the profile without these " <>
                  "would return a conclusion without its limits.",
              properties: %{
                beyond_reach: %Schema{type: :string, nullable: true},
                team_not_person: %Schema{type: :string, nullable: true},
                wrote_for_others: %Schema{nullable: true}
              }
            },
            evolution_over_time: %Schema{
              type: :object,
              description:
                "One point per generation, **oldest first**. A month with no generation is " <>
                  "absent, never interpolated: filling it in would claim an observation " <>
                  "that never happened.",
              properties: %{
                generations: %Schema{type: :array, items: %Schema{type: :object}},
                note: %Schema{type: :string}
              }
            }
          }
        },
        discussion_participation: %Schema{
          type: :object,
          description:
            "Where this person took part in discussion. `acts` are **positions taken**, " <>
              "not issues: five comments on one issue is five acts and one issue. " <>
              "`limit` travels along because a list truncated in silence makes whoever " <>
              "integrates conclude that is all there is.",
          properties: %{
            items: %Schema{type: :array, items: %Schema{type: :object}},
            limit: %Schema{type: :integer}
          }
        },
        changes: %Schema{
          type: :object,
          description:
            "**Four lists, never summed.** Opening, reviewing, merging and committing are " <>
              "distinct acts, and the same change request can appear in more than one — a " <>
              "total would count it twice. Outside the access verdict, as on the screen.",
          properties: %{
            opened: %Schema{type: :array, items: %Schema{type: :object}},
            reviewed: %Schema{type: :array, items: %Schema{type: :object}},
            merged: %Schema{type: :array, items: %Schema{type: :object}},
            commits: %Schema{type: :array, items: %Schema{type: :object}},
            limit: %Schema{type: :integer},
            note: %Schema{type: :string}
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

  defmodule TeamDetail do
    @moduledoc "Uma equipe, com a composição que define o alcance de tudo o mais."
    require OpenApiSpex

    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "TeamDetail",
      type: :object,
      properties: %{
        data: %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :string, format: :uuid},
            name: %Schema{type: :string, nullable: true},
            slug: %Schema{type: :string, nullable: true},
            origin: %Schema{type: :string, enum: ["observed", "declared"]},
            provenance: %Schema{type: :object},
            organization: %Schema{allOf: [TheBandWeb.Schemas.Organization], nullable: true},
            composition: %Schema{
              type: :object,
              description:
                "On a composed team the roster is the team **plus its parts** with a " <>
                  "current composition. There is one definition of *who belongs here*, " <>
                  "and every count uses it — a header counting by evidence over a list " <>
                  "counting by reach would give two answers to one question.",
              properties: %{
                is_composed: %Schema{type: :boolean},
                parts: %Schema{type: :array, items: %Schema{type: :object}},
                note: %Schema{type: :string}
              }
            },
            roster: %Schema{
              type: :object,
              description:
                "**Never summed.** *Left* says the membership existed and ended; " <>
                  "*mistake* says it should never have been claimed. Adding them would " <>
                  "erase the distinction revocation exists to keep.",
              properties: %{
                current: %Schema{type: :integer},
                left: %Schema{type: :integer},
                mistakes: %Schema{type: :integer}
              }
            },
            memberships_pending_role: %Schema{type: :integer},
            access: %Schema{
              type: :object,
              description:
                "Which of the four paths granted the reach: `admin`, `escopo_de_equipe`, " <>
                  "`escopo_da_organizacao` or `vinculo_vigente`. Out of reach never gets " <>
                  "here — it answers `404`.",
              properties: %{reason: %Schema{type: :string}}
            }
          }
        }
      },
      required: [:data]
    })
  end

  defmodule TeamMembers do
    @moduledoc "O roster: quem pertence, e por qual afirmação."
    require OpenApiSpex

    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "TeamMembers",
      type: :object,
      properties: %{
        data: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              person_id: %Schema{type: :string, format: :uuid},
              name: %Schema{type: :string, nullable: true},
              login: %Schema{type: :string, nullable: true},
              situation: %Schema{type: :string},
              direct: %Schema{type: :boolean},
              squads: %Schema{type: :array, items: %Schema{type: :object}},
              memberships: %Schema{
                type: :array,
                description:
                  "`origin` lives on the **membership**, not on the person: someone can " <>
                    "be observed in one team and declared in another, and both claims " <>
                    "hold at once.\n\n`ended_at` says *left*; `mistake` says *should " <>
                    "never have been claimed*. Flattening them would turn history into " <>
                    "error and error into history.\n\nWho declared it is **not** " <>
                    "returned — the field is an e-mail address, and e-mail is what this " <>
                    "API excludes on purpose.",
                items: %Schema{type: :object}
              }
            }
          }
        },
        page: TheBandWeb.Schemas.Page
      },
      required: [:data, :page]
    })
  end

  defmodule TeamMeasures do
    @moduledoc "As medidas da equipe — o que a integração leva para painel próprio."
    require OpenApiSpex

    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "TeamMeasures",
      type: :object,
      properties: %{
        data: %Schema{
          type: :object,
          properties: %{
            window: %Schema{
              type: :object,
              description:
                "Fixed at 56 days and **declared**: a measure over an undeclared window " <>
                  "answers a different question without saying so.",
              properties: %{
                days: %Schema{type: :integer},
                from: %Schema{type: :string, format: :"date-time"},
                to: %Schema{type: :string, format: :"date-time"}
              }
            },
            work: %Schema{
              type: :object,
              properties: %{
                members: %Schema{type: :integer},
                open: %Schema{type: :integer},
                closed_in_window: %Schema{type: :integer},
                stale: %Schema{type: :integer},
                no_work: %Schema{type: :boolean},
                note: %Schema{type: :string}
              }
            },
            open_by_person: %Schema{type: :array, items: %Schema{type: :object}},
            time_to_first_review: %Schema{
              type: :object,
              description:
                "`truncated` is not a pagination detail: a median over 200 of 500 is a " <>
                  "**different measure** wearing the same label. The list asks for one " <>
                  "more than the limit so the cut is never silent.",
              properties: %{
                items: %Schema{type: :array, items: %Schema{type: :object}},
                limit: %Schema{type: :integer},
                truncated: %Schema{type: :boolean},
                truncated_note: %Schema{type: :string}
              }
            },
            skills: %Schema{
              type: :object,
              description:
                "`without_profile` comes **named**, never summed as zero: absence of a " <>
                  "profile is absence of **reading**, so the team's coverage is a floor " <>
                  "and never a ceiling.",
              properties: %{
                members: %Schema{type: :integer},
                with_profile: %Schema{type: :integer},
                without_profile: %Schema{type: :array, items: %Schema{type: :object}},
                competencies: %Schema{type: :array, items: %Schema{type: :object}},
                coverage_note: %Schema{type: :string},
                summary: %Schema{type: :array, items: %Schema{type: :object}}
              }
            }
          }
        }
      },
      required: [:data]
    })
  end

  defmodule Projects do
    @moduledoc "Os projetos declarados, e as três ausências do critério de início."
    require OpenApiSpex

    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "Projects",
      type: :object,
      properties: %{
        data: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              id: %Schema{type: :string, format: :uuid},
              name: %Schema{type: :string, nullable: true},
              phase: %Schema{type: :string, nullable: true},
              parent: %Schema{type: :object, nullable: true},
              started_on: %Schema{type: :string, format: :date, nullable: true},
              ended_on: %Schema{type: :string, format: :date, nullable: true},
              issues: %Schema{
                type: :object,
                description:
                  "**Never summed.** An issue reached through a subproject is not a " <>
                    "second issue.",
                properties: %{
                  direct: %Schema{type: :integer},
                  via_subproject: %Schema{type: :integer},
                  note: %Schema{type: :string}
                }
              },
              start_criterion: %Schema{
                type: :object,
                description:
                  "**Three distinct absences, never one total.** An issue with no start " <>
                    "instant may lack a declared criterion (`no_criterion`), may have one " <>
                    "whose event was never collected (`event_not_collected`), or may have " <>
                    "matched more than one instant (`ambiguous`). Each needs a different " <>
                    "thing done, and an aggregate would say there **is** a problem without " <>
                    "saying **which**.\n\n`ambiguous` carries the **list**, not a count: " <>
                    "to break a tie you have to know which ones.",
                properties: %{
                  total: %Schema{type: :integer},
                  with_instant: %Schema{type: :integer},
                  no_criterion: %Schema{type: :integer},
                  event_not_collected: %Schema{type: :integer},
                  ambiguous: %Schema{type: :array, items: %Schema{type: :object}},
                  note: %Schema{type: :string}
                }
              },
              organizations: %Schema{type: :array, items: TheBandWeb.Schemas.Organization},
              teams: %Schema{
                type: :array,
                description:
                  "`origin` is a mark, not a boolean: the query stores `declared: " <>
                    "true|false`, and a boolean in place of the relator is a declared " <>
                    "antipattern here — it stays on the inner side of the boundary.",
                items: %Schema{type: :object}
              },
              repositories: %Schema{type: :array, items: %Schema{type: :object}},
              boards: %Schema{type: :array, items: %Schema{type: :object}}
            }
          }
        },
        page: TheBandWeb.Schemas.Page
      },
      required: [:data, :page]
    })
  end

  defmodule Syncs do
    @moduledoc "As coletas, e o que cada uma NÃO alcançou."
    require OpenApiSpex

    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "Syncs",
      description: "Collection runs. Answers *is the data current?*",
      type: :object,
      properties: %{
        data: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              id: %Schema{type: :string, format: :uuid},
              status: %Schema{type: :string, nullable: true},
              started_at: %Schema{type: :string, format: :"date-time", nullable: true},
              finished_at: %Schema{type: :string, format: :"date-time", nullable: true},
              records: %Schema{
                type: :object,
                description:
                  "Four readings of the same run, **never summed**: a record collected " <>
                    "falls into exactly one of created, updated or skipped.",
                properties: %{
                  collected: %Schema{type: :integer, nullable: true},
                  created: %Schema{type: :integer, nullable: true},
                  updated: %Schema{type: :integer, nullable: true},
                  skipped: %Schema{type: :integer, nullable: true},
                  note: %Schema{type: :string}
                }
              },
              gaps: %Schema{
                type: :object,
                description:
                  "**`completed` does not mean complete.** A run can finish and still not " <>
                    "have reached repositories — quota, permission, or the source being " <>
                    "unavailable. These travel in the same object so the status is never " <>
                    "read alone.",
                properties: %{
                  repositories_skipped: %Schema{type: :integer, nullable: true},
                  repositories_unreachable: %Schema{type: :integer, nullable: true},
                  skip_reasons: %Schema{nullable: true},
                  memberships_pending_role: %Schema{type: :integer, nullable: true},
                  note: %Schema{type: :string}
                }
              },
              error_reason: %Schema{type: :string, nullable: true},
              interrupted: %Schema{
                type: :boolean,
                description:
                  "Whether a person stopped the run. **Who** is not returned: the id would " <>
                    "name a person on a route that has no reason to."
              }
            }
          }
        },
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
