# Sprint 033 — Acceptance record {#sprint-033--registro-de-aceitação}

**Feature**: [061 — the public API with an access token](../../../specs/061-api-publica/spec.md)

**Evaluated on**: 2026-09-23, on `development` after the merges of #933, #934, #935 and #936,
with **evidence executed in this evaluation** — 149 tests from the 061 files, plus seven
measurements written and run on purpose for the criteria that no named test covered.

**Role**: Product Owner. The release version was decided by the agent in the
`sro.product_owner_role` role; **this criteria evaluation was done by the agent that
implemented** — see the exception at the end.

**Rule**: `sro.rule03` — the phase follows from the criteria, with executed evidence. **A criterion
without evidence does not become accepted.**

## Summary {#resumo}

| | Count |
|---|---:|
| Criteria in the spec | 15 |
| **Conforming** | **13** |
| **Non-conforming** | **2** — SC-004 and SC-007 |
| Tests executed in the 061 files | 149, all passing |
| Measurements written for this evaluation | 7 |

**The two refusals are of different natures.** The SC-007 one is **scope**: measure
provenance was designed for the MCP server (feature 062) and did not reach the API. The SC-004 one is a
**small, localized defect**: the information exists and is discarded one line before
reaching the log.

---

## The fifteen, one by one {#os-quinze-um-a-um}

| # | Criterion | Verdict | Evidence |
|---|---|---|---|
| **SC-001** | 0 occurrences of the cleartext value in log, response, page and database | **conforming** | `test/the_band_web/api/segredo_nao_vaza_test.exs` — four sweeps, and the target is the **isolated secret**, not the whole value: the public id is in the database by design, and sweeping for the full value would pass with the secret stored on its own |
| **SC-002** | 0 identifiers of tenant B in tenant A's response | **conforming** | `isolamento_por_tenant_test.exs` — and the guard of the mechanism: **every domain query takes the tenant as a parameter**, checked through telemetry |
| **SC-003** | nonexistent, revoked and expired: byte-for-byte identical responses | **conforming** | measured in this evaluation: the three bodies, with the `request_id` normalized, are **identical** |
| **SC-004** | 100% of refusals with the real reason recoverable in the internal log, **the three reasons distinct** | **NOT CONFORMING** | measured: the log carries **two** categories — `sem_cabecalho` and `credencial_recusada` — and the three causes collapse into the second |
| **SC-005** | after revocation, 0 calls served | **conforming** | measured: before, `200`; five calls afterwards, `401` on all five |
| **SC-006** | 0 methods beyond `GET` and `HEAD` | **conforming** | `somente_leitura_test.exs` — walks the **route table**, not a hand-written list; a new route without refusal fails |
| **SC-007** | 100% of measure objects with declared provenance and limitations | **NOT CONFORMING** | measured: `/teams/:id/measures` returns `window`, `work`, `time_to_first_review`, `skills` and `open_by_person` — **no** provenance or limitations key from the knowledge base |
| **SC-008** | 0 fields where *not observed* and *measured zero* are indistinguishable | **conforming** | `person_detail_test.exs` — `competencies: null` (there was no reading) versus `[]` (there was one, and nothing demonstrated); and `median_hours: null` versus zero |
| **SC-009** | going through more than three pages returns each item exactly once | **conforming** | `person_controller_test.exs` — 80 people, 8 pages, 80 distinct ids |
| **SC-010** | 100% of endpoints in the OpenAPI description; an endpoint without a description fails CI | **conforming** | `team_controller_test.exs` compares the description with the **route table**. It really failed when `/people/:id` came in, and was fixed |
| **SC-011** | with the limit exceeded by one token, another one gets `200` | **conforming** | `registro_e_limite_test.exs` — counting is per token, and one does not spend the other's limit |
| **SC-012** | 0 token rows physically removed, including on revocation | **conforming** | measured: one row before, one after revocation |
| **SC-013** | the tokens screen shows state and last use, with no value or hash | **conforming** | measured on the rendered HTML: state present, last use present, value absent, hash absent |
| **SC-014** | a scope refusal returns `404` and not `403` | **conforming** | `team_detail_test.exs` and `person_detail_test.exs` — out of reach and nonexistent return the **same** response |
| **SC-015** | 0 endpoints in `/api/v1` outside the FR-021 list | **conforming** | measured: 8 `GET` routes, none outside |

---

## SC-004 — the cause, and why it is small {#sc-004--a-causa-e-por-que-é-pequena}

`TheBand.Tenants.ApiTokens.autenticar/1` collapses the causes into a single `else`:

```elixir
with {:ok, id_publico, segredo} <- partes(valor),
     %Token{} = token <- por_id_publico(id_publico),
     true <- confere?(token, segredo),
     :ativo <- Token.estado(token, agora()) do
  {:ok, carimbar(token)}
else
  _ -> {:error, :recusado}
end
```

**The information exists and is discarded.** `Token.estado/2` already computes `:ativo`, `:revogado` or
`:expirado`; the `_` in the `else` throws it away, and the plug logs `motivo=credencial_recusada` for
all three.

**The response to the client is right and must stay the same** — that is SC-003, and distinguishing the
three there would confirm to whoever is testing a stolen credential that it existed. What is missing is the
distinction **in the internal log**, which is where it is useful.

**Fix**: return `{:error, :inexistente | :revogado | :expirado | :recusado}` and pass the
reason to the `Logger.warning` that already exists. The HTTP response does not change.

## SC-007 — scope, not defect {#sc-007--escopo-e-não-defeito}

Measure provenance — value, composition, window, origin, rule id and version,
`limitations` and `misinterpretations` read from the knowledge base — was **designed for the
MCP server**, in feature [062](../../../specs/062-servidor-mcp/data-model.md), and the envelope
is specified there.

The API delivers what **the screen** delivers: notes written in the controller, and the window declared in
`window`. They are honest, and they are not what SC-007 asks for.

**This is not a one-line fix.** It requires the public function `KnowledgeBase.measurement/1`,
which does not exist — it is task T003 of 062 —, and then the envelope on every API measure.

---

## The exception, declared {#a-exceção-declarada}

**This evaluation was done by whoever implemented.** The Product Owner role decided the release
version; the criterion-by-criterion check was mine, and it is worth less exactly where it would
matter most.

**And there was no independent review** of the API design nor of the security evaluation that
gave rise to #936. Four attempts by agent failed on September 21 and 22, 2026 — two
hung without writing anything, two were refused because the tool was unavailable.

**No merge fulfills that.** Correct classification: *review did not happen*.

---

## The verdict {#o-veredito}

**Feature 061 is accepted with two written caveats.**

Thirteen of fifteen criteria conforming, with executed evidence. The two missing ones do not block
delivery and **must not be forgotten**:

- **SC-004** becomes a backlog item: a small defect, a localized fix, with no change in the
  response to the client;
- **SC-007** becomes a declared dependency of feature 062: measure provenance is born there, and
  once it is, the API can start using it.

Accepting with a written caveat is different from accepting in silence. What is left out is left
**named**.
