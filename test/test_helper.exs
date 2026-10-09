# Mox substitui apenas a borda HTTP. Módulo de domínio próprio nunca é mockado:
# mock de domínio esconde erro em vez de revelá-lo (AGENTS.md §7.6).
Mox.defmock(TheBand.GitHubHTTPMock, for: TheBand.Integrations.GitHub.HTTP)
Mox.defmock(TheBand.LLMHTTPMock, for: TheBand.Integrations.LLM.HTTP)
Application.put_env(:the_band, :github_http_client, TheBand.GitHubHTTPMock)

# Spec 071, T005: conectada pelo papel que serve, a suíte exclui os testes que criam papel no
# setup, porque esse papel não tem `CREATEROLE` — que é justamente o que a 071 garante.
excluir = if System.get_env("THE_BAND_TEST_DB_USER"), do: [:precisa_criar_papel], else: []
ExUnit.start(exclude: [:integration | excluir])
Ecto.Adapters.SQL.Sandbox.mode(TheBand.Repo, :manual)
