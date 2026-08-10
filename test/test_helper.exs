# Mox substitui apenas a borda HTTP. Módulo de domínio próprio nunca é mockado:
# mock de domínio esconde erro em vez de revelá-lo (AGENTS.md §7.6).
Mox.defmock(TheBand.GitHubHTTPMock, for: TheBand.Integrations.GitHub.HTTP)
Application.put_env(:the_band, :github_http_client, TheBand.GitHubHTTPMock)

ExUnit.start(exclude: [:integration])
Ecto.Adapters.SQL.Sandbox.mode(TheBand.Repo, :manual)
