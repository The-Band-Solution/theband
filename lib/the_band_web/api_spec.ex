defmodule TheBandWeb.ApiSpec do
  @moduledoc """
  A descrição OpenAPI da API pública — feature 061, US4, FR-040.

  **Gerada do código, nunca mantida à mão.** As rotas saem do `router.ex`, e as operações dos
  `@doc` de cada controlador. Um endpoint novo aparece aqui sem ninguém editar documento —
  que é o requisito, e não conveniência: descrição escrita à mão envelhece em silêncio, e uma
  que mente é pior que nenhuma, porque quem integra confia nela.
  """
  alias OpenApiSpex.Components
  alias OpenApiSpex.Info
  alias OpenApiSpex.OpenApi
  alias OpenApiSpex.Paths
  alias OpenApiSpex.SecurityScheme
  alias OpenApiSpex.Server

  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [Server.from_endpoint(TheBandWeb.Endpoint)],
      info: %Info{
        title: "The Band — public API",
        version: to_string(Application.spec(:the_band, :vsn)),
        description: """
        Read-only access to what the platform observed and what the organisation declared.

        **Every answer carries its provenance.** A team is `observed` when it came from a
        connected tool, and `declared` when someone stated it here. Delivering a number
        without that mark would destroy the distinction at the point of delivery — and the
        consumer may be a language model, which would assert the number without it.

        **The token carries no permission of its own.** What it reaches is read from the
        owner account on every call, so it shrinks when that person leaves a team. Nothing
        is cached; revoking takes effect on the next request.

        **Read-only, and not by omission.** No `POST`, `PUT`, `PATCH` or `DELETE` answers
        anywhere under `/api/v1` — there is no honest author for the provenance of a write
        made by a token.
        """
      },
      paths: Paths.from_router(TheBandWeb.Router),
      components: %Components{
        securitySchemes: %{
          "bearer" => %SecurityScheme{
            type: "http",
            scheme: "bearer",
            description: """
            The token generated in **Settings › API tokens**, sent as
            `Authorization: Bearer tb_api_…`.

            Only the header is read. A token in a query string is ignored — it leaks into
            server logs, browser history, and the `Referer` of anything the page loads next.
            """
          }
        }
      },
      security: [%{"bearer" => []}]
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
