# The release flow, end to end

**Written on**: 2026-09-13 · Describes what **exists**, measured against `.github/workflows/cd.yml`
and against the instance at `[redigido]`. What does not exist yet is marked as such.

---

## The question that gave rise to this document

*"Can a service be installed in Dokploy from the local image?"*

**No.** And the reason is not a tool limitation — it is architectural, and it is worth
understanding before the rest.

Dokploy runs on **another machine**. An image in `docker images` here exists only on this
disk. To get there it needs a **registry**, and that is what the CD already does.

And there is a better reason than the technical one: **a local image has no provenance.** Nobody knows
which commit it came from, whether the suite passed, whether `mix.exs` matched the tag. The
registry image carries all of that — it is the same principle this house applies to the data it collects.

---

## The flow, as it is today

```
1. decisão          Product Owner avalia e decide a versão
                    ↓
2. PR de release    development → main   ·   MERGE COMMIT, nunca squash
                    ↓
3. push em main     dispara .github/workflows/cd.yml
                    ↓
4. CD, seis passos  ┌─ a versão vem do mix.exs — versão repetida FALHA nomeando
                    ├─ login no ghcr
                    ├─ build e publicação da imagem
                    ├─ a tag git vX.Y.Z nasce do merge
                    ├─ delivery no Dokploy — resposta não-2xx FALHA
                    └─ a produção confirma a versão — resposta diferente FALHA
                    ↓
5. Dokploy          puxa ghcr.io/the-band-solution/theband:vX.Y.Z e sobe
                    ↓
6. verificação      dois agentes, e eles medem coisas diferentes
```

### Step 4 is what prevents lying

Three of the six steps **fail on purpose**, and each one closes a way for the deploy to look
successful without being so:

| step | what it prevents |
|---|---|
| repeated version FAILS | publishing two different images with the same tag |
| non-2xx webhook FAILS | the image existing and nobody deploying it — silence read as success |
| **production confirms the version** | Dokploy accepting the webhook and bringing up **another** image |

The last one is finding **H7**, and it is the most important. Without `/version` answering, *"the release
went up"* is the opinion of whoever looked at the panel.

**Measured on 2026-09-13**: `GET https://[redigido]/version` returns **404** — production
predates PR #859, which created the endpoint. Until v0.8.0 goes up, nobody can ask
production what it is running.

---

## Who does what

Four roles, and **none of them does the work of another**.

### 1. `product-owner` — decides

**When**: before the release PR.

Evaluates what is in `development` and not in `main`, decides the semver version with a justification,
writes the release content in `docs/releases/vX.Y.Z.md` with **the summary of each PR up
front** — a list of numbers without a summary does not pass (constitution 1.6.0).

**It does not execute the release.** The moment of delivery is its recorded decision, not its act.

⚠️ **On 2026-09-13 this agent hung** — 600s without progress, nothing written. The assessment of
v0.8.0 was done directly. If it hangs again, the way is to measure by hand: new migrations,
new variables, and what changes on a screen already in use.

### 2. The CD — publishes and deploys

No agent. It is `.github/workflows/cd.yml`, triggered by `push` to `main`.

### 3. `deploy-producao` — measures the infrastructure

**When**: after the deploy, or when it fails.

Measures SC-001 to SC-005 against the real address: sign in and see a dashboard, release time, restore
rehearsal, zero secrets in logs, refusal without a session. It also does rollback.

**It does not authorize a release, does not receive secrets, does not create a VPS.**

### 4. `aceitacao-em-producao` — measures the functionality

**When**: after the deploy, and it is the only one that answers *"does what was delivered work?"*

It reads the **SC and FR of the spec** and measures them live, screen by screen. Its first measurement is always
`/version` — without it the report errs in the worst possible way: *"the feature is not there"*
when the truth is *"the release did not go up"*.

**Report rule**: an unmeasured criterion **never** becomes ✅. It goes to the section of what was not
measured, with the reason.

### The difference between the last two, which is easy to miss

| | measures |
|---|---|
| `deploy-producao` | that the **platform** goes up, stores and restores |
| `aceitacao-em-producao` | that **whoever uses it** sees and can do what the spec promised |

Green gates prove neither one nor the other: between the merge and going live there is release, build,
publication and deploy — and each one has already failed silently in this project.

---

## The command we are going to create: `/release`

**It does not exist yet.** What exists is the CD; what is missing is the human step before it, which today
is done by hand and therefore forgets things.

### What it does

```
/release                    avalia e prepara — NÃO publica
/release --executar         abre o PR de release, depois da aprovação
```

In order:

1. **audits against the origin** — constitution 1.8.0, principle VII. Clean working directory **first**,
   then commits, then issues. On 2026-09-13 a PR failed in CI because the fix was
   in the working directory and not in the commit, and that day's audit did not look at that;
2. **calls the `product-owner`** to decide the version and write `docs/releases/vX.Y.Z.md`;
3. **measures the risks**, and they are always the same three:
   - new migrations since the last release — and whether any is **destructive**;
   - new environment variables — and whether any is **mandatory**;
   - behavior change on a screen already in use;
4. **updates `mix.exs`** — and **checks that it updated**. On 2026-09-13 the `sed` failed because
   of a comma, the verification `grep` showed the old value in the same output, and the
   commit went out saying the version had changed;
5. **stops**, and shows what it found. The moment of delivery belongs to the maintainer.

With `--executar`: opens the `development → main` PR, **merge commit** declared, with the table of
PRs and what the release does not carry.

### What it never does

- **does not merge** — whoever clicks is whoever decides;
- **does not create the tag by hand** — the tag is born from the CD, and creating it beforehand would make the
  *"repeated version FAILS"* step fail the deploy itself;
- **does not touch Dokploy** — the webhook belongs to the CD;
- **does not receive secrets.**

---

## If the Dokploy API route is really wanted

The API exists and answers:

```
http://[redigido]/api/health   → 200 {"ok":true}
http://[redigido]/api/swagger  → 401   (existe, exige autenticação)
```

Authentication by the **`x-api-key`** header, with a token generated in *Settings → API/CLI*. With it
one can `application.update` (change the image tag) and `application.deploy` (redeploy).

**But that duplicates what the webhook already does**, and adds a secret to keep. The webhook does not
need a new token, lives in the CD, and **fails loudly** if the response is not 2xx.

If it is still the choice: the token goes into `DOKPLOY_API_KEY` in the environment, read without being
printed — like the master key and like the acceptance password.

**Source**: <https://docs.dokploy.com/docs/api> and <https://docs.dokploy.com/docs/core/registry>.
The documentation lists the providers — GitHub, Git, Docker, webhook — and the Docker provider talks
to a **registry**. It **does not say** that a local image does not work; it simply does not offer
that path, and I am recording this as an absence in the documentation, not as a prohibition.

---

## What this document does NOT cover

- **the Dokploy installation** — it is §1 of the runbook, and has already been done;
- **the panel secrets** — they live there and in GitHub Secrets, pasted by a person;
- **rollback** — belongs to `deploy-producao`, and has its own procedure;
- **whether `DOKPLOY_WEBHOOK_URL` is configured** — I did not check. The CD declares the absence if it
  does not exist, and that declaration is the evidence to look for in the first deploy.
