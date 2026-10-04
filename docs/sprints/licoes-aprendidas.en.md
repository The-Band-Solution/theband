# Lessons learned {#lições-aprendidas}

A cumulative record that spans sprints. Read it **before** opening any new
sprint: an open lesson that applies enters as a constraint, not as a
suggestion.

A sprint that ends without recording what it learned condemns the next one to repeat the
same mistakes — and the repeated mistake is the one that costs the most, because it was already
known.

---

## How to use this record {#como-usar-este-registro}

There are **101 lessons** across 29 sprints. Nobody reads a hundred and one when opening a
sprint — and it was because they were not read that **L92** recurred with L75 and L83 already
written, and **L95** recurred in the sprint right after the one that created it.

That is why the index is **by family**, and each family has **one rule**. The seven
rules take a minute; the blocks are for when the rule is not enough and someone
needs the concrete case.

> **A lesson that describes a repeatable act does not belong to this document alone.** It
> becomes a rule in `AGENTS.md` and a mandatory field in the artifact where the act happens.
> The **why** stays here; the **obligation** goes there — L98.

---

## The seven families {#as-sete-famílias}

### The defect that produces no error {#o-defeito-que-não-produz-erro}

Absence of error is not a result. The gate needs to know how to **fail**, and the failure path needs to be exercised.

| # | Lesson | Type | Sprint |
|---|---|---|---|
| [L05](#l05--varchar255-em-coluna-de-diagnóstico-troca-o-erro-real-por-um-erro-de-banco) | `varchar(255)` in a diagnostic column swaps the real error for a database error | — | 001 |
| [L07](#l07--autogenerate-false-em-chave-binary_id-devolve-struct-sem-id) | `autogenerate: false` on a `binary_id` key returns a struct without `id` | — | 001 |
| [L13](#l13--secret-referenciado-e-não-cadastrado-chega-como-string-vazia) | A secret that is referenced but not registered arrives as an empty string | — | 001 |
| [L19](#l19--marcar-ausência-por-tenant-marca-o-que-é-de-outra-organização) | Marking absence per tenant marks what belongs to another organization | — | 002 |
| [L22](#l22--gate-que-só-compara-duas-execuções-não-sabe-dizer-se-alguma-funcionou) | A gate that only compares two runs cannot tell whether either worked | — | 002 |
| [L23](#l23--aviso-de-verificação-pulada-é-reprovação-não-observação) | A skipped-check warning is a failure, not an observation | — | 002 |
| [L26](#l26--casar-o-envelope-errado-devolve-lista-vazia-em-vez-de-erro) | Matching the wrong envelope returns an empty list instead of an error | — | 002 |
| [L29](#l29--falha-transitória-que-marca-estado-permanente-tira-dado-de-circulação-em-silêncio) | A transient failure that marks a permanent state silently takes data out of circulation | — | 002 |
| [L32](#l32--texto-que-afirma-o-que-a-plataforma-não-observou-é-o-mesmo-defeito-na-direção-oposta) | Text that asserts what the platform did not observe is the same defect, in the opposite direction | — | 002 |
| [L36](#l36--gate-que-descarta-o-retorno-da-task-não-é-gate) | A gate that discards the task's return value is not a gate | — | 002 |
| [L54](#l54--átomo-criado-sob-demanda-faz-o-resultado-depender-da-ordem-de-carga) | An atom created on demand makes the result depend on load order | technical | 014 |
| [L57](#l57--verificação-que-filtra-um-tipo-que-ninguém-produz-nunca-roda) | A check that filters for a type nobody produces never runs | technical | 014 |
| [L62](#l62--somar-contadores-por-lista-escrita-à-mão-apaga-a-chave-nova-em-silêncio) | Summing counters through a hand-written list silently drops the new key | technical | 021 |
| [L63](#l63--vínculo-que-só-grava-o-que-casou-apaga-o-que-a-origem-disse) | A link that only records what matched erases what the source said | technical | 021 |
| [L66](#l66--script-que-monta-o-contexto-à-mão-esconde-o-contrato-que-o-job-real-quebra) | A script that builds the context by hand hides the contract the real job breaks | technical | 021 |
| [L69](#l69--defeito-dentro-de-loggerinfo-é-invisível-a-teste-por-configuração) | A defect inside `Logger.info` is invisible to tests, by configuration | technical | 002 |
| [L101](#l101--issue-fechada-na-integração-afirma-sobre-a-produção) | An issue closed on integration makes a claim about production | process | 029 |

**17 open** · closed or merged: L60

### The number that lies about what it measured {#o-número-que-mente-sobre-o-que-mediu}

Moving denominator, measure in progress, a total that hides a phenomenon. **Compare the overlap**, never the totals.

| # | Lesson | Type | Sprint |
|---|---|---|---|
| [L04](#l04--campo-opcional-na-query-pode-custar-um-escopo-inteiro) | An optional field in the query can cost a whole scope | — | 001 |
| [L37](#l37--a-coluna-estreita-só-cai-quando-a-escrita-fica-frequente) | The narrow column only breaks when writes become frequent | — | 002 |
| [L38](#l38--o-custo-de-uma-tela-se-mede-pela-diferença-e-pela-constância-nunca-pelo-total) | The cost of a screen is measured by the difference and by the constancy, never by the total | technical | 009 |
| [L40](#l40--duas-grandezas-com-nomes-parecidos-e-o-complemento-derivado-da-errada) | Two quantities with similar names, and the complement derived from the wrong one | process | 010 |
| [L49](#l49--uma-medida-não-descreve-uma-tela-cujo-custo-depende-do-plano-de-execução) | One measurement does not describe a screen whose cost depends on the execution plan | technical | 012 |
| [L53](#l53--o-teto-de-um-teste-de-custo-vem-da-medida-dos-dois-lados) | The ceiling of a cost test comes from measuring both sides | technical | 013 |
| [L64](#l64--denominador-que-inclui-o-caso-impossível-esconde-o-sinal) | A denominator that includes the impossible case hides the signal | technical | 021 |
| [L67](#l67--duas-medidas-do-mesmo-nome-comparar-os-totais-esconde-que-são-fenômenos-diferentes) | Two measures with the same name: comparing the totals hides that they are different phenomena | technical | 002 |
| [L70](#l70--número-medido-no-meio-de-um-backfill-parece-final-e-não-é) | A number measured in the middle of a backfill looks final and is not | process | 002 |
| [L86](#l86--denominador-móvel-mente-igual-a-denominador-inventado) | A moving denominator lies just like an invented denominator | technical | 026 |
| [L90](#l90--contar-só-o-vencedor-da-corrida-não-prova-o-perdedor) | Counting only the winner of the race does not prove the loser | technical | 026 |

| [L107](#l107--git-log---merges-conta-metade-dos-prs) | `git log --merges` counts half of the PRs | technical | 030 |
**12 open**

### Asserting without measuring at the source {#afirmar-sem-medir-na-origem}

Dashboard, HTTP and log say what the source contradicts. **One query against the source** finds what the suite does not.

| # | Lesson | Type | Sprint |
|---|---|---|---|
| [L30](#l30--conferir-o-número-contra-a-origem-acha-o-que-a-suíte-não-acha) | Checking the number against the source finds what the suite does not | — | 002 |
| [L33](#l33--a-pergunta-que-pega-o-defeito-de-migração-é-o-que-a-tela-diz-no-dia-seguinte) | The question that catches the migration defect is "what does the screen say the next day" | — | 002 |
| [L47](#l47--vínculo-entre-repositórios-só-existe-a-partir-da-segunda-coleta) | A link between repositories only exists from the second collection onward | knowledge | 011 |
| [L51](#l51--afirmar-sobre-o-schema-sem-conferir-contradiz-a-documentação-que-já-está-no-código) | Asserting about the schema without checking contradicts the documentation already in the code | process | 012 |
| [L61](#l61--uma-limitação-declarada-no-mapeamento-não-vira-restrição-no-código-sozinha) | A limitation declared in the mapping does not become a constraint in the code by itself | knowledge | 021 |
| [L76](#l76--a-ferramenta-de-medir-precisa-da-gramática-do-alvo) | The measuring tool needs the target's grammar | technical | 024 |
| [L80](#l80--a-pendência-medida-com-o-grep-do-instrumento-herda-a-cegueira-dele) | A backlog of pending items measured with the instrument's own grep inherits its blindness | technical | 024 |
| [L84](#l84--o-painel-dizer-done-não-significa-aplicação-no-ar) | The board saying `Done` does not mean the application is live | technical | 026 |
| [L85](#l85--um-200-de-http-pode-afirmar-o-que-o-socket-contradiz) | An HTTP 200 can assert what the socket contradicts | technical | 026 |
| [L93](#l93--durante-o-deploy-duas-versões-atendem-e-a-medida-de-fora-não-diz-qual-respondeu) | During a deploy, two versions serve, and the outside measurement does not say which one answered | technical | 026 |
| [L94](#l94--mensagem-que-afirma-a-causa-sem-conferir-manda-procurar-no-lugar-errado) | A message that asserts the cause without checking sends you looking in the wrong place | technical | 027 |

| [L106](#l106--a-verificação-rodou-deu-a-resposta-certa-e-ninguém-a-leu) | The check ran, gave the right answer, and nobody read it | process | 030 |
| [L110](#l110--a-spec-usou-a-palavra-do-mecanismo-com-outro-sentido-e-o-exemplo-nunca-foi-olhado-no-dado) | The spec used the mechanism's word with another meaning, and the example was never looked at in the data | knowledge | 032 |
**13 open** · closed or merged: L35

### The test that does not prove what it claims to prove {#teste-que-não-prova-o-que-diz-provar}

It compares something with itself, depends on the clock, or closes the counterexample without closing the class.

| # | Lesson | Type | Sprint |
|---|---|---|---|
| [L03](#l03--um-teste-com-dado-inválido-encontra-o-que-o-caminho-feliz-esconde) | A test with invalid data finds what the happy path hides | — | 001 |
| [L20](#l20--estado-derivado-do-último-precisa-de-desempate-determinístico) | State derived from "the latest" needs a deterministic tie-break | — | 002 |
| [L41](#l41--teste-que-compara-uma-coisa-com-ela-mesma-passa-sempre) | A test that compares something with itself always passes | technical | 010 |
| [L42](#l42--mensagem-atrasada-de-telemetria-entra-na-contagem-seguinte) | A late telemetry message lands in the next count | technical | 010 |
| [L43](#l43--quando-o-axioma-responde-a-pergunta-errada-a-correção-é-a-precondição-não-um-filtro-na-resposta) | When the axiom answers the wrong question, the fix is the precondition, not a filter on the answer | technical | 010 |
| [L46](#l46--teste-com-corte-temporal-e-dado-montado-no-mesmo-instante-passa-ou-falha-por-sorte) | A test with a time cutoff and data built at the same instant passes or fails by luck | technical | 011 |
| [L50](#l50--teste-que-compara-duas-medidas-precisa-provar-que-mediu-alguma-coisa) | A test that compares two measurements must prove it measured something | technical | 012 |
| [L56](#l56--filtrar-telemetria-pela-source-não-alcança-quem-consulta-por-sql-cru) | Filtering telemetry by `source` does not reach whoever queries with raw SQL | technical | 014 |
| [L59](#l59--o-verde-do-ci-dependia-de-quem-disparou-a-execução) | The CI green depended on who triggered the run | technical | 015 |
| [L68](#l68--corte-incremental-exclui-para-sempre-o-registro-antigo-quando-a-consulta-ganha-campo) | An incremental cutoff excludes the old record forever when the query gains a field | technical | 002 |
| [L77](#l77--verificador-novo-nasce-com-teste-de-ponta-que-não-passa-por-ele) | A new checker is born with an end-to-end test that does NOT go through it | technical | 024 |
| [L78](#l78--troca-em-runtime-só-entra-no-contrato-com-teste-em-runtime) | "Swap at runtime" only enters the contract with a runtime test | technical | 024 |
| [L81](#l81--fechar-o-contraexemplo-não-fecha-a-classe) | Closing the counterexample does not close the class | technical | 025 |

**13 open**

### Merge, branch and history {#merge-branch-e-histórico}

**Squash when the branch dies at the merge; merge commit when someone depends on its history.** It became a rule — `AGENTS.md` §12 and the PR template.

| # | Lesson | Type | Sprint |
|---|---|---|---|
| [L12](#l12--pull-request-não-aberto-na-hora-passa-a-carregar-outra-feature) | A pull request not opened on time ends up carrying another feature | — | 001 |
| [L52](#l52--continuidade-de-conversa-não-é-continuidade-de-branch) | Continuity of conversation is not continuity of branch | process | 013 |
| [L58](#l58--pr-empilhado-incorporado-depois-da-base-não-chega-a-lugar-nenhum) | A stacked PR merged after its base goes nowhere | process | 015 |
| [L74](#l74--a-árvore-de-trabalho-decide-o-que-o-dev-server-serve) | The working tree decides what the dev server serves | process | 023 |
| [L79](#l79--agente-com-árvore-compartilhada-não-troca-de-branch) | An agent with a shared tree does not switch branches | process | 024 |

**8 open** · closed or merged: none

**L75, L83 and L92 were REOPENED on 2026-09-03** — the v0.4.0 release went in by
squash with the rule in `AGENTS.md`, the field in the template and the reason declared in the
PR body. See
[The three squash lessons](#as-três-do-squash-encerradas-juntas--sprint-028): they only
close when the guard is configuration, and not a reminder.

### Review and PR {#revisão-e-pr}

Requesting a reviewer and getting a review are different acts. **Zero reviews is a blocker, not an observation.**

| # | Lesson | Type | Sprint |
|---|---|---|---|
| [L15](#l15--não-há-revisor-possível-num-repositório-de-um-colaborador-só) | There is no possible reviewer in a single-collaborator repository | — | 001 |
| [L48](#l48--palavra-de-fechamento-em-português-não-fecha-a-issue-e-nada-avisa) | A closing keyword in Portuguese does not close the issue, and nothing warns you | process | 011 |
| [L82](#l82--o-comentário-que-contradiz-o-contrato-é-a-violação-documentando-a-si-mesma) | The comment that contradicts the contract is the violation documenting itself | process | 025 |
| [L88](#l88--um-segredo-de-8-segundos-e-o-contrato-que-salvou-o-diagnóstico) | An 8-second secret, and the contract that saved the diagnosis | dependency | 026 |
| [L95](#l95--pedir-revisor-não-é-obter-revisão-e-o-merge-não-espera) | Requesting a reviewer is not getting a review, and the merge does not wait | process | 027 |
| [L98](#l98--a-lição-que-não-vira-regra-reincide-no-sprint-seguinte) | The lesson that does not become a rule recurs in the next sprint | process | 028 |

**6 open** · closed or merged: L14, L89

### The cycle step with no owner {#o-passo-do-ciclo-sem-dono}

What has no gate disappears. Check **issue by issue** before declaring something delivered.

| # | Lesson | Type | Sprint |
|---|---|---|---|
| [L01](#l01--ferramenta-de-scaffolding-sobrescreve-documento-normativo) | A scaffolding tool overwrites a normative document | — | 001 |
| [L02](#l02--servidor-no-ar-duplica-o-efeito-de-qualquer-job-disparado-por-script) | A running server duplicates the effect of any job triggered by a script | — | 001 |
| [L06](#l06--cd-no-shell-persiste-entre-comandos-e-escreve-no-lugar-errado) | `cd` in the shell persists between commands and writes to the wrong place | — | 001 |
| [L08](#l08--contrato-escrito-junto-com-o-código-descreve-não-decide) | A contract written alongside the code describes, it does not decide | — | 001 |
| [L09](#l09--um-contrato-pode-contradizer-a-si-mesmo-e-só-a-implementação-revela) | A contract can contradict itself, and only the implementation reveals it | — | 001 |
| [L10](#l10--rótulo-de-cipher-precisa-identificar-a-chave-não-a-versão-do-algoritmo) | A cipher label must identify the key, not the algorithm version | — | 001 |
| [L11](#l11--configurar-iterations-do-projectv2-recria-as-existentes) | Configuring ProjectV2 iterations recreates the existing ones | — | 001 |
| [L17](#l17--a-derivação-do-esquema-não-era-função-da-ontologia) | The derivation of the schema was not a function of the ontology | — | 002 |
| [L18](#l18--um-critério-atendido-não-é-um-critério-suficiente) | A criterion that is met is not a sufficient criterion | — | 002 |
| [L21](#l21--função-pública-testada-e-sem-consumidor-não-é-funcionalidade-entregue) | A tested public function with no consumer is not delivered functionality | — | 002 |
| [L24](#l24--caminho-que-só-roda-no-ambiente-limpo-não-é-testado-por-quem-já-tem-o-ambiente) | A path that only runs in a clean environment is not tested by whoever already has the environment | — | 002 |
| [L25](#l25--número-da-issue-não-identifica-ele-é-único-dentro-do-repositório) | An issue number does not identify: it is unique within the repository | — | 002 |
| [L27](#l27--implementar-antes-do-plano-faz-o-teste-descobrir-o-que-o-plano-descobriria) | Implementing before the plan makes the test discover what the plan would have discovered | — | 002 |
| [L28](#l28--calcular-e-não-gravar-é-pior-que-não-calcular) | Computing and not storing is worse than not computing | — | 002 |
| [L31](#l31--regra-nova-muda-o-significado-de-teste-que-passava) | A new rule changes the meaning of a test that used to pass | — | 002 |
| [L34](#l34--a-mesma-palavra-para-duas-coisas-diferentes-esconde-o-caso-que-a-feature-existe-para-resolver) | The same word for two different things hides the case the feature exists to solve | — | 002 |
| [L39](#l39--um-join-num-escopo-compartilhado-desloca-os-bindings-de-quem-compõe-sobre-ele) | A `join` in a shared scope shifts the bindings of whoever composes on top of it | technical | 009 |
| [L44](#l44--sprint-que-fecha-sem-review-deixa-a-lição-rascunhada-e-a-próxima-feature-a-cita-como-se-existisse) | A sprint that closes without a review leaves the lesson as a draft, and the next feature cites it as if it existed | process | 009 |
| [L45](#l45--sprint-novo-tirado-da-main-não-enxerga-o-fecho-do-sprint-anterior-enquanto-o-pr-está-aberto) | A new sprint branched from `main` does not see the previous sprint's closing while the PR is open | process | 011 |
| [L55](#l55--task-que-não-compila-valida-o-build-anterior) | A task that does not compile validates the previous build | process | 014 |
| [L65](#l65--coleta-que-a-rede-já-especificou-custa-a-fração-de-uma-que-não) | A collection the network has already specified costs a fraction of one it has not | process | 021 |
| [L71](#l71--quando-o-requisito-muda-de-lugar-os-testes-que-documentam-o-lugar-antigo-caem-em-lote) | When the requirement moves, the tests that document the old place fall in bulk | process | 022 |
| [L72](#l72--a-api-de-iterations-substitui-a-lista-inteira-reenviar-sempre-as-vigentes) | The iterations API replaces the whole list: always resend the ones in force | technical | 023 |
| [L73](#l73--isvisible-não-vê-o-corte-por-overflow-a-prova-de-tela-é-a-imagem) | `isVisible` does not see clipping by overflow: the proof of a screen is the image | process | 023 |
| [L87](#l87--fase-invisível-faz-trabalho-parecer-travado) | An invisible phase makes work look stuck | technical | 026 |
| [L91](#l91--o-passo-do-ciclo-que-não-tem-gate-é-o-que-some) | The cycle step that has no gate is the one that disappears | process | 026 |
| [L96](#l96--issue-que-ninguém-fecha-faz-o-sprint-parecer-não-entregue) | An issue nobody closes makes the sprint look undelivered | process | 027 |
| [L97](#l97--feature-que-corrige-o-vínculo-não-corrige-quem-lê-o-vínculo) | A feature that fixes the link does not fix whoever reads the link | technical | 027 |
| [L99](#l99--conferir-issue-por-issue-achou-o-que-planejar-não-achou) | Checking issue by issue found what planning did not | process | 028 |
| [L100](#l100--branch-de-documentação-sem-pr-faz-o-código-chegar-sem-a-spec) | A documentation branch without a PR makes the code arrive without the spec | process | 028 |

| [L108](#l108--três-features-seguidas-sem-sprint-backlog-e-a-aceitação-sem-lugar) | Three features in a row without a sprint backlog, and acceptance with no place | process | 032 |
| [L109](#l109--tarefa-fechada-sem-código-com-o-critério-da-spec-intacto) | A task closed "without code" with the spec's criterion untouched | process | 032 |
**32 open**

---

## Closed {#encerradas}

Closing **does not erase**. It moves the obligation to where it can be verified, and leaves here
the reasoning that produced it — the block stays in the body of the document.

| # | Lesson | How it was closed |
|---|---|---|
| [L60](#l60--o-pipe-no-mix-gates-devolve-o-código-de-saída-do-tail) | The pipe on `mix gates` returns the exit code of `tail` | rule in `AGENTS.md` §7 — `mix gates` is the single definition, and the verdict is **its exit code** |
| [L75](#l75--squash-merge-abre-janela-para-commits-órfãos-na-branch-do-pr) | Squash-merge opens a window for orphan commits on the PR branch | rule in `AGENTS.md` §12 and a mandatory field in the PR template |
| [L83](#l83--squash-merge-no-release-diverge-os-históricos) | Squash-merge on the release makes the histories diverge | rule in `AGENTS.md` §12 and a mandatory field in the PR template |
| [L92](#l92--squash-num-back-merge-apaga-o-back-merge) | Squash on a back-merge erases the back-merge | rule in `AGENTS.md` §12 and a mandatory field in the PR template |

## Merged {#fundidas}

Lessons that described the **same act at different moments**. Kept apart, each
half looked fulfilled on its own — which is exactly how the defect got through.

| # | Merged into | Why |
|---|---|---|
| [L14](#l14--gh-engole-em-silêncio-o-pedido-de-revisão-recusado) | **[L95](#l95--pedir-revisor-não-é-obter-revisão-e-o-merge-não-espera)** | `gh` silently swallowing the request and the merge not waiting for the review are the same hole, at both ends |
| [L35](#l35--conferir-contra-a-origem-acha-defeito-fora-da-feature-que-se-está-entregando) | **[L30](#l30--conferir-o-número-contra-a-origem-acha-o-que-a-suíte-não-acha)** | it is not a new lesson: it is L30 saying that **summing the total is not enough** — the comparison is item by item |
| [L89](#l89--pr-sem-revisor-pedido-não-é-pr-revisado-e-o-merge-não-sabe-disso) | **[L95](#l95--pedir-revisor-não-é-obter-revisão-e-o-merge-não-espera)** | the two halves of the same failure — L89 checks `reviewRequests` **after requesting**, L95 checks `reviews` **before merging**. Kept apart, each looked fulfilled on its own |

---

## Sprint 001 — Foundation and EO collection (2026-08-09) {#sprint-001--fundação-e-coleta-eo-2026-08-09}

### L01 — A scaffolding tool overwrites a normative document {#l01--ferramenta-de-scaffolding-sobrescreve-documento-normativo}

**What happened.** `mix phx.new .` in the existing directory overwrote
`AGENTS.md` — the project's normative document — with the generic version that
Phoenix 1.8 generates. It also replaced `.gitignore` and `README.md`.

**Why it matters.** `AGENTS.md` has 654 lines of accumulated decisions. The loss
was only not permanent because the file was committed; had the generation
happened before the commit, it would have vanished without warning. Nothing in the generator's
output mentions that it overwrote a normative file.

**How to apply.** Before running any generator over an already populated directory,
check that `git status` is clean and list what the generator creates. After running it,
`git diff --stat` and restore what should not have changed — **before**
any commit.

### L02 — A running server duplicates the effect of any job triggered by a script {#l02--servidor-no-ar-duplica-o-efeito-de-qualquer-job-disparado-por-script}

**What happened.** The demonstration called `Worker.perform/1` directly with
`mix phx.server` running. The server's Oban picked the same job from the queue, and the
collection ran twice: 32 records collected instead of 16, two pages per
entity instead of one.

**Why it matters.** The numbers looked plausible. Without checking against the source
— 6 people, 2 teams — the duplication would have passed as a correct result, and the
FR-028 report would have been lying.

**How to apply.** A demonstration or load script uses **the same path the
interface uses**: enqueue and wait. Call `perform/1` by hand only with the server
stopped, and saying in the script itself why it is doing so.

### L03 — A test with invalid data finds what the happy path hides {#l03--um-teste-com-dado-inválido-encontra-o-que-o-caminho-feliz-esconde}

**What happened.** The test "a record without an Application Reference is rejected"
brought the query down with an Ecto `ArgumentError` — comparing a column with `nil` is
forbidden — instead of returning an invalid changeset. The real collection would never have
exposed this: GitHub always returns `id`.

**Why it matters.** The code was correct for every input the source
produces, and broke on the first input a new source would produce. The
defect would have stayed latent until the second integration.

**How to apply.** For each invariant the spec declares, write the test for the
**violation**, not only the one for conformance. Validate before querying, whenever the
query uses fields that the validation requires.

### L04 — An optional field in the query can cost a whole scope {#l04--campo-opcional-na-query-pode-custar-um-escopo-inteiro}

**What happened.** Asking for `email` in the GraphQL queries made the collection fail with
`INSUFFICIENT_SCOPES`: the field requires `read:user`, much broader than the
`read:org` the collection needs. The mapping itself already declared that this field
"is usually null due to privacy settings".

**Why it matters.** The request would have pushed every tenant to grant a broader
scope for a field that is almost always empty — and excess scope is attack surface
that nobody reviews after it is granted.

**How to apply.** When building a query, check field by field which scope it
requires, and cross-reference with the limitations declared in the mapping. A field declared as
"usually null" does not justify an additional scope.

### L05 — `varchar(255)` in a diagnostic column swaps the real error for a database error {#l05--varchar255-em-coluna-de-diagnóstico-troca-o-erro-real-por-um-erro-de-banco}

**What happened.** `syncs.error_reason` was `varchar(255)`. A longer GraphQL error
overflowed the `UPDATE`, and the exception that showed up was
`string_data_right_truncation` — not the cause of the collection failure. The diagnosis
took one extra round just because of that.

**How to apply.** A column that stores a reason, message or diagnosis is born `text`.
An arbitrary limit on an error field protects nothing and erases the information
exactly when it is most needed.

### L06 — `cd` in the shell persists between commands and writes to the wrong place {#l06--cd-no-shell-persiste-entre-comandos-e-escreve-no-lugar-errado}

**What happened.** A `cd /tmp` done to test the interface with `curl`
persisted, and the following commands created `test/test_helper.exs` inside
`/tmp`. The project's real `test/`, generated by Phoenix, was left untouched — and the
wrong conclusion was "the generator did not create the tests".

**How to apply.** A command that writes a file uses an absolute path, or starts with an
explicit `cd` to the root. Before concluding that a directory does not exist,
check where the check was made from.

### L07 — `autogenerate: false` on a `binary_id` key returns a struct without `id` {#l07--autogenerate-false-em-chave-binary_id-devolve-struct-sem-id}

**What happened.** The schemas declared `@primary_key {:id, :binary_id,
autogenerate: false}` relying on Postgres's `DEFAULT gen_random_uuid()`. The
`INSERT` worked, but the returned struct came back with `id: nil`, and the first
association to use it compared `tenant_id` with `nil`.

**How to apply.** With `binary_id`, `autogenerate: true` in the schema; the database
`DEFAULT` remains as a safety net for inserts outside Ecto.

### L08 — A contract written alongside the code describes, it does not decide {#l08--contrato-escrito-junto-com-o-código-descreve-não-decide}

**What happened.** `/speckit-analyze` found two divergences between
`contracts/ontology-eo.md` and the code: the signature of
`mark_evidence_no_longer_observed/2` and the `opts` of the read functions. In both
cases the **code was right and the document was out of date**. Both contracts
had been drafted alongside the implementation.

**Why it matters.** A contract written afterward becomes a comment: it describes what already
exists, stops deciding what should exist, and the divergence between the two
becomes invisible until someone compares line by line. One of the
divergent items, `:order_by`, promised to parameterize the ordering — which would have
reintroduced through the back door the divergence between `list_*` and `count_*` that
the contract itself existed to prevent.

**How to apply.** Write the contract **before** the first public function:
signature, success return, error return, and what the API deliberately
does not expose. When the implementation shows the contract was wrong — and it will —,
fix the contract in the same commit, with the reason.

The section "what this API does not expose" is the one that pays off most. It was what kept
`create_person/2` from existing without provenance, and `delete_*` from erasing what
should become `no_longer_observed_at`. Writing it forces you to decide the absences,
which is where most boundary errors are born.

It became a norm in `AGENTS.md` §12 and in the constitution, principle VI, amendment 1.1.0.

### L09 — A contract can contradict itself, and only the implementation reveals it {#l09--um-contrato-pode-contradizer-a-si-mesmo-e-só-a-implementação-revela}

**What happened.** The reprocessing contract, written before the code,
promised `{:error, {:unknown_mapping, id}}` as a batch return **and**, in the
next paragraph, that a broken mapping does not prevent the correction of the others.
Both cannot be true at the same time. The contradiction only became
visible when writing the clause that never matched.

**How to apply.** A contract before the code does not exempt the contract from review. When
implementing, treat an unreachable clause and a return that never occurs as a
**symptom of a wrong contract**, not as code to delete silently: the right
question is which of the document's two statements prevails, and why.

### L10 — A cipher label must identify the key, not the algorithm version {#l10--rótulo-de-cipher-precisa-identificar-a-chave-não-a-versão-do-algoritmo}

**What happened.** The master key rotation was implemented with two ciphers
with fixed labels — `AES.GCM.V1` for the new key and `AES.GCM.V0` for the old one.
Cloak chooses which cipher to decrypt with by the **label stored at the start of the encrypted
value**. Since the label said nothing about the key, it chose by the order of the
configuration and used the wrong one. The rotation did not work.

**Why it matters.** The symptom would be "I cannot decrypt this credential", with no
apparent cause, and only at the moment of using it — in the middle of a collection, with the
tool being flagged as needing attention for a reason that was not the
real one. No unit test of the cipher would have caught it: each one works
alone, and the defect only exists when the two keys coexist.

**How to apply.** The cipher label derives from the key — eight characters of SHA-256
are enough to identify without revealing. That way each encrypted value carries which key
encrypted it, and the choice no longer depends on configuration order.

The more general point: **secret rotation is only verifiable by running the rotation.**
Implementing both sides and checking that they compile proves nothing — the proof is to
re-encrypt and then read with the new key, and with it alone.

### L11 — Configuring ProjectV2 iterations recreates the existing ones {#l11--configurar-iterations-do-projectv2-recria-as-existentes}

**What happened.** When adding the sprint 002 iteration,
`updateProjectV2Field` **replaced the whole set** of iterations. The
sprint 001 one was recreated with a new identifier, and the 77 items assigned to it
were orphaned. The mutation does not accept `id` on existing iterations, so there is
no way to preserve them by passing the list.

When reassigning, a second error: the script assigned by issue number, and the project
contained 10 items from **other repositories** — which went to sprint 001 and
had to be cleaned up.

**Why it matters.** Nothing warns you. The iteration still exists with the same
title and the same dates; only the identifier changed, and the items simply
stop appearing in the sprint. Anyone looking at the board would see an empty sprint with no
explanation.

**How to apply.** Before touching the iterations configuration, list the items and
their iteration identifiers — that is what allows reassigning. And filter by
**repository**, not by issue number: an issue number is not unique in a project
that aggregates several repositories.

Better still: create all planned iterations at once, at the start, and not
touch the configuration again while a sprint is open.

**Applied in**: Sprint 002 — when changing the cadence from 14 to 7 days, on 2026-08-10.

### The procedure that worked, and the discovery it revealed {#o-procedimento-que-funcionou-e-a-descoberta-que-ele-revelou}

The cadence change required touching the same configuration. With the lesson applied as a
procedure, the damage was fully reverted:

| Step | Result |
|---|---|
| snapshot **before** — item, repository, number and iteration of each item | 97 items: 76 in sprint 001, 11 in 002, 10 with no iteration |
| `updateProjectV2Field` with `duration: 7` | both iterations recreated, **97 orphan items** — as predicted |
| reassignment by the snapshot's **`item id`** | 87 reassigned, 0 failures |
| check against the snapshot | 76 · 11 · 10, and the 10 with no iteration from **other repositories**, as they were |

Two choices made the difference, and both come from this lesson:

- **reassigning by `item id`**, which does not change when the iteration is recreated. That is what
  avoided repeating the mistake of matching by issue number — a number is not unique in a project
  that aggregates several repositories;
- **taking the snapshot before.** Without it, the information about which item belonged to which
  sprint would not exist anywhere after the mutation. It is not a precautionary backup:
  it is the only copy.

**New discovery: an iteration with a date in the past leaves `iterations` and enters
`completedIterations`.** On receiving 2026-08-03 with 7 days, the sprint 001 one ended
before today and changed lists, with its own identifier (`2849580c`). The mutation's own
response returned **only** sprint 002, which looks like data loss and is not.

Consequence for any script: **read both lists.** Whoever queries only
`iterations` concludes that the past iteration ceased to exist, and a
reassignment script that only looks for it there fails silently — leaving orphaned the items of the
closed sprint, which is precisely the history the flow measures depend on.

### L12 — A pull request not opened on time ends up carrying another feature {#l12--pull-request-não-aberto-na-hora-passa-a-carregar-outra-feature}

**What happened.** Task T073 of feature 001 called for opening the pull request at the
end of that feature. It was not opened. Sprint 001 closed, sprint 002 was
planned, and three documentation commits from 002 went into the same branch
`feature/001-github-eo-ingestion`.

When the PR was finally opened, it no longer contained feature 001: it contained
001 **plus** the planning of 002. Fifteen commits, two scopes.

**Why it happened.** Opening the PR was the feature's last task, and the last
task is the one that gets pushed back. Nothing prevented the next work from
starting before it — and next work, on the same branch, is work that goes
into the PR.

**Why it matters.** The reviewer loses the unit of review. A PR with two
scopes forces the reviewer to mentally separate what belongs to which feature, and that is
exactly where what should not get through gets through. Worse: the review of 001 becomes
a condition for merging 002 documents that have nothing to do with it.

**How to apply.** Two things, and the second is the one that solves it:

1. open the PR **when the task calls for it**, not when the feature "is polished" —
   a PR opened early is reviewable in parts; a PR opened late is unreviewable;
2. **do not pull new work while an earlier item has no destination.** This lesson is the
   origin of the rule the `product-owner` skill started requiring in planning, and
   of Phase 0 of sprint 002: whatever was left over from the previous sprint gets a destination before
   any new scope is selected.

The destination does not have to be "done". It can be returned to the backlog, discarded
with a reason, or blocked with a named blocker — independent review is of that
last kind, because it requires a person the team cannot produce. What cannot happen
is for it to stay open with none of the four.

**Applied in**: Sprint 002 — Phase 0, before F1.

### L13 — A secret that is referenced but not registered arrives as an empty string {#l13--secret-referenciado-e-não-cadastrado-chega-como-string-vazia}

**What happened.** The feature 001 PR was opened and CI failed on `mix test`,
with the application refusing to boot because the master key was missing. The eight gates passed
on the local machine, and nothing in the code was wrong.

The workflow declared `THE_BAND_MASTER_KEY: ${{ secrets.THE_BAND_MASTER_KEY }}`, and
the secret **was not registered** in the repository. GitHub does not omit the variable
in this case: it sets it to an **empty string**.

**Why it happened.** `config/runtime.exs` has a deliberate fallback — in
`config_env() == :test` it provides a fixed and admittedly public key, because in
CI it only encrypts fixtures in a throwaway database. The pattern was `{nil, :test}`, and
`""` is not `nil`. The fallback existed and was not reached.

The result is the worst of both worlds: **referencing a secret that does not exist became
worse than never having referenced it.** Without the line, the fallback would work.

**Why it matters beyond this case.** Absent and empty are the same thing for
any secret, credential or key — no system accepts `""` as a
valid value. Where the code distinguishes the two, it created a third state nobody
modeled, and that state shows up exactly when someone forgets to register something.
`TheBand.Vault` already got it right (`decode_key(value) when value in [nil, ""]`); the
configuration did not. One piece treated empty as absent, the other as a value.

**How to apply.**

1. **Where absence is handled, handle empty the same way.** `when blank in [nil, ""]`,
   never just `nil`;
2. **Do not reference a secret the environment does not need.** CI did not need its own
   key: `:test` already provides one. The reference added no protection and
   broke the fallback;
3. **A gate green locally is not a green gate.** This defect only existed in CI, and only
   showed up because the PR was opened and the pipeline **ran**. It is the same shape as
   [L10](#l10--rótulo-de-cipher-precisa-identificar-a-chave-não-a-versão-do-algoritmo):
   the proof is running, not implementing.

**Applied in**: Sprint 002 — Phase 0, when opening the 001 PR.

### L14 — `gh` silently swallows the rejected review request {#l14--gh-engole-em-silêncio-o-pedido-de-revisão-recusado}

> **Merged into L95 in Sprint 028** — `gh` silently swallowing the request and the merge not waiting for the review are the same hole, at both ends.

**What happened.** The rule that every PR is born with a requested reviewer came into force, and
PR #90 was opened with `gh pr create ... --reviewer paulossjunior`. The command
printed the URL and **nothing else** — no warning, exit code zero.

The reviewer was not assigned. `gh pr edit 90 --add-reviewer paulossjunior` did the
same: printed the URL, exited with zero, assigned no one.

Only the direct API call showed the reason:

```text
POST repos/.../pulls/90/requested_reviewers
422  Review cannot be requested from pull request author.
```

**Why it happened.** The PR was opened with `paulossjunior`'s token, so he is
the author — and GitHub refuses to request a review from the author of their own PR. The refusal is
legitimate and is exactly the rule principle VII wants: nobody reviews what they
wrote.

The defect is not the refusal. It is `gh` **not reporting it**: the `--reviewer` flag fails
without a signal, and whoever runs the command is convinced they requested a review.

**Why it matters.** It is the worst class of failure for a process rule. A rule
that fails loudly is fixed on the spot; one that fails silently produces a record
that asserts compliance — "the PR was opened with a reviewer" — while the
reviewer's queue stays empty. The check and the result diverge, and nothing warns you.

Same shape as [L13](#l13--secret-referenciado-e-não-cadastrado-chega-como-string-vazia):
the configuration looked right and the effect did not exist.

**How to apply.**

1. **Never trust the exit code of `gh pr create --reviewer`.** After
   opening the PR, check the result:
   `gh pr view <n> --json reviewRequests`. An empty list means nobody was
   requested, regardless of what the command said;
2. **To see the error, use the API**, not the flag:
   `gh api -X POST repos/<owner>/<repo>/pulls/<n>/requested_reviewers -f 'reviewers[]=<login>'`;
3. **Record the gap when the request is impossible.** A single account does not satisfy
   principle VII: whoever opens the PR and whoever reviews it must be different identities.
   While they are the same, the requirement is unreachable, and that belongs in the record of
   each sprint instead of reappearing as a surprise at every merge.

**Applied in**: Sprint 002 — when opening PR #90, which is the case itself.

### L15 — There is no possible reviewer in a single-collaborator repository {#l15--não-há-revisor-possível-num-repositório-de-um-colaborador-só}

**What happened.** The rule that every PR is born with a requested reviewer was written and
failed on the next three attempts, each for a different reason:

```text
reviewers[]=paulossjunior
  422  Review cannot be requested from pull request author.

team_reviewers[]=the-band
  422  Reviews may only be requested from collaborators.
       One or more of the users or teams you specified is not a collaborator.
```

The survey explained why:

| Fact | Evidence |
|---|---|
| the repository has **one** collaborator: `paulossjunior`, admin | `GET /repos/.../collaborators` |
| **no team** has access | `GET /repos/.../teams` returns empty |
| a review can only be requested from a collaborator | the second 422 |
| the author cannot be the reviewer | the first 422 |

**Why it matters.** The four together give **zero possible reviewers**: the only
collaborator is the author of every PR. Principle VII of the constitution — review by someone who
did not implement — is **unreachable** in this repository, not delayed. It was treated
as a scheduling item during the whole of sprint 001; it was a permission item.

The organization has two teams with people who did not implement — `the-band`, with
`Adylla027` and `EduardoNFraiz`, and `zeppelin`, with three more. Neither of them is
a collaborator on the repository. **The capacity to review exists in the organization and does not
reach the repository**, and nothing in the process reveals it: the requirement appears as a
pending item on a list, indistinguishable from an item that only needs time.

**How to apply.**

1. **Before writing a rule that depends on a permission, verify the permission.**
   The repository's `collaborators` and `teams` answer in two calls whether the rule can be
   fulfilled. An unfulfillable rule costs the same writing effort and has no effect;
2. **Distinguish a scheduling item from a permission item.** The first closes with
   work, the second only with a decision by whoever administers. Mixing them makes the second
   get replanned sprint after sprint without ever moving forward;
3. **Declare the impossibility with the four pieces of evidence**, and not as "review
   pending". The generic phrase suggests that waiting is enough.

**Applied in**: Sprint 002 — the inheritance from sprint 001 started classifying independent
review as blocked **structurally**, and not as delayed.

**Resolved on 2026-08-10, with two API calls:**

```text
PUT /orgs/The-Band-Solution/teams/the-band/repos/The-Band-Solution/theband
    permission=pull

POST /repos/.../pulls/91/requested_reviewers
    team_reviewers[]=the-band          → {"equipes":["the-band"]}
```

`pull` is the minimum a review requires — whoever reviews needs to read, not write.

**Correction to the record.** This paragraph said the grant gave the team **read** access,
and the effective level is something else: `Adylla027` and `EduardoNFraiz` are organization admins, so the
resolved level on the repository is `admin`. Granting `pull` to the team did not elevate
anyone — it only made them **visible as collaborators**, which was exactly what
was missing for the review request to go through.

The mechanism of the lesson is still right; the description of the access was wrong. And the
distinction matters: "I gave two people read access" and "two people who were already admins
became reachable by the review request" are different facts, and only the second
is true.

**Requesting from the team is better than requesting from a person**, and not for convenience: the request
stays open to any member, and the author, being a member, simply cannot
fulfill it. GitHub's restriction comes to **produce** the independence the principle
requires, instead of blocking it.

**What this teaches, and it is the point of the lesson.** The requirement went through a whole sprint
as "review pending", indistinguishable from any item that only needs time. What
was missing were **two API calls**. The pending item was not about effort or
scheduling; it was about permission, and the only reason it lasted so long is that nobody asked
*whether* it was possible before planning *when* it would be done.

**A residue remains that cannot be recovered**: PR #89 was already merged without review, and there is
no way to request a review of a merged PR. The feature 001 code is on `main` without
ever having been reviewed, and that remains in the acceptance record — the correction applies
from #91 onward.

## Sprint 002 — Scope by organization (2026-08-10 to 2026-08-16) {#sprint-002--escopo-por-organização-2026-08-10-a-2026-08-16}

### L17 — Schema derivation was not a function of the ontology {#l17--a-derivação-do-esquema-não-era-função-da-ontologia}

**What happened.** Task T004 required a mandatory regression: add the association rule to the
deriver and check that **the derivation of every other ontology comes out identical**. The
comparison flagged ten of the eleven ontologies as changed.

None had changed. Three runs of the **same code**, over the **same base**, gave three different
outputs:

```text
run1 != run2
run1 != run3
```

**Why it happened.** `owned = {cid for cid, (o, _) in concepts.items() ...}` is a set of strings,
and iterating a set of strings in Python varies between runs because of hash randomization. That
order decided the insertion order into `absorbed`, which decided the order of the discriminator
values, of the notes and of the columns. `glob` added its share: it returns in file-system order,
and the read order decided the order of the relations, and therefore of the foreign keys.

**Why it matters far more than the aesthetics of the output.** ADR 0004 decides that the
information model is **derived and never hand-written**. A derivation that changes between runs is
not a derivation: it is a draw stable enough to look deterministic and unstable enough not to be
verifiable. Three concrete consequences:

- **no derivation diff is reviewable.** Every diff comes full of reordering, and the real change is
  hidden in the noise;
- **the regression T004 demands was impossible**, and nobody had noticed because nobody had run
  it;
- **the promise of ADR 0004 D4 was left unverified.** "The schema matches the derived model" is not
  checkable when the derived model depends on when it was generated.

It is worth noting what was **not** the problem: the defect did not produce a wrong schema. The
same table, with the same columns, came out described in another order. That is why it survived —
nobody compares two runs when today's looks right.

**How to apply.**

1. **Sort every iteration whose order reaches the output.** Sets and `glob` have no order; `sorted`
   costs nothing and is the difference between derivation and a draw;
2. **A reproducibility gate in CI**, not trust: the pipeline derives four ontologies twice and
   compares. It is the only way this does not come back;
3. **Regression over a generator's output requires a deterministic generator first.** When a
   comparison flags a change in everything, distrust the comparison before distrusting the change
   — and run the baseline twice against itself.

**Applied in**: Sprint 002 — T004. The baseline was redone with the `HEAD` code plus the
determinism fix and nothing else, and only then was the new rule compared: **only EO changed**, and
only by the new column.

### L18 — A criterion met is not a sufficient criterion {#l18--um-critério-atendido-não-é-um-critério-suficiente}

**What happened.** Check V9 of sprint 002 required zero people without an organization, and it is
the MVP's criterion SC-003a. The first run returned exactly that:

```text
pessoas sem organização alcançável: 0
```

Criterion met. And the platform was lying: the derived team of `ifesserra-lab`, an organization
with **5 members**, had received **72** people — the whole tenant. All three organizations started
showing all 72.

The defect only showed up when walking through the **next** criterion, SC-009, which requires
"exactly one derived team, and in it exactly the members who were missing". 72 is not 5.

**Why it happened.** `list_people_without_team/2` returned every person of the tenant outside that
organization's teams, and that is a different thing from "a member of the organization outside its
teams". The definition of "of an organization" had never been written, and without it the function
answered the wrong question in the right shape.

What made the error invisible is that **it met the criterion with room to spare**: the more people
in the derived team, the more guaranteed V9's zero.

**Why it matters.** An acceptance criterion checks a claim, not the system. V9 claims "nobody
without an organization", and the derived team taking in the whole world makes that true by the
worst possible route. Only reading the criteria together — which walking through them one by one
forces — exposed the contradiction.

An acceptance record that settled for V9 would have accepted the deliverable, with evidence, in
good faith, and wrongly.

**How to apply.**

1. **Never accept on one criterion.** Walking through all of them is not a process formality: it is
   the mechanism by which one criterion corrects the reading of another;
2. **Distrust the criterion that passes with room to spare.** Absolute zero, 100%, "no cases left"
   — when a limit is reached with margin, ask what excess produced it;
3. **A count criterion needs the composition criterion beside it.** "Nobody outside" and "exactly
   these inside" answer different things, and only together do they describe the result;
4. **A missing definition is a defect, not a matter of style.** "Of an organization" looked
   obvious, and the function implemented something else. Where a domain term appears in the
   signature, it has to be defined in the function's documentation.

**Applied in**: Sprint 002 — the evaluation of D01 found the defect before acceptance, and the fix
is recorded in `aceitacao.md`.

### L19 — Marking absence by tenant marks what belongs to another organization {#l19--marcar-ausência-por-tenant-marca-o-que-é-de-outra-organização}

**What happened.** The demo of feature 003 showed `Paulo` with a single organization in force —
`leds-conectafapes` — when `The-Band-Solution` is also still being observed. And `EduardoNFraiz`
showed up with **none** in force, while being in two active organizations.

Neither had been marked by ending the observation. What was marked were the **team memberships**,
and the mark had come from before:

```text
organização        vínculos  marcados  primeira marca
The-Band-Solution         7         7  2026-08-10 00:44:30
leds-conectafapes        70        55  2026-08-10 00:44:30
ifesserra-lab             5         5  2026-08-10 23:21:59   ← the ending
```

The first two at the **same instant**, long before feature 003 existed.

**Why it happened.** `mark_evidence_no_longer_observed/2` is called at the end of each collection
to mark what did not appear in it, and it filters by **tenant**:

```elixir
where: e.tenant_id == ^tenant_id and e.last_observed_at < ^collection_started_at
```

No organization scope. So collecting `The-Band-Solution` marks the team memberships of
`leds-conectafapes`, because they did not appear in *that* collection — and would not appear,
because they belong to another organization.

**Why it matters.** It is a defect of feature 001, and the semantics it breaks is the most central
in the project: the mark means "the source stopped showing it", and came to mean "the last
collection was not of this organization". Every query that asks only for what is in force returns
less than the platform observes — which is exactly what the demo showed.

**It was not fixed in feature 003, on purpose.** Patching it there would have mixed the fix of an
old defect with the delivery of a feature, and it is the same reason the `connected_tools.status`
debt was not touched either.

**What makes the lesson bigger than the defect.** Feature 002 gave the platform exactly the
vocabulary missing here — `organization_id` on the team, and the path person → team →
organization. It fixed the model and **did not revisit who already used the old semantics**.
Adding the ability to scope scopes nothing by itself.

**How to apply.**

1. **A feature that adds a dimension must look for who decides without it.** When introducing
   scope by organization, the next question is "which queries and writes decide by tenant today and
   should decide by organization?";
2. **An absence mark needs the scope of the observation that produced it.** "Did not appear" only
   means something relative to what was looked at;
3. **Demonstrating on real data finds what the test does not.** The 151 tests pass: each one builds
   its own scenario, and in a one-organization scenario the missing scope is invisible. The defect
   needs two organizations and two collections in a row — which is what the development database
   has and the test did not.

**Fixed in sprint 003.** `mark_evidence_no_longer_observed/3` now requires the organization, and
the collection returns **which organization it observed** instead of only saying it finished. Four
tests fail when the scope is removed, including one whose message says why: *"collecting alpha
marked beta's team membership — it's L19 coming back"* *(original: "coletar alfa marcou o vínculo
de beta — é a L19 de volta")*.

**The historical data is still wrong, and the fix does not repair it.** The change applies to
future collections; the team memberships marked before stay marked. They were not unmarked, by
decision: nobody knows what the source showed at that instant, and unmarking on our own would
assert an observation that did not happen — exactly the error that L19 is.

The repair happens by itself at the next real collection of each organization: re-observing a team
membership clears the mark. Until then, queries by what is in force return less than the platform
observes, and the record says so.

**The demonstration on the database was weak, and it is honest to say so.** When simulating a
collection of `leds-conectafapes`, the team memberships of `The-Band-Solution` stayed intact — but
it already had **zero** team memberships in force, because of the defect itself. "0 before, 0
after" is intact at zero, and proves little. The strong proof is in the tests, with two
organizations built from scratch.

### L20 — State derived from the "latest" needs a deterministic tie-breaker {#l20--estado-derivado-do-último-precisa-de-desempate-determinístico}

**What happened.** While implementing resume, the test "reuses the existing tool" failed saying the
observation was still ended after being resumed. The two events — `ended` and `resumed` — had been
written in the **same second**, and the state derivation asks for the latest event by
`occurred_at desc, inserted_at desc`. With both columns in `timestamp(0)`, the tie was total, and
the database returned either of the two.

**It had already happened, under another name.** In sprint 001, `active_credential/1` picked the
most recently validated credential, and two registered in the same second tied on `validated_at` —
the same database state picked different credentials between runs. The fix there was to add a
tie-breaker; the fix here is the same idea with another mechanism.

**Why it recurred.** Because the earlier lesson was recorded as being about **credentials**, and not
about **deriving state from an ordered set**. The pattern is the same every time the code asks
"which is the latest": if the sort key has a coarser granularity than the write frequency, the
"latest" is undefined.

And the granularity that fools you is precisely the second, because it looks fine enough. Two
interface actions are seconds apart; two in a test, microseconds.

**The fix.** `occurred_at` stays in seconds — it is when the thing **occurred**, and a second is
enough. `inserted_at` moved to microseconds: it is the write order, and it is what breaks the tie.
Separating the two roles is what makes the order defined without faking a precision the event does
not have.

**How to apply.**

1. **Every derivation of "the latest" declares its tie-breaker.** If the answer changes with the
   execution plan, it is not a derivation;
2. **A second is not a tie-breaker.** Where a write can happen more than once per second — and it
   almost always can —, the order needs a column with finer resolution, or a sequence;
3. **When recording a lesson about a case, ask what class it belongs to.** "Tied credential" locked
   down the case; "derived state without a tie-breaker" would have locked down the class, and this
   lesson would not exist.

**Applied in**: Sprint 003 — the observation events table.

---

## L21 — A tested public function with no consumer is not delivered functionality {#l21--função-pública-testada-e-sem-consumidor-não-é-funcionalidade-entregue}

**Where**: Sprint 003, feature 003 — `resume_observation/3`.

**What happened.** Resuming the observation was specified (US2, four acceptance scenarios),
implemented and covered by six green tests. The maintainer asked to "specify the option to
reactivate the observation" *(original: "especifique a opção de reativar a observação")*, and the
check showed the specification already existed. What did not exist was the **button**: the
LiveView had zero occurrences of `resume_observation`.

Ending was possible through the interface. Resuming, only through the console — and an ending that
is irreversible in practice makes people not end, which is exactly what US2 itself says in the
justification of its priority.

**Why it got through.** Because each gate measured what it knows how to measure, and none measures
reach:

| Gate | What it said | What it did not say |
|---|---|---|
| `mix test` | 161 green | nobody can call the function |
| task coverage | T023 to T025 done | the tasks were domain tasks |
| `sprint-review.md` | F4 delivered | delivered **to whom** |

The `sprint-backlog` declared F4 as "US2 — resume", and the phase ended when the domain ended. The
vertical slice exists precisely to prevent this, and the rule was written: *never infrastructure
without a visible consumer*. It was followed in F3 — the ending screen came along — and not in F4.

**What exercising through the screen found, and the tests did not.** Two defects, both because the
domain tests always passed complete attributes:

- label `""` did not get the default, because the default only applied to an **absent** field;
- an invalid changeset turned into a `MatchError` inside the transaction, killing the LiveView
  instead of responding.

Neither is subtle. Both needed a form to show up.

**How to apply.**

1. **A user story phase only closes with a consumer.** If the US describes someone doing something,
   the phase does not end while that someone cannot do it;
2. **Before declaring a phase done, look for the function in the interface layer.** A `grep` for
   the public function's name costs seconds and answers "delivered to whom";
3. **When reading a request that already looks fulfilled, check the whole path.** "It is already
   specified and implemented" was true and hid the gap. The useful question is not "does it
   exist?", it is "who can use it?".

**Applied in**: Sprint 003 — resume button, form and observation history.


---

## L22 — A gate that only compares two runs cannot tell whether either one worked {#l22--gate-que-só-compara-duas-execuções-não-sabe-dizer-se-alguma-funcionou}

**Where**: Sprint 003 — the gate "information model — reproducible derivation".

**What happened.** The gate was born in the fix for [L17](#l17--a-derivação-do-esquema-não-era-função-da-ontologia), to prove that the
derivation is deterministic. It runs the script twice and compares the outputs:

```bash
for o in eo sro cmpo spo; do
  python scripts/derive_information_model.py --ontology "$o" > /tmp/d1-$o.txt
  python scripts/derive_information_model.py --ontology "$o" > /tmp/d2-$o.txt
  diff "/tmp/d1-$o.txt" "/tmp/d2-$o.txt" || { echo "não é reproduzível"; exit 1; }
done
```

The SRO derivation **fails**, because 43 concepts do not declare `ontouml_stereotype` — and it fails
the same way in both runs. The `diff` passes. What failed the step was `bash -e` stopping on the
script's exit code, and the message the gate prints never appeared: whoever read the log would see
an unexplained error, in the middle of a step called "reproducible".

**And I reported the gate as green twice**, in the reviews of sprints 002 and 003. I checked that
the two outputs were equal and did not check whether either of them was a derivation. `main` had
been red since PR #93.

**What the gate was hiding.** Annotating SRO and deriving again showed a defect that existed before
it: the ADR 0004 D5 guard — `role` materializes through a relator, never through a discriminator —
was only applied when the lifting target was in the same ontology. **CMPO and SPO already produced
the violation**, visible in the output, green in CI:

```
spo.artifact.type += {configuration_item}
ufo.agent.type    += {change_implementer}
eo.person.type    += {project_person_stakeholder}
```

A people table asserting that someone **is** a Product Owner. The gate read that output twice,
found both equal, and said everything was fine.

**How to apply.**

1. **Every differential gate needs a success gate before it.** Comparing two runs only means
   something after knowing that one run is valid. `set -o pipefail`, check the exit code, and fail
   with the gate's message — not with the shell's `-e`;
2. **Read the green step's log once.** What the derivation prints is the information model; nobody
   read it, and it stated the violation out loud;
3. **Reporting a gate as green requires having seen the green.** I carried forward a claim from an
   earlier review. A repeated claim does not become a verification.

**Applied in**: Sprint 003 — the 43 SRO stereotypes and the `role` guard for a kind from another
ontology.


---

## L23 — A skipped-check warning is a failure, not a note {#l23--aviso-de-verificação-pulada-é-reprovação-não-observação}

**Where**: feature 004, while writing the mappings.

**What happened.** The Python validator prints, when the schema library is missing:

```text
[schema] jsonschema não instalado — validação de forma NÃO executada
         (pip install -r scripts/requirements.txt)
```

I read that in **every** run of this session — there were more than ten — and treated it as an
environment note. It is not: the line is recorded as `fail`, the validator counts "1 problema(s)"
and **exits non-zero**. I ran it with `| tail -2`, which swallows the exit code, and concluded
"passed" every time.

CI, which installs the dependency, failed six mappings on shape errors — `source_path: null` where
the schema requires a string. Errors that had been there since the first file I wrote.

**The relation to L22.** It is the same defect, and it recurred **two days** after I recorded it.
There, the derivation gate compared two runs that failed the same way and I did not check the exit
code. Here, the validator said it had not validated and I did not check the exit code.

L22 was recorded as being about a **differential gate**. The pattern is bigger: **any check whose
result I read from text, and not from the exit code**.

**What fixing the error taught along the way.** `source_path: null` was not only invalid against the
schema — it was wrong in content. Declaring an attribute pointing to nothing asserts "there is a
mapping, and it maps to nothing". The absence of a mapping is represented by **omitting the
attribute**, and the limitation names the why. The same rule the constitution already gives for
data: absence is null, never zero.

**How to apply.**

1. **Never `| tail` on a gate.** Run it, look at the exit code, and only then summarize.
   `cmd && echo OK || echo FALHOU` costs nothing;
2. **A check that declares itself skipped is a failure.** "Not run" and "run and passed" cannot
   produce the same reaction in the reader;
3. **Environment parity is part of the gate.** If CI validates more than the local machine, local
   gives a false green. The `README` now tells you to create the venv first, with the reason
   written.

**Applied in**: feature 004 — six mappings fixed, and the venv documented.


---

## L24 — A path that only runs in a clean environment is not tested by whoever already has the environment {#l24--caminho-que-só-roda-no-ambiente-limpo-não-é-testado-por-quem-já-tem-o-ambiente}

**Where**: feature 004, while creating `mix gates`.

**What happened.** The task provisions `.venv` on the first run. I ran `mix gates` nine times
locally, all nine gates green every time, and CI failed:

```text
── 8/9 validador Python
   criando .venv (uma vez)
** (ErlangError) Erlang error: :enoent
    System.cmd(".venv/bin/pip", ["install", ...])
```

`System.cmd` does not resolve a relative path. I already knew that — I had fixed exactly that for
`python` in the same function, minutes earlier — and did not fix it for `pip` right next to it.

**Why it passed nine times.** Because `.venv` **already existed** on my machine, since August.
`ensure_venv` found the interpreter and returned the path without ever entering the creation
branch. The code that failed was the only code I did not run, and it was the only code CI always
runs.

**What closed it.** I moved `.venv` out of the way and ran again. The creation branch ran, failed
where CI failed, and the fix could be verified:

```bash
mv .venv /tmp/venv-guardado
mix gates --from "validador Python"
```

And the fix itself is better than fixing the path: `python -m pip` instead of the `pip` executable
leaves **one** path to expand instead of two, and it is the venv's own interpreter that resolves the
module.

**How to apply.**

1. **Every provisioning branch has to be exercised without the resource.** `mv` the directory,
   `docker rm` the volume, `unset` the variable — the cost is one line, and it is the only way to
   run the path CI runs;
2. **A dirty environment hides the clean environment's branch.** Nine green runs say nothing about
   the tenth on a new machine, and a new machine is what CI is;
3. **Fixing one occurrence of a defect does not fix its neighbors.** Two calls with the same
   problem were five lines apart. When fixing, look for the pattern in the whole file before moving
   on.

**Relation to L23**: L23 was about **verification** parity — CI validated more than local. This one
is about **environment** parity — CI starts from a clean machine and local does not. Both produce a
false green, by different paths.

**Applied in**: `mix gates` — `python -m pip`, and the creation branch exercised with the venv
removed.

---

## L25 — An issue number does not identify: it is unique within the repository {#l25--número-da-issue-não-identifica-ele-é-único-dentro-do-repositório}

**Where**: Sprint 004 — linking sub-issues to their parent, in the collection.

**What happened.** The `collected_issues` table already carried the rule in its unique index: the
identity is the Application Reference, and `number` is left out of it, with the reason written in
the migration.

And I linked the parts to the parent by **number**:

```elixir
por_externo = Map.new(WorkItems.list_issues(ctx.tenant), &{&1.number, &1.id})
pai_id = por_externo[node["number"]]
```

The organization has 135 repositories. Several have an issue `#1`. `Map.new` kept the last one for
each number, and parts from one repository were linked to the parent of another.

**The effect was silent.** No error, no exception, no red test: the classification came out wrong.
The screen showed **2 epics** where there were 3, and issue `#1` — with 39 parts — appeared as an
atomic user story.

**Why it got through.** Because the routing test calls `decide/2` with the list of the parts' types
**already assembled**, and the assembly is precisely what was wrong. The defect lived between two
pieces that each test exercised separately.

What found it was looking at the screen with real data and noticing a number that did not match
what the API said.

**The fix.** Key by `external_id`, which is global:

```elixir
por_externo = Map.new(WorkItems.list_by_external_id(ctx.tenant), &{&1.external_id, &1.id})
```

**How to apply.**

1. **Where the identity is declared, use it.** The unique index of `collected_issues` already said
   which the key was; I wrote another one next to it;
2. **A key that "works in my test" is usually a key of a single scope.** A fixture with one
   repository does not distinguish a number from an identifier — real data with 135 does;
3. **`Map.new` over a non-unique key loses data silently.** It does not warn on collision: it keeps
   one and discards the rest. Where uniqueness is not guaranteed, `Enum.group_by` shows the problem
   instead of hiding it.

**Applied in**: Sprint 004 — `vincular/2`, and the epic count went from 2 to 3.

---

## L26 — Matching the wrong envelope returns an empty list instead of an error {#l26--casar-o-envelope-errado-devolve-lista-vazia-em-vez-de-erro}

**Where**: Sprint 004 — first run of the repository collection against the real source.

**What happened.** `Client.graphql/4` returns `{:ok, %{data: ..., rate_limit: ...}}` — an envelope. I
matched `{:ok, data}` and passed the envelope to the function that extracts the nodes:

```elixir
{:ok, data} -> {nodes, page_info} = extrair(data, query_name)
```

`extrair` does `get_in(data, ["organization", "repositories"])`. On an envelope with keys `:data`
and `:rate_limit`, that returns `nil`, which the code treats as `[]`.

**Result: the job completed successfully and collected zero.** `status: completed`, no error
recorded, no payload written. The screen showed "0 issues collected" and the plausible explanation
was "the organization has no repositories".

**Why it compiled and passed.** `{:ok, data}` matches any `{:ok, _}`. Dialyzer does not complain
because `get_in/2` accepts a map and legitimately returns `nil`. And the tests used the HTTP-edge
Mox with a payload already in the internal format — they never exercised the real envelope.

**The relation to L22 and L23.** It is the same family: **silent success**. There a gate compared
two runs that failed the same way; here a job completes without doing anything. In all three, the
absence of an error was read as the presence of a result.

**How to apply.**

1. **Broad pattern matching hides a change of shape.** `{:ok, %{data: data}}` fails loudly when the
   shape changes; `{:ok, data}` carries on with whatever comes;
2. **A collection that returns zero has to be distinguishable from a collection that did not
   look.** The `sync` report now counts by `sync_id`, and zero with 14 repositories observed is
   different from zero with none;
3. **A test with Mox in the internal format does not validate the boundary.** The payload captured
   from the source has to go through the whole client, envelope included, at least once.

**Applied in**: Sprint 004 — the collection went from 0 to 14 repositories and 189 issues in the
first organization.

---

## L27 — Implementing before the plan makes the test discover what the plan would have discovered {#l27--implementar-antes-do-plano-faz-o-teste-descobrir-o-que-o-plano-descobriria}

**Where**: Sprint 005 — feature 006, issue detail.

**What happened.** The spec and the API contract existed; the request was direct — *"when I click
the repository title and the issue title I want to see the details"* *(original: "ao clicar no
titulo do repositorio e da issue quero ver os detalhes")* —, and I implemented from the contract,
without `plan.md`, `research.md` or `tasks.md`.

The code came out well: nine green gates, 29 new tests, the axiom with a single path. But **two
design decisions were only examined when a test failed them**:

1. I displayed `partes declaradas: 39` in the epic panel, next to 9 in composition and 30 in
   fulfillment. SC-004's `refute html =~ ">39<"` failed, and it was right: 39 is exactly the sum, and
   a reader would conclude that the two sections count the same thing twice;
2. the test comparing the axiom's two paths used `for issue <- ..., pai = fetch_parent(...)` — and in
   a comprehension an expression that is not a generator acts as a **filter by its value**.
   `pai = nil` discarded precisely the task without a parent, which is one of the two cases being
   compared. The test agreed by not looking.

**Why it happened.** Both are design questions, not code questions: *what does the screen show next
to the two relations?* and *how do you prove the two paths agree?* They are exactly the questions
`research.md` forces you to answer along with what was rejected, and that the tasks phase forces you
to write as a *Test* before any implementation exists.

Without the plan, they became late discoveries — and the first one was only caught because SC-004
was written in the spec with the forbidden number. Had the spec said only "show the decomposition",
the sum would have passed.

**What to do differently.** When the request arrives direct and the temptation is to implement,
writing **just the `research.md`** already pays off: it holds the design questions, with what was
rejected alongside. `plan.md`, `data-model.md` and `tasks.md` can come with the code at no comparable
cost — but design decisions examined after the code have already been made, and all that is left is
to justify them.

And the corollary that holds for every spec: **write down the forbidden number**. "Show 9 and 30,
never 39" is verifiable; "show the decomposition separately" is not.

**Status**: open. **Type**: process. **Apply in**: sprint 005, feature 005 — whose full cycle was
written before any line of code, and is the first check of this lesson.

---

## L28 — Computing and not writing is worse than not computing {#l28--calcular-e-não-gravar-é-pior-que-não-calcular}

**Where**: Sprint 005 — first run of the recomputation on real data.

**What happened.** The decision computed the divergence between the label and the structure, with
sentence and type, for 488 issues. The database had **zero**.

`mudou_registro?/2` — the function that decides whether a new row is worth writing — compared
concept, gap reason, rule and evidence source. **It did not compare the divergence.** An issue whose
concept did not change never received the divergence discovered later.

**Why it happened.** The function was born before the structural divergence existed, and nobody went
back to it when the new field came in. The test I wrote checked that the decision *computes* the
divergence — and it passed, because it really does compute it.

**Why it is worse than not computing.** An absent feature is visibly absent. This one showed **zero
divergences** on a screen designed to display them, and whoever read it would conclude that no issue
diverges. The product claimed the opposite of what it knew.

**What to do differently.** When a new field enters a structure that is already compared somewhere,
**look for the comparison**. A `grep` for the names of the neighboring fields finds it in seconds:
if `evidence_source` is compared and the new field is not, it is a defect.

And the test has to go all the way to the database. "The decision computes X" and "X is written" are
different claims, and only the second is what the screen reads.

**Status**: open. **Type**: technical.

---

## L29 — A transient failure that marks permanent state takes data out of circulation silently {#l29--falha-transitória-que-marca-estado-permanente-tira-dado-de-circulação-em-silêncio}

**Where**: Sprint 005 — checking the issue count against the source.

**What happened.** The GitHub API says `leds-conectafapes` has 4282 issues. The collection saw 3383.
The difference — **899 issues** — was in **38 repositories marked as inaccessible** because of a
`:nxdomain`, a momentary DNS failure.

The mark was permanent in practice: `list_collectable/2` excludes inaccessible ones, and nothing
cleared it. The 38 dropped out of **every** later collection, and the screen said "completed ·
100%".

**Why it happened.** `mark_inaccessible/3` was called for any error. The distinction between a
failure that repeats — revoked credential, deleted repository — and a failure of the moment existed
in the code (`Client.transient?/1`, used to decide retries) and **was not consulted here**.

**Why it went unnoticed.** The collection finished successfully, the percentage closed at 100%, and
the denominator also came only from the accessible repositories. **The number was consistent with
itself and wrong.**

**What to do differently.** Before marking state that takes something out of circulation, ask:
*does this heal by itself?* If so, do not mark — and if you do mark, mark **who clears it**. The cure
here is the collection itself: reached it, clears it.

And: a percentage computed over what the platform decided to look at never detects what it stopped
looking at.

**Status**: open. **Type**: technical.

---

## L30 — Checking the number against the source finds what the suite does not {#l30--conferir-o-número-contra-a-origem-acha-o-que-a-suíte-não-acha}

**Where**: Sprint 005 — the two lessons above, and the empty body of feature 006.

**What happened.** Three defects in two days, all with the suite green:

| defect | how it showed up |
|---|---|
| 480 issues with a `NULL` body | the source returns `""`; `cast/4` discards an empty string |
| 899 issues out of collection | sum of the source's `totalCount` against what the collection saw |
| 488 divergences not written | the decision computed them and the database did not have them |

None had a test that failed, because **all three were about data the test scenario does not
produce**: empty body, inaccessible repository, issue whose concept does not change.

**Why it happened.** The test scenario is built from what is expected. Real data has what nobody
expected — and that is exactly where the defect lives.

**What to do differently.** When delivering anything that counts, **measure against the source
once**. It is not an audit: it is one query. `search(query: "org:x is:issue")` and the sum of
`issues.totalCount` took two minutes and found 899 lost issues.

When the two numbers diverge, **explain the difference all the way**. "Probably issues created
afterwards" is a hypothesis, not an explanation — and in this sprint that hypothesis was wrong.

**Status**: open. **Type**: process.

---

## L31 — A new rule changes the meaning of a test that used to pass {#l31--regra-nova-muda-o-significado-de-teste-que-passava}

**Where**: Sprint 005 — classification by structure.

**What happened.** The structural rule started classifying every issue. Two preview tests broke, and
**neither of them was wrong**: they measured "how many issues would change concept", comparing with
what was written. With the structure deciding anyway, that comparison started attributing to the
rule what the structure would do on its own.

The fix was neither in the test nor in the rule: it was in the **meaning**. `would_change` now
measures the effect *of the rule* — with it versus without it — and a new number, `rows_to_write`,
now measures what the write produces.

**Why it matters.** A test that breaks after a new rule is an invitation to "adjust the expected
value". Doing that here would have kept the test green and the preview lying: it would say a
harmless rule changes 3451 issues.

**What to do differently.** When a correct test breaks because of a new rule, ask **what the
assertion meant** before changing the number. If the question it asked stopped making sense, the
answer is a new question — not a new value.

**Status**: open. **Type**: process.

---

## L32 — Text that asserts what the platform did not observe is the same defect, in the opposite direction {#l32--texto-que-afirma-o-que-a-plataforma-não-observou-é-o-mesmo-defeito-na-direção-oposta}

**Where**: Sprint 006 — the work mark on the repository.

**What happened.** The feature exists to prevent absence from showing up as zero. The third state of
the mark — "unknown" — got the text `not collected yet`, and it **asserts** that the collection did
not happen.

Measured in the database after the migration: **94 repositories with a null `issues_collected_at`,
and the collection visited 61 of them** and found nothing. `nil` means absence of a **record**, not
absence of collection. The screen would be asserting about 61 repositories something the platform
did not observe.

**Why it happened.** All the design attention went in one direction — not letting absence look like
a quantity — and the phrase chosen to name the absence asserted a fact in the opposite direction.
`no collection recorded` names what exists: the absence of the record.

**Why it nearly slipped through.** No test would fail: the text is different from the empty-state
text, which is what the tests required. The missing distinction was not between two texts, it was
between **what the text asserts** and what the platform holds as observed.

**What to do differently.** For every phrase the interface displays about absence, ask: *does this
assert a fact, and did the platform observe that fact?* "Not collected" asserts; "no collection
recorded" describes what exists. The difference is the same one that separates `declared_type` from
`structure` in the evidence.

**Status**: open. **Type**: technical.

---

## L33 — The question that catches the migration defect is "what does the screen say the next day" {#l33--a-pergunta-que-pega-o-defeito-de-migração-é-o-que-a-tela-diz-no-dia-seguinte}

**Where**: Sprint 006 — finding A1 of the analysis, before any code existed.

**What happened.** The mark decided by the collection date before the count. Each piece worked: the
query counted right, the column wrote right, the screen read both. And the result, at the instant
right after the migration, would be the platform saying `no collection recorded` about **41
repositories** it has collected issues for — one of them with 2514.

No unit test has that instant as a scenario: the test scenario creates the date because the test
needs it.

**Why it happened.** A migration that adds a nullable column leaves **every** existing row null, and
the new code is written looking at the state it will produce — not the state it will find.

**What to do differently.** When adding a column the interface reads, ask before writing the read:
*how many existing rows will have `nil`, and what will the screen say about them?* If the answer is
a false claim about part of the data, the decision order is wrong — and the test that proves it is
the one that provides data without the column filled.

It was `/speckit-analyze` that asked the question, and it is the concrete argument for the phase to
exist: it examines the design against the state of the world, not against the test scenario.

**Status**: open. **Type**: process.

---

## L34 — The same word for two different things hides the case the feature exists to solve {#l34--a-mesma-palavra-para-duas-coisas-diferentes-esconde-o-caso-que-a-feature-existe-para-resolver}

**Where**: Sprint 007 — the feature for unblocking a stuck sync.

**What happened.** The design had **one** notion of "live work": any job in a non-terminal state. The
implementation passed the tests, and was wrong.

The orphan job measured in the database has been `executing` since 2026-08-09, on a node that no
longer exists. With a single notion, `executing` blocked the automatic ending **and** the human one —
and the feature left stuck exactly the case that motivated it. The two runs that required SQL were
that case.

**Why it happened.** "Live" looked like one question; it was two. *Can the platform end it on its
own?* and *can the person end it?* have different answers for `executing`, because the platform
cannot tell a running collection from a dead process — and the person who restarted the application
can.

**Why the tests did not catch it.** They measured what the design said. The "do not end a live
collection" test passed with `executing`, and no test asked *"and the orphan, who ends it?"* —
because the design had answered "nobody" without saying so.

**What to do differently.** When a condition appears at **two** decision points — here, the
automatic trigger and the human action —, ask whether it means the same thing at both. If the answer
for some state diverges, they are two conditions, and using only one erases a case.

The warning sign is the generic name: "active", "valid", "ready". A generic name usually covers two
questions nobody separated.

**Status**: open. **Type**: technical.

---

## L35 — Checking against the source finds defects outside the feature being delivered {#l35--conferir-contra-a-origem-acha-defeito-fora-da-feature-que-se-está-entregando}

> **Merged into L30 in Sprint 028** — it is not a new lesson: it is L30 saying that **adding up the total is not enough** — the comparison is item by item.

**Where**: Sprint 007 — the maintainer found the issue count low and asked for a check.

**What happened.** The check confirmed that the collection is almost complete — **4283 at the
source, 4280 in the database**, and the 3 missing were created after the last collection. Nothing is
filtered by state or by archiving.

And it found **two defects nobody was looking for**:

| defect | cost |
|---|---|
| the inaccessible mark does not heal: the marked repository is filtered out **before** the collection, and the function that would clear the mark never reaches it | 39 repositories and **899 issues** out of every future collection |
| a GitHub **internal** error — HTTP 200 with `errors` — is classified as a permanent failure | it created a new mark the same day |

The first is **L29 revisited**, and it is the one that matters most: the L29 fix prevented new marks
from transient failures and did not reach the ones that already existed — because the declared cure,
*"the cure is the collection itself"*, assumes the collection **tries**. It does not try: the
inaccessible one is filtered out beforehand.

**Why it went unnoticed for two sprints.** The total in the database is 3 issues away from the
source's total. **The aggregate number is right, and the mechanism is broken** — the loss is
everything created from now on in those 39 repositories, and today it is almost zero.

**What to do differently.** Checking against the source **is not just adding up the total**. The sum
matched here and would have hidden the defect forever. What found it was comparing **repository by
repository**, and then asking *why is this one marked, and what would clear the mark?*

And the corollary: when a lesson declares a cure — "the cure is the collection itself" —, check that
the cure's path is **reachable**. A cure that assumes a step the filter prevents is not a cure.

**Status**: open. **Type**: process.

---

## L36 — A gate that discards the task's return value is not a gate {#l36--gate-que-descarta-o-retorno-da-task-não-é-gate}

**Where**: Sprint 008 — and the first version of this lesson was **wrong** about the mechanism. The
correction is recorded below, because the error is instructive.

**What happened.** An orphan `@doc` got into `main` with **all ten gates green** and CI green.

**The mechanism, isolated by experiment:**

```
$ mix gates            # with the defect present
   código de saída: 0
   warning: redefining @doc attribute previously set at line 419   ← printed three times
── 1/10 format
── 2/10 compile
```

The warning **is emitted**. The gate **prints** the warning and exits **zero**.

The cause is in the gates' own definition:

```elixir
defp execute({:mix, [task | args]}) do
  Mix.Task.reenable(task)
  Mix.Task.run(task, args)      # ← the return value is DISCARDED
  :ok
rescue
  e in Mix.Error -> {:error, Exception.message(e)}
end
```

`mix compile --warnings-as-errors` **does not raise**: it returns `{:error, diagnostics}`. Since the
return value was discarded and nothing was raised, the gate reported `:ok`. **The compile gate never
failed on a warning** — neither locally nor in CI, because CI runs the same task.

**What I had written, and why it was wrong.** The first version of this lesson said that incremental
compilation did not emit warnings for files not recompiled, and that the `_build` cache in CI
reproduced the blindness. **Two claims, neither verified.** The experiment that would test them — and
that I ran afterwards — shows the opposite: Elixir **re-emits** cached diagnostics, and
`mix compile --warnings-as-errors` in its own process fails even without recompiling anything.

I had two true measurements — `main` failing on a clean tree, and the gates passing — and **invented
the link between them** instead of isolating it. The right conclusion needed one more experiment.

**What to do differently, and it is two things.**

First, in the code: **a gate's verdict is the exit code**, and that is why each gate now runs in a
subprocess. It is L22 applied to the gates' own definition — it said that checking a gate by text
(`| tail`) does not count, and the same goes for checking by a discarded return value.

Second, in the method: **when two true measurements seem to contradict each other, the link between
them is a hypothesis, not a conclusion.** Publishing the hypothesis as the cause was the error, and
it cost a wrong lesson in the record the next sprint will read.

**Measured cost of the fix**: full `mix gates` in **78.6 s**, with each gate starting its own VM.

**Status**: open. **Type**: process.

---

## L37 — The narrow column only breaks when writes become frequent {#l37--a-coluna-estreita-só-cai-quando-a-escrita-fica-frequente}

**Where**: Sprint 008 — finding from the analysis, before the code.

**What happened.** `inaccessible_reason` is `varchar(255)`. The longest reason written had **181**
characters, and the reason for the source's internal failure — with the prefix the platform adds —
comes to **~228**. Twenty-seven characters of slack, in a text the source controls and that carries
an incident identifier of variable length.

Without `validate_length` in the changeset, the long value goes to the database and **raises**. And
the collection's error handling covers an invalid changeset, not a driver exception: the stage would
crash, and the error in the log would be the database's instead of the source's.

**Why nobody had seen it.** The column was written **once per repository**, and only when it failed
permanently. Thirty-nine writes in two days, all below the limit. Feature 009 changed that: with the
collection retrying on every run, the field is now written **on every collection that fails**.

**The pattern, and it is what matters:** a narrow limit does not break for being narrow — it breaks
when the **write frequency** rises. The feature did not introduce the defect; it changed the
exposure to it.

**What to do differently.** When changing how often a field is written, check its limit. And, for a
**diagnostic** field, have no limit: truncation belongs at the edge, where the message is built, not
in the column width. That is what L05 had already concluded, and what this lesson adds is **when**
the debt comes due.

**Status**: open. **Type**: technical.

---

## L38 — The cost of a screen is measured by the difference and the constancy, never by the total {#l38--o-custo-de-uma-tela-se-mede-pela-diferença-e-pela-constância-nunca-pelo-total}

**Origin**: Sprint 009 · **Type**: technical

**What happened.** Feature 010's plan declared eight queries for the person page, and the test
asserted eight. It failed: the page makes **24**. Neither measurement was wrong — 16 are framework
and authentication, across **two** renders of `live/2`.

**Why it happened.** "How many queries the page makes" and "how many queries the page **adds**" are
different questions, and the plan answered the second while the test measured the first.

**What to do differently.** Two assertions, and both have to exist:

1. the **difference** against a baseline screen, divided by the number of renders;
2. the **constancy**: a page with little data and one with a lot measure **the same**.

The second is the one that catches the real defect — a query per row —, and the first is the one
that keeps the number from growing without a decision. **"A number that does not grow" is not an
assertion**: it passes with 8 and passes with 80.

**Applied in**: Sprint 010 — and there it bit twice. The cost test compared the same page with itself
(**L41**), and a late telemetry message got into the next count (**L42**).

**Applied in**: Sprint 023 — and this time it DEFENDED: the guard failed the new access verdict (+5
queries per render on the person page) before any slow screen existed. The fix went back under the
ceiling without raising the yardstick: the person themselves is decided in memory, the target side
is only read when there is a scope with a target, and grant names cost zero when there is no grant.

**Status**: open.

---

## L39 — A `join` in a shared scope shifts the bindings of whoever composes on top of it {#l39--um-join-num-escopo-compartilhado-desloca-os-bindings-de-quem-compõe-sobre-ele}

**Origin**: Sprint 009 · **Type**: technical

**What happened.** `escopo/2` in `WorkItems.Queries` gained a filter by person, written as a `join` on
`issue_assignees`. `list_issues/2` composes on top of that scope with its own `join` and a `select` by
**position** — `[i, p]`. The binding `p`, which was the promotion, became the assignment.

```
field derived_concept in select does not exist in schema IssueAssignee
```

**Why it happened.** A positional `select` ties the code to the **order** of the joins, and a `join`
added upstream changes that order without touching whoever consumes it.

**What to do differently.** A filter in a shared function uses a **subquery**, not a `join`:

```elixir
where(query, [i], i.id in subquery(designadas))
```

A subquery does not create a binding, and so it shifts nothing. And when the `join` is unavoidable,
the `select` names the bindings instead of counting them.

**Applied in**: Sprint 010 — `list_parents/2` was born with a `select` naming the fields, and the
filter by repository is still a `where`.

**Status**: open.

---

## L40 — Two quantities with similar names, and the complement derived from the wrong one {#l40--duas-grandezas-com-nomes-parecidos-e-o-complemento-derivado-da-errada}

**Origin**: Sprint 010 · **Type**: process

**What happened.** Feature 011's spec opened with the measurement: *"4,529 issues in force, **1,666
with a parent**, 2,863 without"*. All three were wrong together: **1,666 is the count of links**, the
issues with a parent are **1,630**, and those without a parent are **2,899**.

The error survived because the sum **added up**: 1,666 + 2,863 = 4,529. It added up because the
second number was **derived** from the first by subtraction, not measured.

**Why it happened.** The query counted rows of `decomposition_links`, and the sentence talked about
issues. The difference — **36** — was exactly the edge case the feature exists to handle: issues with
more than one parent.

**What to do differently.** Two rules, and the second is the one that catches this case:

1. **measure both sides**, never derive the complement by subtraction — the total matching does not
   prove the parts are right;
2. when two quantities relate by multiplicity — issue and link, person and assignment —, **measure
   both and check the difference**. If the difference is zero and should not be, or the reverse, the
   name of one of them is wrong.

**Applied in**: Sprint 010 — fixed before the plan, and the difference of 36 became a check.

**Status**: open.

---

## L41 — A test that compares a thing with itself always passes {#l41--teste-que-compara-uma-coisa-com-ela-mesma-passa-sempre}

**Origin**: Sprint 010 · **Type**: technical

**What happened.** The column's cost test asserted **constancy** like this:

```elixir
poucas = contar_consultas(fn -> abrir(ctx) end)
grande = repositorio_grande(ctx)          # returned the SAME repository
muitas = contar_consultas(fn -> live(ctx.conn, ~p"/work/repositories/#{grande}") end)
assert poucas == muitas
```

`repositorio_grande/1` returned `ctx.cenario.observed_repository_id` — the same page `abrir/1`
already opened. Equality was guaranteed, and the test passed **measuring nothing**.

**Why it happened.** The helper was written as a shortcut — "the big page already exists, it is the
scenario" — and its name, `repositorio_grande`, described the intent instead of what it did. Reading
the test afterwards gives the impression that two different pages were compared.

**What to do differently.** In an **invariance** test — constancy, idempotence, determinism —, check
that the two sides are in fact **different** before asserting that the result is equal. A cheap way:
if you swap the assertion for `refute` the test must **fail**. If it passes both ways, it does not
measure.

And the smell: a helper whose name promises variation and whose body returns a constant.

**Status**: open.

---

## L42 — A late telemetry message gets into the next count {#l42--mensagem-atrasada-de-telemetria-entra-na-contagem-seguinte}

**Origin**: Sprint 010 · **Type**: technical

**What happened.** Measuring the page's cost three times in a row — empty, small, big —, the third
measurement returned **22** queries on a page that makes **20**. The full trace, done afterwards,
showed 10 per render on both pages.

The counter attaches a handler for `[:the_band, :repo, :query]` that does `send` to the test process,
and then drains the mailbox with `after 0`. The two excess messages were from the **previous
measurement**, arriving after the `detach` had happened.

**Why it is worse than it looks.** I almost wrote an explanation for the 22 — a conditional query
that would only appear with more data. **Explaining an unstable number is L36 again**: the link
between two measurements is a hypothesis, not a conclusion. The difference is that here one of the
measurements simply was not a measurement.

**What to do differently.** A telemetry counter **empties the mailbox before attaching**, and the
number has to repeat across runs before any explanation. If it varies, the instrument is wrong — and
a wrong instrument is not interpreted.

**Status**: open.

---

## L43 — When the axiom answers the wrong question, the fix is the precondition, not a filter on the answer {#l43--quando-o-axioma-responde-a-pergunta-errada-a-correção-é-a-precondição-não-um-filtro-na-resposta}

**Origin**: Sprint 010 · **Type**: technical

**What happened.** The `part of` column has to say which relation the link is, and the violation
decision belongs to `Axioms.rule07/2` — reusing it is a requirement, so the column does not disagree
with the panel on the same screen.

But `rule07(tarefa, nil)` returns `{:violation, :task_without_parent}`: in `rule07/2`, `nil` in the
parent's concept means **has no parent**. Calling it for every row would fill **2,091 of the 2,899**
cells with a warning, drowning the **293** that are the interesting case — and the suite would pass,
because each piece works.

**Why it happened.** The same `nil` means two things: "has no parent" in the axiom, and "the parent
exists and was not promoted" in the column. It is **L34** — the same word for two things — showing
up in a value instead of a name.

**What to do differently.** Two things, and the second is the lesson:

1. handle the ambiguous `nil` **before** calling the axiom, in its own clause;
2. when the axiom's answer does not serve, **restrict the call**, do not filter the result. The new
   function declares the precondition — *there is a parent* — and the case outside it never reaches
   the axiom. Filtering the answer would be a second decision about the same fact, which is exactly
   what reusing the axiom existed to avoid.

**Status**: open.

---

## L44 — A sprint that closes without a review leaves the lesson in draft, and the next feature cites it as if it existed {#l44--sprint-que-fecha-sem-review-deixa-a-lição-rascunhada-e-a-próxima-feature-a-cita-como-se-existisse}

**Origin**: Sprint 009, found in Sprint 010 · **Type**: process

**What happened.** Sprint 009 was delivered and merged — PR #247, thirteen issues closed — **without
`sprint-review.md`, without `aceitacao.md` and without consolidated lessons**. Lessons **L38** and **L39** stayed
as drafts in the feature's commit message and never reached the cumulative record.

The absence only showed up when **sprint 010** cited them in its "lessons applied" table, as
constraints. They had in fact been applied — the named `select` and the measure by difference are in the
code —, but **they did not exist in the document that exists to be read when opening the sprint**.

**Why it happened.** The merge ends the feeling of completion. The three pieces of closing — sprint review,
acceptance, lessons — come **after** it, and nothing fails when they are omitted: the gates pass, the issues
close, the PR merges.

**It is the silent success pattern**, applied to the process instead of the code: absence of error read
as work done.

**What to do differently.** The sprint is only closed when the **three** documents exist, and the
check is mechanical:

```bash
ls docs/sprints/<n>-*/          # sprint-backlog.md and sprint-review.md
ls specs/<feature>/aceitacao.md # the acceptance, from sprint 006 on
```

**And acceptance lives in two places**, which delayed noticing the gap: up to sprint 005 it was in
`docs/sprints/<n>/aceitacao.md`, and from 006 on in `specs/<feature>/aceitacao.md`, next to the spec
it evaluates. Looking in only one place gives a false negative in both directions.

**Opening a new sprint checks the previous one** — and citing a lesson requires finding it in the file, not in
memory.

**Status**: open.

---

## L45 — A new sprint branched from `main` does not see the previous sprint's closing while the PR is open {#l45--sprint-novo-tirado-da-main-não-enxerga-o-fecho-do-sprint-anterior-enquanto-o-pr-está-aberto}

**Origin**: Sprint 011 · **Type**: process

**What happened.** The sprint 011 branch came off `main`, as always. And `main` did not have the
`sprint-review.md` of sprint 010, the acceptance of feature 011, the updated `RETOMAR.md`, nor
lessons **L38 to L44** — all four are in PR [#264](https://github.com/The-Band-Solution/theband/pull/264),
open and awaiting review.

Sprint 011 would open citing lessons that, **from that branch**, did not exist. It is L44's defect by
another route: there the lesson had not been written; here it was written and is not where whoever opens the
sprint looks.

**Why it happened.** L44 checked the **existence** of the three documents, not their
**visibility**. `ls docs/sprints/<n>-*/` answers differently depending on the branch, and the check was written
as if `main` were the only place a document lives.

And there is the underlying cause: a sprint's closing travels in the **same PR** as the feature. Until it is
merged, the sprint is closed in the repository and open on `main`.

**What to do differently.** When opening a sprint, check **where** the previous one's closing is before
choosing the branch's base:

```bash
gh pr list --state open           # the previous sprint's closing is in an open PR?
git log --oneline main -1         # does main have the commit that closes the previous sprint?
```

If it is in an open PR, **stack** the branch on top of it — that is what this sprint did, and it had the
side effect of unblocking the screen task, which depended on the same code.

**Status**: open.

---

## L46 — A test with a time cutoff and data built in the same instant passes or fails by luck {#l46--teste-com-corte-temporal-e-dado-montado-no-mesmo-instante-passa-ou-falha-por-sorte}

**Origin**: Sprint 011 · **Type**: technical

**What happened.** Two test defects, both clock-related, both on the same day:

| Symptom | Cause |
|---|---|
| the second collection marked nothing | both collections fall in the **same second**, and the cutoff is a strict `<` |
| the mark reached **33** team memberships where 9 were expected | the cutoff was `DateTime.utc_now/1`, and building the fixture takes hundreds of milliseconds: part of the team memberships ended up on the wrong side of the second's turnover |

The second is the worse of the two: it **passes** when the machine is fast.

**Why it happened.** The cutoff of an absence mark is a statement about **elapsed time**, and
the test built everything in a single instant. In real data, hours pass between one collection and the next.

**What to do differently.** In a time-cutoff test, two rules:

- **age the data explicitly** — move back the timestamp of what the previous collection wrote, instead of
  waiting for the clock to move on its own;
- **the cutoff is always past and fixed** — `agora() - 15 min`, never `agora()`. A cutoff at the instant of the
  call competes with the scenario's setup time.

**Status**: open.

---

## L47 — A cross-repository link only exists from the second collection on {#l47--vínculo-entre-repositórios-só-existe-a-partir-da-segunda-coleta}

**Origin**: Sprint 011 · **Type**: knowledge

**What happened.** The test for the link whose parent is in `A` and whose child is in `B` failed because it found
no link at all. The cause is not the test: it is how collection works.

`vincular/2` runs **per repository**, and resolves the child by `external_id` among the issues **already
written**. When `A` is processed, the issue from `B` does not yet exist — the relation becomes an
`out_of_scope` refusal. On the **next** collection, the child is already in the database, and then the link is recorded.

**Why it matters.** It explains two numbers in the real data that looked unrelated: the **4**
`out_of_scope` refusals, and the **57** links that cross repositories. They are the same phenomenon at different
moments — the refusal is the cross link **before** the collection that completes it.

And it has a direct consequence: **an organization's first collection undercounts decomposition**, and
nobody notices, because the refusal is recorded silently.

**What to do differently.** When measuring decomposition in a newly observed organization, check
`refused_links` before concluding that the source does not declare it. And when building a test scenario with a
cross-repository link, **collect twice** — a single collection does not produce the state.

**Status**: open.

---

## L48 — A closing keyword in Portuguese does not close the issue, and nothing warns {#l48--palavra-de-fechamento-em-português-não-fecha-a-issue-e-nada-avisa}

**Origin**: Sprint 011 · **Type**: process

**What happened.** PR [#278](https://github.com/The-Band-Solution/theband/pull/278) opened with
**"Fecha #263"** on the first line of its body. The PR was merged, and **#263 stayed open**.

**And it was not the first time.** Reviewing the list of open issues — done by the
maintainer, asking *"why are these still open?"* (*original: "por que estas ainda estão abertas?"*) — found
**#246** open since the merge of PR [#264](https://github.com/The-Band-Solution/theband/pull/264), which said
**"Fecha #246"**. Two PRs, the same mechanism, and neither warned.

GitHub only recognizes the English words — `close`, `closes`, `closed`, `fix`, `fixes`, `fixed`,
`resolve`, `resolves`, `resolved`. "Fecha" becomes ordinary text: it creates the cross-reference, which **looks like**
the link working, and closes nothing.

**Why it happened.** This repository's documents are in Portuguese, and the phrase came out in the language of
the rest. And the signal that it worked is indistinguishable from the signal that it failed: the issue appears
mentioned in the PR in both cases.

**It is the silent success pattern again** — no error, and the issue stays open looking like
undone work.

**What to do differently.** The closing keyword is **in English**, even in a Portuguese body:

```text
Closes #263.
```

And the check is one line, after the merge:

```bash
gh issue view <n> --json state --jq .state   # CLOSED, or close it by hand
```

**It also applies to the second trap of the same mechanism**: the keyword only closes when the PR lands on the
**default** branch. A stacked PR, whose base is another branch, closes no issue at all when merged
— and #278 was stacked. #264 was **not**, and still did not close: there the cause was only the language.

**And the check that found the recurrence was not mine**: it was the maintainer looking at the list
of open issues. Two delivered issues stayed open for days with nothing indicating it. **The list
of open issues is the check**, and it applies when closing the sprint:

```bash
gh issue list --state open --limit 100   # has any of them already been delivered?
```

**Status**: open.

---

## L49 — One measurement does not describe a screen whose cost depends on the execution plan {#l49--uma-medida-não-descreve-uma-tela-cujo-custo-depende-do-plano-de-execução}

**Origin**: Sprint 012 · **Type**: technical

**What happened.** I measured the person detail on a single person — **85 ms** — and wrote the whole spec
with that number. The maintainer pointed to a page that took **2 s**. The eight people with the most
work measured between **3.5 and 6.12 s**, and the one I had measured was the **fastest of all** —
with more assigned issues than any other.

**Why it happened.** The query had a subquery over all of the tenant's promotions, and
Postgres executed it with different strategies depending on what it estimated: a single sort in one
case, **163,451 group sorts** in another. The time did not depend on the person's size; it depended
on the chosen path.

**It is L30 on new ground.** There it was checking the number against the source; here it is that **a sample does not
describe a distribution** when the hidden variable is the execution plan.

**What to do differently.** When measuring a screen, measure **the tail**: the cases with the most data, and at least
five of them. And when two similar cases give very different times, that **is** the finding —
not noise to be discarded.

**Status**: open.

---

## L50 — A test that compares two measurements must prove it measured something {#l50--teste-que-compara-duas-medidas-precisa-provar-que-mediu-alguma-coisa}

**Origin**: Sprint 012 · **Type**: technical

**What happened.** The test guaranteeing that cost does not grow with history compared rows
read before and after doubling the promotions. **It passed on the first run — measuring zero.** The
expression that extracted the number from the plan looked for `"Relation Name"` before `"Actual Rows"`, and
Postgres's JSON has the keys in **alphabetical order**: it never matched.

`0 <= 0 × 1,5` is true. The test would have watched for the regression forever without ever looking.

**Why it happened.** The assertion was about the **relation** between two measurements, and a relation between two
zeros is always satisfied. The test case had the right shape and empty content.

**What to do differently.** Every test that compares measurements carries a **guard that the measurement
exists**:

```elixir
assert simples > 0, "a medida deu zero — o que passou não foi a garantia"
```

It is the same family as L22 and L41: a comparison that cannot tell whether either side happened.

**Status**: open.

---

## L51 — Asserting about the schema without checking contradicts the documentation already in the code {#l51--afirmar-sobre-o-schema-sem-conferir-contradiz-a-documentação-que-já-está-no-código}

**Origin**: Sprint 012 · **Type**: process

**What happened.** I wrote in **four documents** that `inserted_at` had second precision, and
built on it a "correctness defect": tied promotions would return an arbitrary concept.

The schema declares `timestamps(type: :utc_datetime_usec)`, the column has precision **6** in the database, and the
docstring of `list_issues/2` already said, in full, *"`inserted_at` em microssegundo desempata"* ("`inserted_at` in microseconds breaks the tie").

**Why it happened.** I recognized a pattern — second-precision `utc_datetime` is the project default in
other tables — and applied it without checking **this one**. The pattern was true in three neighboring tables
and false in the one that mattered.

**And the cost was low only by chance**: the tie-break kept going in as a safeguard, and nothing in the plan
changed. Had the conclusion been "we need to migrate the column", it would have cost a sprint.

**What to do differently.** Before writing a characteristic of the schema in a spec, **read the schema**
— and, when there is a docstring on the subject, read it before contradicting it. The code is the source; the
memory of the pattern is not.

**Status**: open.

---

## L52 — Continuity of conversation is not continuity of branch {#l52--continuidade-de-conversa-não-é-continuidade-de-branch}

**Origin**: Sprint 013 · **Type**: process

**What happened.** Features 014 and 015 were born from the same conversation: measuring 014 revealed the 288
logins without a person, and the decision to create them became 015. **I implemented both on the same branch**, and the
PR was born with both diffs — against `AGENTS.md` §17, and against what **my own sprint
backlog** said two sections above: *"two PRs, one sprint"* (*original: "dois PRs, um sprint"*).

**Why it happened.** The second feature was a direct consequence of the first, and the feeling of
continuity — same conversation, same measurement, same subject — extended to the branch without a conscious
decision. **Writing the rule in the backlog did not prevent breaking it**: it was read at the opening and not
at commit time.

**The real cost**: navigation and ingestion have different review criteria. Whoever reviewed #284
would have had to switch criteria in the middle of the diff — and that is exactly what the rule exists to avoid.

**What to do differently.** The question is at the **first code commit**, not at sprint opening:

```bash
git log --oneline main..HEAD    # are the code commits all from the same feature?
```

If the answer is no, the new branch is born **before** the commit, not after. Fixing it afterwards cost
two branches by cherry-pick and one closed PR.

**Status**: open.

---

## L53 — The ceiling of a cost test comes from measuring both sides {#l53--o-teto-de-um-teste-de-custo-vem-da-medida-dos-dois-lados}

**Origin**: Sprint 013 · **Type**: technical

**What happened.** I wrote a test guaranteeing that linking names adds no query, with the ceiling
`assert consultas <= 30`. **It failed with the right code**: the screen made 38. The reflex would be to raise the
number until it passed — and a `<= 300` would pass with the defect the test exists to catch.

I measured both sides: **39 before** the feature, **38 after**. The ceiling became 39.

**Why it happened.** The number came from an estimate — "a screen like this should make about 30" — and not from
measurement. An estimated ceiling errs in both directions, and both are bad: it fails the right code, or passes the
wrong one.

**What to do differently.** A cost test with a numeric ceiling requires **measuring the before**, and the comment
keeps both numbers:

```elixir
# 39 before the feature, 38 after. A ceiling of 30 fails the right code;
# one of 300 passes with the defect.
assert consultas <= 39
```

It applies to queries, time, rows read and memory — and it is a sibling of **L50**, which requires proving the
measurement is not zero.

**Status**: open.

## L54 — An atom created on demand makes the result depend on load order {#l54--átomo-criado-sob-demanda-faz-o-resultado-depender-da-ordem-de-carga}

**Origin**: Sprint 014 · **Type**: technical

**What happened.** The knowledge base loader classified each artifact's type with
`String.to_existing_atom(chave_de_topo)`, with `rescue ArgumentError -> :unknown`. The intent was
right: text coming from a file must not create atoms.

The effect was something else. Whether the atom existed depended on **which module had already been loaded**.
Before `Mix.Task.run("app.config")`, `:ontology` did not exist yet — the 12 ontologies became
`:unknown`, the dependency map came out empty, and validation failed the knowledge base with **124 invented
problems**, all in ontologies that declare the dependency right there in the file. After
`app.config`, the same knowledge base passed.

I lost hours chasing the defect in the knowledge base, because calling the validator directly passed and the Mix
task failed — with the same code, over the same files.

**Why it happened.** `to_existing_atom` turns a question about the **data** ("is this type
known?") into a question about the **state of the virtual machine** ("has this atom already been created?"). The
two almost always coincide, and diverge exactly when the code runs early.

**What to do differently.** A closed set known at compile time becomes a **literal table**:

```elixir
@tops [{"ontology", :ontology}, {"module", :module}, ...]

defp kind_from(top) do
  case List.keyfind(@tops, top, 0) do
    {_, kind} -> kind
    nil -> :unknown
  end
end
```

The atom exists as soon as the module loads, and the result no longer depends on order. It applies to every
text → atom mapping over a closed set: artifact type, sortable column, role.

**Status**: open.

## L55 — A task that does not compile validates the previous build {#l55--task-que-não-compila-valida-o-build-anterior}

**Origin**: Sprint 014 · **Type**: process

**What happened.** `mix knowledge.validate` called `Mix.Task.run("app.config")` and nothing else.
`app.config` **does not compile**. The task ran against the beams from the previous compilation, so a
fix in the validator did not show up — and I was debugging a defect already fixed on disk, with the direct
call to the module passing and the task failing.

**Why it happened.** `mix run`, `mix test` and `mix compile` compile on their own, and we
generalize that "a Mix task compiles". It is not true: what compiles is the declared dependency, and
`app.config` does not have it.

**What to do differently.** Every Mix task that **measures** the code — gate, validator, report —
starts with `Mix.Task.run("compile")`. A gate that measures old code lies in both directions: it passes
what has already broken, and fails what has already been fixed.

**Status**: open.

## L56 — Filtering telemetry by `source` does not reach whoever queries with raw SQL {#l56--filtrar-telemetria-pela-source-não-alcança-quem-consulta-por-sql-cru}

**Origin**: Sprint 014 · **Type**: technical

**What happened.** The query counters excluded the Oban tables by `meta[:source]` —
L42's fix. The coverage job failed anyway: 30 queries with few issues and 31 with
many, on a screen the branch did not touch.

Oban queries with **raw SQL**. Then `meta[:source]` comes in null, while the query text says
`oban_jobs`. Under coverage the run stretches, the `Oban.Stager` tick falls inside the window, and the
query gets counted against the screen.

**Why it happened.** The first fix closed the path I had seen — query via
schema — and assumed it was the only one. `source` is filled in by Ecto when there is a schema; without a schema,
there is nothing to fill in.

**What to do differently.** A query telemetry filter looks at **both**: the `source` and the text.

```elixir
String.starts_with?(query, "SELECT") and
  to_string(meta[:source]) not in ignoradas and
  not String.contains?(query, "oban_")
```

And the lesson behind the lesson: **a test that fails under coverage and passes outside it is not intermittent
by chance** — coverage changes timing, and what changes with timing is the window of whoever measures.

**Status**: open.

## L57 — A check that filters for a type nobody produces never runs {#l57--verificação-que-filtra-um-tipo-que-ninguém-produz-nunca-roda}

**Origin**: Sprint 014 · **Type**: technical

**What happened.** `perguntas_de_competencia/2` filtered `kind == :competency_questions`, and
**no** artifact in the knowledge base had that type — the loader classified them as `:unknown`. The
check existed, was called, walked an empty list and returned zero problems. Green.

It only showed up because the loader fix started producing the type, and then the check began to
actually run.

**Why it happened.** It is silent success in its hardest-to-see form: there is no error, no
warning, and the function **is** on the execution path. What is missing is the data, and absence of data is
indistinguishable from absence of problems.

**What to do differently.** A check that filters by type carries a test that **proves the
filter finds someone**:

```elixir
assert perguntas != [], "nenhum arquivo de perguntas de competência foi reconhecido"
```

It applies to the whole family: `Enum.filter` by type, `where` by category, query by
discriminator. If the filtered set could be empty by mistake, the test asserts it is not.

**Status**: open.

## L58 — A stacked PR merged after its base gets nowhere {#l58--pr-empilhado-incorporado-depois-da-base-não-chega-a-lugar-nenhum}

**Origin**: Sprint 015 · **Type**: process

**What happened.** Three stacked PRs, and the merge order was this:

```
03:25:48  #302 → 034-editar-credenciais ... ✓ verde
03:26:03  #301 → main                    ... ✓ verde   (leva a 033, que leva a 034)
04:50:35  #303 → 034-editar-credenciais  ... ✓ verde
```

All three merges were green. **The content of #303 did not reach `main`**, because at 04:50
`034` was no longer a path to anywhere: it had been merged into `033` at 03:25, and
`033` into `main` fifteen seconds later.

Four commits were orphaned — `data_table.ex` and `tabela_live.ex` did not even exist on `main`.
And it was not only #303's: the last two commits of #302, pushed **after** it was
merged, followed the same path to nowhere.

**Why it happened.** Merging a stacked PR does not check whether the base still flows downstream. GitHub
has what it needs to warn — it knows `034` has already been merged — and does not warn: for
it, merging into an existing branch is a valid operation, and it really is.

The signal is also misleading in the wrong direction: **the PR stays green**. Green there means "this
diff applies on top of this base", and not "this code goes to `main`".

**What to do differently.** Two things, and the second is the one that catches it:

1. **merge the stacked PR before the base**, or retarget it to `main` after the base
   has gone;
2. **check the commit on `main`, not the green PR**:

```bash
git fetch origin
git branch -r --contains <sha> | grep origin/main   # empty = did not arrive
```

It is L48 applied to **content** instead of to the closing keyword. L48 was born from `Fecha #281`
not closing the issue; this one is born from a merge not incorporating the code. Both have the same shape:
the operation was done, the effect did not happen, and nothing said so.

**And it is L45 from the other end.** L45 says a new sprint branched from `main` does not see the previous
one's closing while the PR is open — the work exists and `main` does not see it. Here the PR was
merged and `main` still does not see it: same symptom, opposite cause.

**Status**: open.

## L59 — CI's green depended on who triggered the run {#l59--o-verde-do-ci-dependia-de-quem-disparou-a-execução}

**Origin**: Sprint 015 · **Type**: technical

**What happened.** Commit `090c9ea1` was measured twice by the same workflow, in the same
minute:

```
por push            cobertura 80,2%   ✓ passou   (122,7 s de teste)
por pull_request    cobertura 23,4%   ✗ falhou   ( 14,0 s de teste)
```

The run that failed had the **entire** `lib/the_band_web` tree at 0.0% — including files
with plenty of tests. It was not a coverage drop: it was the suite crashing, and coverage measuring what
was left.

**The chain.** `config/test.exs` did not override Oban, so in test the queue, `Cron`,
`Pruner` and `Peer` started for real. They query the database on their own, outside the process that owns the
sandbox connection, and each query dies with `DBConnection.OwnershipError`. The supervisor
restarts, and the cycle starts again.

When the restart intensity blows, what restarts is the **application** supervisor — and it
takes `KnowledgeBase` down with it, which owns the knowledge base's ETS table:

```
** (ArgumentError) the table identifier does not refer to an existing ETS table
   :ets.lookup(:the_band_knowledge_base, {:derivation_rule, ...})
```

**197 tests** failed this way, all for the same reason, and none of them had a defect.

**Why it happened.** Three things added up, and none alone would have brought it down:

1. Oban processes querying the database outside the connection owner — noise tolerated for months,
   with hundreds of `OwnershipError` per local run that nobody read;
2. a GenServer that **owns an ETS table** in the application tree — the table dies with the process;
3. coverage changing timing, which is **L56** again.

The third is what made the defect pick runs. The first two were there all along.

**What to do differently.**

**Tolerated noise is an unmeasured defect.** Hundreds of `OwnershipError` per run were read
as test noise. They were a supervisor restarting in a loop. An error that always appears and brings
nothing down has not brought anything down yet — that is not the same as not bringing anything down.

**State kept in a process has the lifetime of the process.** An ETS table belongs to whoever
created it. If the owner is in the application tree, every supervisor restart wipes the knowledge
base — and the symptom appears far away, in any test that reads it.

**A verdict that changes with the trigger is a verdict that is worth nothing.** Had the PR been merged
on the push's green, the defect would keep picking PRs at random — and whoever saw red
would learn to rerun without reading, which is the same erosion described in issue #232.

**And the note on the fix**: `testing: :manual`, which is Oban's documented mode, **did not work** —
it checks the migration version at startup, and the repository is at `version: 12` with the
library requiring 14. Fixing CI by slipping in a production migration would have traded a
defect for a risk. The debt was recorded, separately, in PR #308.

**Status**: open.

---

## L60 — The pipe in `mix gates` returns the exit code of `tail` {#l60--o-pipe-no-mix-gates-devolve-o-código-de-saída-do-tail}

> **Closed in Sprint 028** — rule in `AGENTS.md` §7 — `mix gates` is the single definition, and the verdict is **its exit code**. The block stays: the rule carries the obligation, and here is the case that produced it.

**Origin**: Sprint 016 · **Type**: process

**What happened.** The first gates run of this session was:

```bash
mix gates 2>&1 | tail -40; echo "EXIT=$?"
```

The report said **exit code 0**. The gates had **failed**:

```
** (Mix) The database for TheBand.Repo couldn't be created: killed
** (Mix) gate reprovou: testes — código de saída 1
EXIT=0
```

The `$?` of a pipeline is the **last** command's, and the last was `tail` — which always exits
with zero, because reading forty lines never fails. The real cause was Docker being down, and
Postgres refusing connections on `localhost:5432`.

**Why this is a recurrence, and not a new case.** The rule is already written in three
places: in `AGENTS.md` (section 4, *"do not disable checks"*), in the project memory
(*"`mix gates` is the single definition — never run a gate with `| tail`"*), and in the lessons
themselves. It was violated anyway, on the first run, for a trivial reason: the pipe was
there to **shorten the output**, not to dodge the verdict.

**It is the same family as the lesson that recurs most in this repository** — absence of error read
as a result. Here the absence was manufactured by the reading command itself.

**What to do differently.**

**To shorten the output, redirect to a file — never pipe.**

```bash
mix gates > /tmp/gates.log 2>&1; echo "EXIT=$?"   # the $? is mix's
tail -40 /tmp/gates.log                            # reading comes after, and is a different thing
```

Redirection preserves the exit code because there is no second command. Reading the
output and obtaining the verdict become two separate acts, which is what they always
were.

**The written rule did not prevent it.** What prevents it is the shape of the command being different: as long as
`| tail` is the natural way to shorten, someone will use it again. The alternative above
has to be just as short, or the rule keeps depending on memory.

**Status**: open — the redirection form **went into `AGENTS.md`** (section 4,
next to the prohibition), which resolves the original pending item.

**Applied in**: Sprint 022 — and it exacted a new variation. The command was
`mix gates > log 2>&1; echo "EXIT=$?"` run in the background: the `EXIT=` went to the
*task*'s output, and the log ended only in "13 gates verdes" — the acceptance pointed out that the
log did not contain the exit code. The complete form writes the verdict **into the log
itself**: `mix gates > log 2>&1; echo "EXIT=$?" >> log`. Two runs without a recurrence
of the pipe; one more and it closes.

---

## L61 — A limitation declared in the mapping does not become a constraint in the code by itself {#l61--uma-limitação-declarada-no-mapeamento-não-vira-restrição-no-código-sozinha}

**Origin**: Sprint 021 (feature 037) · **Type**: knowledge

**What happened.** The mapping `github.workflow_run.to.ciro.continuous_integration_process`
said, since version 1, in its own `limitations` section:

> Not every workflow is continuous integration; release workflows map to CDRO.

I implemented the collection mapping **every** Actions run to
`ciro.continuous_integration_process`. Only when measuring against the real data did the problem appear: of the
1,051 collected runs, the five most frequent are `Sync to GitLab` (264),
`Deploy Docs to GitHub Pages` (247), `Deploy Backoffice and Front-office` (235),
`Sprint Rollover` (109) and `Release ConectaFapes` (90). **None of them integrates code.**

**Why it happened.** I read the mapping through the `target`, `attributes` and `relations` sections — the
ones that say what to build. `limitations` was read as documentation of what the platform could not
do, and not as the **specification of a path the code needs to have**. The
distinction does not exist in the format: both things live in the same list.

The cost would have been a continuous verification measure poisoned by runs that verify
nothing — and nobody would question it, because the number would look just like the right number.

**What to do differently.** When implementing a mapping, read `limitations` **before**
`attributes`, and sort each item into two piles: what the platform cannot know (becomes an
absence sentence on the screen) and what the platform **needs to distinguish** (becomes a branch in the code).
The second pile is a requirement, not a footnote.

And when an item from the second pile is addressed, mark it `RESOLVIDA na versão N` in the file
itself — which is what version 2 of this mapping started doing.

**Status**: open.

---

## L62 — Summing counters through a hand-written list erases the new key silently {#l62--somar-contadores-por-lista-escrita-à-mão-apaga-a-chave-nova-em-silêncio}

**Origin**: Sprint 021 (feature 037) · **Type**: technical

**What happened.** The CI collection phase accumulates a summary by summing maps with
`%{jobs: a.jobs + b.jobs, monoliticos: ..., sem_nome: ...}`. When adding the key
`sem_jobs` — which is what decides whether the repository checkpoint advances —, `somar/2` **was not
updated**. The result: `marcar_se_completo/3` without a matching clause, and the phase
would crash any repository sync with at least one run.

It went through the whole `mix gates`, with 1,038 green tests, and into the PR.

**Why it happened.** Two causes added up. The sum repeated the list of keys in a second place,
and nothing tied the two together. And **the phase was never exercised**: with no observed repository, the list of
repositories is empty and no request happens — the full sync test passed
through it without touching it. It is the same shadow in which file collection stayed **switched off** with the
moduledoc claiming it was on.

**What to do differently.** Two things, and the second is the one that catches the whole family:

```elixir
# the sum derives the keys from zero, and does not repeat them
defp somar(a, b) do
  Map.new(zero(), fn {chave, _} -> {chave, Map.fetch!(a, chave) + Map.fetch!(b, chave)} end)
end
```

And: **every phase that only runs under a data precondition needs a test that creates that
precondition.** The question when finishing a new phase is "which database row makes this phase
exist?", and the test starts by creating that row. Without it, the green suite only proves the phase
was not visited.

**Status**: open.

---

## L63 — A link that only writes what matched erases what the source said {#l63--vínculo-que-só-grava-o-que-casou-apaga-o-que-a-origem-disse}

**Origin**: Sprint 021 (feature 038) · **Type**: technical

**What happened.** A new panel at `/work/changes` showed **"no issue recognised:
4.177"** — 83% of the 5,035 change requests with no link to scope. The maintainer
distrusted the volume and asked for it to be checked. Three change requests sampled against the source:

| PR | the source says | the database says |
|---|---|---|
| `The-Band-Solution/theband#427` | closes #426 | no link |
| `leds-conectafapes/…-otto#127` | closes #675 | no link |
| `…prestacao-de-contas#133` | closes nothing | no link |

**Two out of three were collection failures**, not facts about the process.

**Why it happened.** `GithubChangeRequests.vincular_issues/3` translates the source's
`closingIssuesReferences` into internal ids, and only writes what **already exists** in
`collected_issues`:

```elixir
externos = Enum.map(get_in(node, ["closingIssuesReferences", "nodes"]) || [], & &1["id"])
ids = issue_ids_por_external(ctx.tenant.id, externos)   # matches only what was already collected
:ok = Commands.replace_attended_issues(ctx.tenant, solicitacao_id, Map.values(ids))
map_size(ids)                                            # counts only what matched
```

When the issue is not in the database, the link is discarded **without a record**. The function returns
`map_size(ids)` — what matched —, and never `length(externos)` — what the source said. The
difference between the two is exactly the hole, and it is not written anywhere.

The pattern is that of `commits_total`, which the same feature got right: the source's total stays in the
column, and the screen compares it with what was collected to reveal truncation. Here it did not.

**What to do differently.** Every translation of an external reference into an internal id **writes both
numbers**: how many the source cited, and how many the platform resolved. The rule in one
sentence: *if the function discards something, how much it discarded is data, not an implementation
detail.*

And the assertion that catches this in a test: build a PR whose `closingIssuesReferences` cites a
**non-collected** issue, and require the source's total to appear in the record.

**The cost avoided.** The panel would have published "83% of the work with no trail to scope"
as a measure of the organization's process. Nobody would question it — the number looks
just like the right number. It is the same family as
[[padrao-largo-inventa-mais]]: the expensive error is the one that looks like a measure.

**Status**: open — the fix has not been made yet.

---

## L64 — A denominator that includes the impossible case hides the signal {#l64--denominador-que-inclui-o-caso-impossível-esconde-o-sinal}

**Origin**: Sprint 021 (issue #440) · **Type**: technical

**What happened, twice on the same day.**

First: a panel said "no issue recognised: 4.177" — 83% of the change requests. I sampled
three, two were collection failures, and I announced the number was wrong. Measured after the
fix: 4,168 were real facts and 9 were our gap. The sample of three did not measure 5,035.

Then, in the #440 survey, when evaluating two fields of the CI run payload:

| field | how I presented it | the right denominator |
|---|---|---|
| `pull_requests` | 3 of 1,052 runs — 0.3%, "not worth it" | 3 of **33** PR-triggered runs — **9%** |
| `triggering_actor` | differs in 1 of 1,052 — "not worth it" | differs in 1 of **3** reruns — **33%** |

**Why it happened.** In both cases the denominator included records where the field **cannot
exist**. A run triggered by `push` has no associated pull request; a first
attempt has no rerun actor different from the original actor — it is the same person, by
definition. Adding those cases to the denominator dilutes the signal until it disappears.

And the maintainer caught it both times, by the volume. The second time, quoting back my
own text.

**What to do differently.** Before computing a proportion, answer: **in how many
records could this field be filled in?** That is the denominator. If the answer requires
a filter, the filter is part of the measure and is declared along with it.

And the corollary, which holds for every measure on this platform: when the correct denominator is
small — 33, or 3 —, the honest conclusion is **"small sample, I don't know"**, and not a
percentage. Three reruns do not decide whether `triggering_actor` is worth keeping.

**The common root with [[padrao-largo-inventa-mais]]**: the expensive error is the one that looks like a
measure. A percentage with the wrong denominator looks exactly like a
correct one.

**Status**: open.

---

## L65 — A collection the network has already specified costs a fraction of one it has not {#l65--coleta-que-a-rede-já-especificou-custa-a-fração-de-uma-que-não}

**Origin**: Sprint 021 (issue #440) · **Type**: process

**What happened.** The #440 survey found three declared mappings with
not a single row in the database: review, branch and deployment. Implementing the first two took
one session, and the reason is that **almost nothing needed to be decided**:

| piece | review | branch |
|---|---|---|
| target concept | declared | declared |
| attributes and paths in the source | declared | declared (one) |
| relations | declared in the mapping | declared |
| information need | declared | — |
| measure | declared, with inputs | — |
| limitations | four, all actionable | two |

The work was **translating what was already written** into migration, schema, query and
screen. No meeting, no choice of slice, no doubt about what the number
means.

**The comparison that closes the argument.** On the same day, the third — deployment — did not move
a single step, because the source was wrong: the GitHub API has 2 records where the CI jobs
already produce 1,361. It became issue #442, with four pending decisions, and the
maintainer's decision to use ArgoCD. **A collection whose source has not been decided yet costs
orders of magnitude more than one whose ontology already has been.**

**Why it happened, and what it teaches about the order of work.** The mapping
written ahead of the code is not documentation: it is the expensive part of the work already done. The
four review limitations became four schema decisions in minutes —
`author_type` to separate bots, raw `state` so as not to assert conformance, `reviews` instead
of `reviewThreads`, and null `submitted_at` for drafts. I would not have thought of any of them
on my own while writing the migration.

**What to do differently.** Before proposing a new collection, sweep the declared mappings and
ask **which are already specified and have no data**. That list is the cheapest backlog
there is, and it shows up on no screen — only by reading the YAML.

The command that produces it:

```bash
# for each mapping, is there a table with data?
for f in $(find priv/knowledge_base/mappings -name "*.yaml"); do
  grep -m1 "  id: " "$f"
done
```

And the corollary: **a limitation declared in the mapping is worth more than a requirement written later**,
because it was written by someone looking at the ontology, not at the screen. It is [[L61]] from the
positive side.

**Status**: open.

---

## L66 — A script that builds the context by hand hides the contract the real job breaks {#l66--script-que-monta-o-contexto-à-mão-esconde-o-contrato-que-o-job-real-quebra}

**Origin**: Sprint 021 · **Type**: technical

**What happened.** The scheduled sync died in **all three tenants**, on all five
Oban attempts, with `KeyError key :started_at not found`. It ended `interrupted`, and it had been
happening since **2026-08-17** — days before anyone noticed. The maintainer asked
why two tenants had errored; it was three.

The cause is one line in `SyncGitHubEO.run/4`:

```elixir
started_at = sync.started_at        # local variable

ctx = %{tenant: tenant, sync: sync, tool: tool, token: token, org: tool.organization_login}
#      ^ no `started_at`, and nine ingestion points read `ctx.started_at`
```

**Why nobody saw it.** Two causes added up, and the second is the lesson:

1. The path that reads the key only runs **when there is data to mark** — the absence mark for
   issues and iterations. With an empty fixture, nothing needs a mark and the line is never
   reached. It is [[L62]] again.

2. **Every manual collection in this session built the `ctx` by hand**, and always with `started_at`:

   ```elixir
   ctx = %{tenant: tenant, tool: tool, token: token, started_at: DateTime.utc_now(:second)}
   ```

   I ran the collection of changes, CI, branches and reviews against the real data, all of them
   successfully — and none went through the `ctx` the job builds. The script satisfied the contract
   the job violated, and so the evidence of "it works against the real data" was false
   exactly where it mattered.

**What to do differently.** A one-off collection script **does not build the context**: it calls the same
function the job calls, or asks it for the context. When that is not possible, the script
declares at the top that the context is synthetic — and its result does not count as evidence
that the job works.

The question that closes it: *does this script prove the production path works, or only that the
function works with the context I chose?*

**And the test attempt that proved nothing.** I wrote a test that returns an issue through the
simulated edge to force the absence mark. It passed. **I removed the fix on purpose
and it kept passing** — the issue never got written, and the path never ran.
Without that check I would have announced a guarantee that did not exist.

*Every test written to catch a specific defect needs to be run against the defective
code.* If it passes on both, it is not a test of the defect — it is a test of something else.

**Status**: open.

---

## L67 — Two measures with the same name: comparing totals hides that they are different phenomena {#l67--duas-medidas-do-mesmo-nome-comparar-os-totais-esconde-que-são-fenômenos-diferentes}

**Type**: technical · **Origin**: feature 041 (issue #439) · **Status**: open

**What happened.** I switched the measure of "change request merged with a red
check" from matching by `head_sha` to the tip's `statusCheckRollup`, and
justified the switch by comparing the **totals**: "matching found 284, the rollup
finds 349 — 23% more". I wrote that in four places: two `@moduledoc`, one
query comment and one column comment.

Measured in the database afterwards: matching finds **296**, the rollup finds **221**. The rollup
finds **fewer**. The claim was inverted, and it was the whole argument for the
switch.

*(Final numbers, with the recollection completed on 2026-08-20: matching **323**, rollup
**261**, in both **115**, union **469**. The sign did not change; see L70 on why
the midway numbers should not have been written down as definitive.)*

**Why it happened.** I compared two one-line numbers. The question I did not ask
was *which* change requests each one finds — and the answer changes everything:

    in both          82
    matching only   214
    rollup only     139
    union           435

An overlap of 82 in 435. **They are not two precisions of the same phenomenon; they are
different phenomena.** Of the 214 that only matching finds, 186 are green at the
tip: the red was on an intermediate commit and was fixed before the
merge. Matching overcounted — and overcounted exactly the case that the
screen's `@moduledoc` declares it refuses to count ("red on a proposal branch is the
process working").

In other words: the switch was right, and for a **better** reason than the one I
wrote. But I had written the wrong reason, with an inverted number, and it was already
in reviewed code.

**What to do differently.** When replacing one measure with another, never justify it
by the difference in totals. Measure the **overlap** — in both, only in A, only in B,
union — and look at a sample of what only the old one finds. If the overlap is
small, the two do not measure the same thing, and their totals are not comparable.

And the corollary about coexistence: a replaced old measure gets **removed**, not
left alongside. `integrated_with_red/2` was left with `@spec`, a 25-line `@doc` and
no caller — dead code whose `@doc` would convince whoever wired it back in that it
was right.

**Relation to L64.** L64 is about a denominator that includes the impossible case; this one
is about a numerator that includes the case opposite to what one wants to measure. Both are born
from accepting the count without looking at what it counted.

---

## L68 — An incremental cutoff excludes the old record forever when the query gains a field {#l68--corte-incremental-exclui-para-sempre-o-registro-antigo-quando-a-consulta-ganha-campo}

**Type**: technical · **Origin**: feature 041 (issue #439) · **Status**: open

**What happened.** Feature 041 added `statusCheckRollup` to the change request
query. Two weeks later, **763 merged change requests in 10
repositories** still lacked the field — and not through a failure: `GithubChangeRequests.collect/1`
stops paginating when it reaches `observed_repositories.changes_collected_at`, and those
repositories were already listed as collected.

The signature is unmistakable: in the ten repositories the fraction without the field was **100%**.
A whole repository without the field is a repository untouched since the field has existed.

**Why it happened.** The incremental cutoff is right for data that does not change, and it is what avoids
repaginating history on every collection. But it answers "have I already collected this record", and the
question a query change asks is another: "have I already collected this record **with this
query**?". The two coincide until someone adds a field.

**What to do differently.** Every time a phase's query gains a field, the same
change has to answer what happens to what was already collected. Three ways out, and the choice is
explicit:

  * the field only matters from now on — declare that, and have the screen distinguish
    "not measured" from "measured and empty", which is what these columns already do;
  * reopen the cutoff for the affected repositories — `mix the_band.recollect_changes`;
  * a targeted backfill, if a full recollection is too expensive.

What does **not** work is leaving it implicit: the number is wrong, the screen calls it "cannot
know", and nobody connects the gap to the change that created it.

**The structural fix remains open.** Nothing in the code prevents this from coming back in the next
feature that adds a field. A per-repository query version marker
would invalidate the cutoff automatically — it is a design decision, and it is recorded as an issue.

---

## L69 — A defect inside `Logger.info` is invisible to tests, by configuration {#l69--defeito-dentro-de-loggerinfo-é-invisível-a-teste-por-configuração}

**Type**: technical · **Origin**: feature 041 · **Status**: open

**What happened.** `Jobs.RecomputePromotions` interpolated the return of
`Mapping.recompute/2` into a log string. The return is `%{written:, concept_changed:}`, and the
interpolation blew up with `Protocol.UndefinedError` **after** the recomputation had already
happened: the work was done three times and the job ended `discarded`.

I wrote the test, it failed — and it failed **for the wrong reason**, at the broadcast's
`assert_received`. When I restored only half of the log, the test passed.

**Why it happened.** `config :logger, level: :warning` in `config/test.exs`. `Logger.info/1`
is a macro: with the level turned off it exits **before evaluating the argument**. The interpolation
never runs, so the defect does not exist in the test environment.

And `capture_log([level: :info], fn -> ... end)` **does not solve it** — the option filters what is
captured, not what Logger emits. The log comes back empty and the assertion fails for another reason,
which is easy to mistake for "the sentence changed".

**What to do differently.** A test that needs to exercise the content of a `Logger.info` or
`Logger.debug` actually raises the level:

```elixir
nivel = Logger.level()
Logger.configure(level: :info)
on_exit(fn -> Logger.configure(level: nivel) end)

log = capture_log(fn -> assert :ok = Worker.perform(job) end)
assert log =~ "o que a frase promete"
```

And the broader rule: **do not put anything that can raise inside a log interpolation.** The log
is the place in the code where failure is most silent — in tests it does not evaluate, and in production
it brings down work already done.

**Relation to the silent success pattern.** It is the same old defect, in a new
place: absence of signal read as absence of problems. Here the absence was of the
evaluation itself.

---

## L70 — A number measured in the middle of a backfill looks final and is not {#l70--número-medido-no-meio-de-um-backfill-parece-final-e-não-é}

**Type**: process · **Origin**: feature 041, recollection of the 763 · **Status**: open

**What happened.** L67 tells how I had written "2,038 change requests went in without a
check, out of 4,734 measured", measured the database, found **1,705** out of 4,056, and **corrected** the number in
four places — including on the published landing page.

With the recollection completed, the true number is **2,024** out of 4,878.

In other words: the original value was 14 away from the right one, and my "correction" moved it
to 319 away. I corrected in the wrong direction, confidently, and published.

**Why it happened.** There were 763 change requests without the field measured, and I knew it — the
very sentence I wrote said "only 763 were collected before the platform asked for the
field". But I used as the **denominator** the total already measured, and reported the partial count as
if it were the phenomenon.

A number measured while a backfill is running has two bad properties at once: it
is precise (the query is right) and it is provisional (the population is not complete). The precision
makes it look reliable.

**What to do differently.** Before writing any count in a `@moduledoc`, screen, PR or
published page, check whether there is a pending backfill **of that column**:

```elixir
Repo.aggregate(from(c in tabela, where: is_nil(c.coluna)), :count, :id)
```

If it is greater than zero, one of two: wait, or label the number as partial and say how much
is missing. What does not work is reporting the count over what has already been measured — which is exactly the
"denominator that excludes the pending case", a cousin of L64.

And the corollary about correction: **correcting a number requires the same proof as publishing it.** I
treated "I measured it just now" as enough to overturn a previous value, and "now" was the middle of
a recollection.

**Relation to L68.** L68 is the cause of the incomplete population — the incremental cutoff
excluding the old record. This one is what to do while the gap exists.

---

## L71 — When the requirement moves, the tests that document the old place fall in bulk {#l71--quando-o-requisito-muda-de-lugar-os-testes-que-documentam-o-lugar-antigo-caem-em-lote}

**Origin**: Sprint 022 (feature 046) · **Type**: process · **Status**: open

**What happened.** Feature 046 moved the navigation — a 12-item bar became 4 entities +
Settings, and the trail (Changes/Files/Checks) became a sub-tab of Work. The first full run of the
suite brought down **6 tests at once**, and none was a defect of the new code: they were tests
guarding the old requirement. Four in `menus_do_rastro_test` ("the three destinations appear IN THE
BAR"), one in `clicar_leva_a_pagina_test` (it refuted `href="/organizations"` on the whole page
because "there is no organization page" — now there is), and one in `migalha_test`
(`aria-current="page"` on an anchor — the new bar used the same value as the breadcrumb).

**Why it happened.** Good tests carry the *reason* for the requirement in the file itself — and that is
exactly what makes them sensitive when the reason changes address. The feature's plan listed
screens and components to touch, but did not ask **"which tests document the behavior that
this feature retires?"**. The suite answered, at the cost of a whole run (≈10 min) and
diagnosing them one by one.

**What to do differently.** In the plan of any feature that MOVES a requirement (menu, route, visibility
rule, format), add a targeted search step before implementing:
`grep` the tests for the invariants the spec revokes (the hrefs, the sentences, the attribute
values). Each hit becomes a recorded decision: the test moves along with the requirement
(preserving the assertion), narrows its scope, or dies with the premise — decided in the plan, not in the
suite's red. And the resolution of this sprint's three cases is the reference catalog:
change of address (trail), narrowing of scope (organization out of the bar), separation of
vocabulary (`"true"` on the bar, `"page"` only on the breadcrumb).

---

## L72 — The iterations API replaces the whole list: always resend the ones in force {#l72--a-api-de-iterations-substitui-a-lista-inteira-reenviar-sempre-as-vigentes}

**Origin**: Sprint 023 · **Type**: technical · **Status**: open

**What happened.** When creating the Sprint 023 iteration with
`updateProjectV2Field.iterationConfiguration`, Sprint 022's vanished and its 15 items
were left without a sprint. The `iterations` input does not APPEND — it replaces the active list
entirely, and does not accept `id` (recreating generates a new id, orphaning the assignments).

**What to do differently.** Every mutation of that configuration resends ALL the iterations
in force along with the new one. When the damage happens: recreate both and reassign the items on the
spot, checking by query — that was the repair, with even more faithful dates (022 = 1 day).

**Applied in**: Sprint 024 (opening) — the preventive dance preserved 34 assignments,
checked by query. **And Sprint 025 (opening) refined the danger map**: a COMPLETED
iteration keeps its id and survives the mutation, but the VALUES of the items that pointed to
an iteration that left the active list are erased — and the API refuses to reassign to a
completed one ("The iteration Id does not belong to the field"). Sprint 022's 15 items
lost the field irrecoverably; the record of membership is the sprint backlog in the
repository, and the Projects field is a snapshot of the present, not an archive.

---

## L73 — `isVisible` does not see clipping by overflow: the proof of a screen is the image {#l73--isvisible-não-vê-o-corte-por-overflow-a-prova-de-tela-é-a-imagem}

**Origin**: Sprint 023 · **Type**: process · **Status**: open

**What happened.** The Settings dropdown opened CLIPPED by the bar's `overflow-x-auto`
(overflow-x forces overflow-y). The initial diagnosis got the cause right — and was discarded
because Playwright's `isVisible()` returned `true`: the predicate does not consider clipping by an
ancestor's overflow. The screenshot captured IN THE SAME SESSION showed the menu missing, and
was not looked at. The maintainer reported the defect twice before the image was read.

**What to do differently.** A visibility predicate never ends a screen diagnosis: the
proof is the IMAGE, looked at. If a screenshot has already been captured to prove something, it is read
before any conclusion — capturing and not looking is worse than not capturing, because it dresses
the diagnosis up as verified.

---

## L74 — The working tree decides what the dev server serves {#l74--a-árvore-de-trabalho-decide-o-que-o-dev-server-serve}

**Origin**: Sprint 023 · **Type**: process · **Status**: open

**What happened.** Twice on the same day: (1) `mix.lock` changed (bcrypt) and the code
reloader started answering 500 on everything, demanding a restart — the error was clear in the
server log, not on the screen; (2) the schema fix lived on the fix branch, and switching the tree
back to the feature branch resurrected the 400 IN THE MIDDLE of a test by the maintainer — the
schema is read from disk on every generation, and the disk is the current branch.

**What to do differently.** With a dev server whose reloader is on, switching branches is touching the
LIVE server: before switching, say what the user will see change; after touching
mix.lock/config, restart the server without waiting for the symptom. A hot fix the user is
exercising also stays in the active tree (applied without commit) until the official merge.

---

## L75 — Squash-merge opens a window for orphan commits on the PR branch {#l75--squash-merge-abre-janela-para-commits-órfãos-na-branch-do-pr}

> **Closed in Sprint 028** — rule in `AGENTS.md` §12 and a mandatory field in the PR template. The block stays: the rule carries the obligation, and here is the case that produced it.

**Origin**: Sprint 023 · **Type**: process · **Status**: open

**What happened.** PR #562 was squash-merged while the session kept
pushing commits to the same branch (dropdown, organization reach, person page).
The pushes landed on the remote branch — and nowhere else: the PR was already closed, and nothing
warns you. Only the question "did you open the PR?" revealed it; comparing by SHA misleads (squash does not preserve
commits), and it was the CONTENT diff against main that said what was missing.

**What to do differently.** Before every push to a branch with an open PR, check the state
of the PR (`gh pr view --json state`). Once a merge is detected: stop pushing there,
cherry-pick what is left onto a new branch from main, open a complementary PR. The real difference
between branch and main is measured by content (`git diff main branch`), never by the list of
commits.

---

## L76 — The measuring tool needs the target's grammar {#l76--a-ferramenta-de-medir-precisa-da-gramática-do-alvo}

**Origin**: Sprint 024 · **Type**: technical · **Status**: open

**What happened.** The plan for 047 measured "55 message literals" with grep. The
AST-based checker, during execution, found **137** — multiline, concatenation and the pipe
form were invisible to the regex. The plan sized the migration at half.

**Why it happened.** Grep reads lines; code is a tree. Measuring syntactic structure with
a text tool always errs low — and the smaller number looks more credible.

**What to do differently.** A count that becomes task scope uses the tool with the
target's grammar: Elixir code is counted by AST (`Code.string_to_quoted`), never
by regex. Grep serves to FIND candidates, not to COUNT commitments. A close relative
of "check the number against the source" — here the source is the syntax tree.

---

## L77 — A new checker is born with an end-to-end test that does NOT go through it {#l77--verificador-novo-nasce-com-teste-de-ponta-que-não-passa-por-ele}

**Origin**: Sprint 024 · **Type**: technical · **Status**: open

**What happened.** The 047 checker covered plain `put_flash` — and the qualified form
`Phoenix.Controller.put_flash` (another AST head) went straight through. What
caught it was the LANGUAGE TEST: the plug's refusal did not switch language, because the literal
had never been migrated. The checker said "zero findings" with a live finding.

**Why it happened.** Testing the checker only with fixtures designed by whoever
wrote it proves that it sees what the author remembered — not what the repository contains.

**What to do differently.** Every new checker/gate gets at least one end-to-end
test that exercises the promised EFFECT (here: switching the language switches the sentence)
without going through the checker. It is the outside pair that catches the forgotten AST head.

---

## L78 — "Switch at runtime" only enters the contract with a runtime test {#l78--troca-em-runtime-só-entra-no-contrato-com-teste-em-runtime}

**Origin**: Sprint 024 · **Type**: technical · **Status**: open

**What happened.** The 047 contract promised to switch the default language via the gettext
backend config. During implementation, the test failed: the backend config is
COMPILE-TIME; only the `:gettext` app config is read at runtime. The contract was corrected in the
same commit, with the reason — but the promise had been written without proof.

**What to do differently.** A contract clause of the kind "changing X reconfigures at
runtime" is born with the test that changes X at runtime and observes the effect — before the
contract is considered written. Library documentation does not replace measurement
(gettext's describes both configs without shouting which one is compile-time).

---

## L79 — An agent on a shared tree does not switch branches {#l79--agente-com-árvore-compartilhada-não-troca-de-branch}

**Origin**: Sprint 024 · **Type**: process · **Status**: open

**What happened.** The PO's acceptance agent ran `git checkout main` to
evaluate 047 — in the SAME tree as the main session. The machine slept, the agent
died, and the session came back with the 048 files "reverted" on disk until someone
noticed the branch was a different one. Nothing was lost because everything was committed and pushed
— by luck of discipline, not by design.

**What to do differently.** An agent prompt that touches a shared repository carries
the explicit rule: do NOT switch branch/stash — evaluate what the tree has, or ask for
its own worktree (`git worktree add`). And the main session checks
`git branch --show-current` when resuming from any agent that ran git.

---

## L80 — A gap measured with the instrument's own grep inherits its blindness {#l80--a-pendência-medida-com-o-grep-do-instrumento-herda-a-cegueira-dele}

**Origin**: Sprint 024 (acceptance) · **Type**: technical · **Status**: open

**What happened.** The 047 `pendencias.md` promised to enumerate all screen text
outside the checker — and it was measured with a grep for `<.notice>/<.absent>`. The class
"rendered message assign" (`assign(erro: "...")` shown in a div) is neither a
notice nor `put_flash`: it was left out of the catalog, out of the checker AND out of the
enumeration. The PO found it through directed reading, and two user stories came back because of it.

**Why it happened.** The gaps document was validated against its own
method (the grep reproduced the counts byte for byte — E7 of the acceptance), not against the
question it answers ("what does the screen say that does not come from the catalog?"). An instrument
checked against itself confirms itself, not the world.

**What to do differently.** A gap enumeration is validated by INDEPENDENT SAMPLING:
open N screens and list by hand what they say, and check the list against the
enumeration — the same principle as double measurement (two measures, compare
overlap). And every new class of leak discovered becomes a checker test case
in the same commit.

**Applied in**: Sprint 025 — the rework extends the checker to the assign class
by AST and redoes the gaps list with sampling.

---

## L81 — Closing the counterexample does not close the class {#l81--fechar-o-contraexemplo-não-fecha-a-classe}

**Origin**: Sprint 025 (acceptance) · **Type**: technical · **Status**: open

**What happened.** The 047 rework migrated the 13 points that the Sprint 024 acceptance
pointed out and extended the checker to the assign class — and US1 fell AGAIN: the
same screen-sentences-as-literals existed one level back, born in a source
function (`PatternValidator.explicar/1`, `primeira_mensagem/1`) and reaching the same
assign leak behind a call that the checker approves on purpose.

**Why it happened.** The rework aimed at the LIST of findings, not at their SHAPE. The
"approved function call" boundary is legitimate — as long as what escapes through it
is enumerated, and nobody hunted for what was escaping.

**What to do differently.** Every class rework closes with the hunt for SIBLINGS:
derive the class's syntactic pattern (here, `(erro|ok|error|aviso): funcao(...)`) and
sweep the repository for it BEFORE delivering. What the sweep finds either migrates in the
same PR or enters the gaps list by name — it is never left for the next acceptance to
discover.

---

## L82 — The comment that contradicts the contract is the violation documenting itself {#l82--o-comentário-que-contradiz-o-contrato-é-a-violação-documentando-a-si-mesma}

**Origin**: Sprint 025 (acceptance) · **Type**: process · **Status**: open

**What happened.** The 051 spec, contract and tasks asked for the ORGANIZATION in the
people search result (the homonyms edge case). The implementation showed only name and
login — and left a comment saying "no organization", with a new rationale, without
correcting any contract. The US fell at acceptance because of it.

**Why it happened.** In the heat of implementation, the divergence looked like an improvement and the
comment looked like a record. But the house rule is different: a contract error is
corrected IN THE CONTRACT, in the same commit, with the reason — a code comment does not amend a
normative document, it only confesses that the document was ignored.

**What to do differently.** When diverging from spec/contract/tasks during implementation:
stop, correct the document with date and reason (or ask, if the divergence is a
product decision), and ONLY THEN code. A checking grep before the PR:
comments with "não"/"em vez de" ("not"/"instead of") near references to an FR/contract deserve
a second reading.

---

## L83 — Squash-merge on the release diverges the histories {#l83--squash-merge-no-release-diverge-os-históricos}

> **Closed in Sprint 028** — rule in `AGENTS.md` §12 and a mandatory field in the PR template. The block stays: the rule carries the obligation, and here is the case that produced it.

**Origin**: Sprint 026 (release v0.1.0) · **Type**: process · **Status**: open

**What happened.** PR #636 entered `main` by squash, creating there a commit
that `development` did not know. The merge back opened **6 conflicts, all of identical
content** — the resulting tree was the same as `development`'s.

**Why it happened.** Squash produces a new commit, with no kinship to the ones it
summarizes. The contents stay the same and the histories diverge; git has no way to
know that both sides are the same thing, and GitHub starts warning
"main had recent pushes" on the following PRs.

**What to do differently.** Two things, and the first avoids half the problem.

**The version bump is a commit on `development`**, before opening the release PR —
never on a `release/*` branch. v0.1.0 went out from `development → main` and the bump
came back with it; v0.2.0 went out from `release/v0.2.0 → main`, and **`development`
kept saying `0.1.0` in `mix.exs` while production served `0.2.0`**. The
single source of the version asserting what the environment contradicts, and any image
built from `development` would come out with the wrong tag. Discovered in the
back-merge, which separated the false conflict (eight identical files) from the real
difference (one line).

**And the back-merge of `main` into `development` after each release**, resolving
the conflicts in favor of the `development` version. Without it, each release increases the
divergence and the false conflicts grow. With the bump in the right place, the
back-merge becomes mere history convergence — no content
decision. The structural alternative — swapping squash for a merge commit **only**
on the release PR — is an amendment to the constitution 1.7.0 flow, and has not yet been
decided.

---

## L84 — The panel saying `Done` does not mean the application is up {#l84--o-painel-dizer-done-não-significa-aplicação-no-ar}

**Origin**: Sprint 026 (production) · **Type**: technical · **Status**: open

**What happened.** Dokploy marked two deploys as completed while the
container died in a loop.

**Why it happened.** `Done` in the host's panel means "I created the
service", not "the process survived". They are two different statements, and the
interface shows only the first with the word that suggests the second.

**What to do differently.** The proof that the application is up is **always the
measurement from outside** — a request to the public address, with response code and
time. A third-party panel is a hint; measurement is evidence. This holds for any
deployment tool, not only Dokploy.

---

## L85 — An HTTP 200 can assert what the socket contradicts {#l85--um-200-de-http-pode-afirmar-o-que-o-socket-contradiz}

**Origin**: Sprint 026 (production) · **Type**: technical · **Status**: open

**What happened.** With `PHX_HOST` pointing to the panel's host and people
accessing through another address, Phoenix's default `check_origin` refused the
LiveView WebSocket with **403** while the page answered **200**. The log
recorded `_mount_attempts => "79"`. To whoever was looking, it was a loading
bar that never finished.

**Why it happened.** `PHX_HOST` serves to **generate** URLs; the origin accepted on the
socket is **where people come in from**. With a single address, the two coincide and
nobody notices they are different things.

**What to do differently.** Measure the **socket**, not only HTTP: a
LiveView application is only up when the socket connection is accepted. It is the silent
success class in the false-positive direction — the green of one layer asserting what
the layer below contradicts.

---

## L86 — A moving denominator lies just like an invented denominator {#l86--denominador-móvel-mente-igual-a-denominador-inventado}

**Origin**: Sprint 026 (production) · **Type**: technical · **Status**: open

**What happened.** The `/syncs` progress bar showed **100% during the
entire collection**, because the total grew along with what had been collected. It fooled even
the investigation that was looking for why the collection seemed stuck.

**Why it happened.** A percentage presupposes a closed denominator. While
discovery and collection run together, `collected/total` is always ≈1 — and the most
convincing number on the screen is the emptiest.

**What to do differently.** **Without a closed total, a count — never a percentage.**
Showing `1,204 items` tells the truth that `100%` hides. Fixed in PR #642.
This holds for every measure derived from a denominator still being formed — it is the same
family as L70 (a number measured in the middle of a backfill).

---

## L87 — An invisible phase makes work look stuck {#l87--fase-invisível-faz-trabalho-parecer-travado}

**Origin**: Sprint 026 (production) · **Type**: technical · **Status**: open

**What happened.** Board collection runs after promotion and **had no
row on the screen nor a checkpoint**. With the seven visible phases full and the sync still
`running`, the natural conclusion was that it had stalled — when 15 boards and
3,981 items were still to be fetched.

**Why it happened.** The screen enumerated the phases that existed when it was written.
The new phase entered the process and not the enumeration, and absence of a row was read
as absence of work.

**What to do differently.** Every phase of a long process is born with **a row on the screen and
a checkpoint**, in the same commit that creates it. Phase enumeration is the same class as
L80: the instrument that does not see the new phase asserts that it does not exist.

---

## L88 — An 8-second secret, and the contract that saved the diagnosis {#l88--um-segredo-de-8-segundos-e-o-contrato-que-salvou-o-diagnóstico}

**Origin**: Sprint 026 (release v0.1.0) · **Type**: dependency · **Status**: open

**What happened.** The v0.1.0 CD failed because it read `DOKPLOY_WEBHOOK_URL` **eight
seconds before** the secret was created. The contract message was what it should
be — *"the image and the tag exist, but there was NO delivery"* — and because of it
nobody looked for the image in the wrong place. The re-run solved it in 11s.

**Why it happened.** A human milestone and an automatic trigger running in parallel:
the merge triggered the workflow while the person was still registering the secret.

**What to do differently.** No corrective action — the contract already did the right thing, and
the lesson is the **confirmation**: a failure message that separates what happened from what
did not happen is worth the cost of writing it, and pays for itself on the first real failure.
Record it as evidence in favor of the practice, not as a defect to fix.

---

## L89 — A PR without a requested reviewer is not a reviewed PR, and the merge does not know it {#l89--pr-sem-revisor-pedido-não-é-pr-revisado-e-o-merge-não-sabe-disso}

> **Merged into L95 in Sprint 028** — the two halves of the same failure — L89 checks `reviewRequests` **after requesting**, L95 checks `reviews` **before merging**. Separated, each seemed fulfilled on its own.

**Origin**: Sprint 026 (acceptance) · **Type**: process · **Status**: open

**What happened.** Of the sprint's nine PRs, **six were merged without a requested
reviewer** (#635, #637, #638, #639, #640, #642). The first three
(#630, #631, #632) requested review from two people, and **neither reviewed**: `reviews` is empty
in all nine. Nobody noticed during the sprint — the merge does not ask.

**Why it happened.** The production session ran at incident pace, and the
review request is the step that disappears first when the PR is a means to something
else. Principle VII of the constitution requires a reviewer other than whoever
implemented; the tool does not require it, and what only the process requires is what only the
process loses.

**What to do differently.** Check the request **after requesting** —
`gh pr view <n> --json reviewRequests` —, because the request command exits with
code zero even when it requests nobody (L14). And, when there is no possible
reviewer, **write the attestation**: who reviewed, when, and under what condition. The
three situations are different and only one is a review gap: *review recorded*,
*review attested without a record* and *review did not happen*. What this sprint
produced was the third in six PRs, and it cannot be fixed after the merge.

---

## L90 — Counting only the race winner does not prove the loser {#l90--contar-só-o-vencedor-da-corrida-não-prova-o-perdedor}

**Origin**: Sprint 026 (acceptance) · **Type**: technical · **Status**: open

**What happened.** The 052 race test (FR-005) asserted two things:
that there is **one** administrator at the end, and that **exactly one** of the two calls
returned `{:ok, :criada, _}`. Turning off the lost-race read — the
loser starting to return `{:error, changeset}` instead of `{:ok, :ja_existe}` —
**the 16 tests stayed green**. The defect only showed up because the acceptance
injected it.

**Why it happened.** The assertions described the **final state** and the **winner**.
The loser has no effect on the database, so no count reaches it — and it is
precisely the loser that FR-005 promises to serve: on a real second start-up, the
common path is the loser's, and an `{:error, ...}` there would make the boot shout about an
installation that is correct.

**What to do differently.** In every race, **assert both sides**: what the
winner produced and what the loser returned. The rule holds beyond races — it is the
general form of the relator: when a function returns different phases for the same
final state, the test that only looks at the state does not tell the phases apart. It also holds
as a note on injection: the injection that **passes** is the informative one, because it does not
say "the code is right", it says "the test does not see here".

---

## L91 — The cycle step that has no gate is the one that disappears {#l91--o-passo-do-ciclo-que-não-tem-gate-é-o-que-some}

**Origin**: Sprint 026 (closing) · **Type**: process · **Status**: open

**What happened.** Two features in a row — 052 and 054 — ran
`/speckit-specify` → `/speckit-plan` → `/speckit-tasks` → **implementation**,
skipping `/speckit-taskstoissues`. Neither had an issue on GitHub
while the work was happening. Discovered only at the sprint closing, when the
acceptance went looking for the tasks' issues and did not find them.

**Why it happened.** Every earlier step of the cycle **produces a file that the
next step reads**: without `spec.md` there is no plan, without `tasks.md` there is nothing to
implement. `taskstoissues` is the only one that produces something **outside the repository**
— and nothing inside it notices the absence. The gates run over the code; the
`tasks.md` is complete and correct; implementation proceeds. **There is no next
step that trips.**

The cost is not bureaucratic: `flow.wip.count` undercounted sprint 026 while it
ran, and that measure cannot be recovered later. Issues created retroactively
restore traceability, never the time series.

**What to do differently.** Treat `taskstoissues` as **part of the sprint's task T001**,
and not as a loose step: no task starts before its issue
exists. And the check is one line —
`gh issue list --search "<feature>/T in:title"` returning the expected number —,
which fits in the same check in which the gates' exit code is read.

The general form, which holds beyond this cycle: **a process step whose product lives
outside the repository needs explicit checking**, because no gate
reaches it. It is the same family as L57 — a verification that never runs is a verification that
does not exist.

---

## L92 — Squash on a back-merge erases the back-merge {#l92--squash-num-back-merge-apaga-o-back-merge}

> **Closed in Sprint 028** — rule in `AGENTS.md` §12 and a mandatory field in the PR template. The block stays: the rule carries the obligation, and here is the case that produced it.

**Origin**: Sprint 026 (release v0.3.0) · **Type**: process · **Status**: **closed in Sprint 028** — it became a rule in `AGENTS.md` §12 and a mandatory field in the PR template

**What happened.** PR #646 did the back-merge of `main` into `development` — the
action that L83 prescribes — and **was merged by squash**. The content arrived; the
ancestry did not. Two releases later, the v0.3.0 release PR was born
`DIRTY`, conflicting on the **same false files** that #646 had already
resolved: gettext, the 052 `tasks.md`, `bootstrap_test.exs`.

The proof is in the history itself: the v0.1.0 back-merge (`d9c6a57`)
**survived**, because that one was merged with a merge commit. And
`git merge-base main development` kept pointing to `cc4b5f9` — the
v0.1.0 —, as if v0.2.0 had never come back.

**Why it happened.** Squash exists to turn N commits into one, and the price
is **discarding the parents**. In a regular PR that is the desired effect. In a back-merge,
the second parent **is the whole product** — the content was already identical on both
sides. Squashing a back-merge is asking for what it delivers and throwing away what it
does.

What hid the error for one cycle: **the result looked right**. The files
were correct, the gates passed, and nothing showed up until the next release.

**What to do differently.** **A back-merge is merged with a merge commit, never with
squash** — the repository allows all three methods, and the choice belongs to whoever presses the
button. To make this checkable instead of remembered, the back-merge PR is born
saying in its title and body that squash voids it, and carries the two measures that
prove it:

```bash
git diff origin/development          # empty: no content decision
git cat-file -p HEAD | grep -c ^parent   # 2: this is what squash would erase
```

And the check afterwards: `git merge-base main development` must point to the
**latest** release, not the previous one.

---

## L93 — During the deploy, two versions serve, and the outside measurement does not say which one answered {#l93--durante-o-deploy-duas-versões-atendem-e-a-medida-de-fora-não-diz-qual-respondeu}

**Origin**: Sprint 026 (production, feature 054) · **Type**: technical · **Status**: open

**What happened.** Right after a redeploy, three probes to the socket returned
`400 / 400 / 403` — the result that proved feature 054 in production. It was
declared as proof. Minutes later, the container log showed the **same
origin being refused** in the same minute:

```
20:04:54  Access TheBandWeb.Endpoint at https://theband.5.189.161.85.sslip.io
20:05:35  [error] Could not check origin — Origin: https://app.theband.dev
20:10:20  SIGTERM received - shutting down
```

The **old** container was still serving, with the old configuration, and only
died at 20:10. For five minutes both were behind the same
router: each request fell on one or the other, and the measurement became a coin toss. The
repetition after the `SIGTERM` gave `400/400/403` three times in a row — now it counted.

**Why it happened.** Zero-downtime deploy **exists precisely because both
versions coexist**. Whoever measures from outside sees a single address and concludes there is a
single service. The mistake is invisible: the number that comes out is plausible, and it is the number
that was expected.

**What to do differently.** An acceptance measurement **is not taken during the deploy**.
Three ways to avoid it, in order of strength:

1. wait for the old container's `SIGTERM` to appear in the log — it is the only signal that
   says the coexistence is over;
2. check the identity of whoever answered: the boot's `Access TheBandWeb.Endpoint
   at …` line says which configuration is in force;
3. **repeat the measurement until it stabilizes** — a single reading, in a switchover window,
   is not evidence. Two versions produce two answers to the same question.

It is the same family as L70 (a number measured in the middle of a backfill) and L84 (`Done`
in the panel is not the application up): **the instrument is right, it is the moment that
is wrong** — and the result looks good, which is what makes nobody check.

---

## L94 — A message that asserts the cause without checking sends you to look in the wrong place {#l94--mensagem-que-afirma-a-causa-sem-conferir-manda-procurar-no-lugar-errado}

**Origin**: Sprint 027 (production) · **Type**: technical · **Status**: open

**What happened.** The access scopes screen showed
*"Já existe concessão vigente para esse alvo"* ("A grant in force already exists for this target") for **any** changeset
error — a missing required field, an invalid level and a uniqueness violation
all fell into the same sentence:

```elixir
{:error, %Ecto.Changeset{}} ->
  assign(socket, erro: dgettext("errors", "Já existe concessão vigente para esse alvo."))
```

The maintainer tried to grant an organization scope to an account, received
that sentence, and concluded what the sentence says: **that only one person can have a scope per
organization**. It could not be more wrong — the index is
`(tenant_id, user_id, level, target_id)`, and two accounts in the same organization
had been proven by test, in the domain and through the screen.

The diagnosis consumed four measurements — the count in the development database,
the index in the migration, `granted_scopes/2` to see whether the list was hiding something, and the
search for a second index — and **none of them found the cause**, because the
cause never reached the screen. The production capture knocked down both hypotheses that
I had formed from the message itself.

**Why it happened.** The `case` matched the **shape** of the error (`%Ecto.Changeset{}`) and
wrote the most likely **cause**. While the likely cause is the only one, nobody
notices; the day it is a different one, the message lies with conviction — and whoever reads it stops
looking, because they already got an answer.

It is silent success in reverse: instead of an error that does not show up, **an error
that shows up saying something else**.

**What to do differently.** An error shown to someone describes **the observed
situation**, never the presumed constraint. In Ecto, that means checking the
`constraint` in the error's `opts` before naming it:

```elixir
if Enum.any?(errors, fn {_c, {_m, opts}} -> opts[:constraint] == :unique end) do
  # only then, the duplicate sentence
else
  # and here, what the changeset actually said
end
```

The question that separates the two: *"if the cause were different, would this sentence change?"* If
it does not change, it is not describing what happened — it is describing what whoever
wrote it imagined.

---

## L95 — Requesting a reviewer is not getting a review, and the merge does not wait {#l95--pedir-revisor-não-é-obter-revisão-e-o-merge-não-espera}

**Type**: process · **Origin**: Sprint 027 · **Status**: open

**What happened.** The four PRs of feature 055 — #706, #710, #712 and #713 —
were merged into `development` with **2 reviewers requested and 0 reviews** each.
Measured on 2026-09-02 with `gh pr view --json reviews,reviewRequests`.

**Why it happened.** L89 turned requesting a reviewer into a habit, and the habit was
mistaken for the guarantee. Requesting a reviewer is an action of whoever opens the PR; reviewing is an
action of another person, at another moment — and nothing between the two prevents the merge. The
button does not know the difference between "nobody has reviewed yet" and "nobody will review".

**What to do differently.** Before merging, measure: `gh pr view <n> --json
reviews --jq '.reviews|length'`. Zero is a blocker, not an observation. When the
review cannot be obtained, **declare the gap in the sprint review** — which is
what was done here, late.

**Applied in**: Sprint 028 — entry condition for the feature 057 PRs.

### RECURRED — 2026-09-13, sixteen out of sixteen {#reincidiu--2026-09-13-dezesseis-de-dezesseis}

In the v0.8.0 window (v0.7.0 → `0ccf02b`), **16 PRs merged into `development` and 16 without a recorded
review**: `gh pr view --json reviews,reviewRequests` returns `0` and empty for each one. Nine
of them **did not even request** (#853, #857, #860, #863, #864, #865, #889, #907, #908). And on the same day
**eight open PRs** (#909–#916) were born without a reviewer and outside the project — the rule has been in
`AGENTS.md` since #89, and the rule's author violated it eight times in twelve hours. Fixed by hand
at 21:00Z, with the read-back.

The L98 pattern: the lesson exists, the rule exists, and nothing on the way **asks**. `gh pr create`
accepts a PR without a reviewer and prints the URL. **The next measure is not another lesson**: it is a check in
CI, `pr-revisor-pedido`, triggered on `pull_request` (`opened`, `synchronize`,
`review_requested`), which **fails** while `reviewRequests` is empty — the same design
as `pr-tipo-de-merge`, which has already stopped a PR of mine. The check fails on opening and passes when the
request arrives; the merge waits for both.

---

## L96 — An issue nobody closes makes the sprint look undelivered {#l96--issue-que-ninguém-fecha-faz-o-sprint-parecer-não-entregue}

**Type**: process · **Origin**: Sprint 027 · **Status**: open

**What happened.** Thirteen tasks completed and merged, and **zero issues
closed**. On 2026-09-02, anyone looking at the source would see 18 open issues and
conclude that the sprint delivered nothing.

**Why it happened.** Closing depended on the keyword in the PR, which already fails
for three known reasons, and nobody checked afterwards. There is no gate between "the
code is in `development`" and "the issue is closed" — and the step without a gate is the
one that disappears, which is L91 showing up somewhere else.

**Why it is especially costly here.** The platform exists to compute
flow measures from issues. A repository in which the issue does not close
when the work ends produces infinite lead time and zero throughput — about the
very project that measures it.

**What to do differently.** When closing the sprint, `gh issue list --state open` with the
feature prefix **before** writing the review. An open issue whose task is
marked `[x]` in `tasks.md` is a divergence to resolve, not a detail.

**Applied in**: Sprint 028 — it enters the sprint's Definition of Done.

---

## L97 — A feature that fixes the team membership does not fix whoever reads the team membership {#l97--feature-que-corrige-o-vínculo-não-corrige-quem-lê-o-vínculo}

**Type**: technical · **Origin**: Sprint 027 · **Status**: open

**What happened.** Feature 055 delivered `started_at`, `ended_at` and the
invalidation of the team membership, with SC-003 requiring that recording a departure not change the
past. **No measure query started using it.**
`Profiles.TeamSkills` kept reading the evidence that the source lists today — so
whoever left keeps counting, and today's set of members is applied to
past months.

The defect that SC-003 forbids in the team membership was happening in the measure, **in the same
sprint that created the data to avoid it**.

**Why it happened.** The scope was written in terms of *who writes* the team membership
— declare, end, invalidate. Nobody listed *who reads*. New data does not
reach the consumers of the old data on its own, and the search for them does not happen
by chance.

**A second defect, from the same family**, found while planning 057: the in-force
condition uses `started_at <= data`, and `started_at` is nullable on purpose. Against
null the comparison evaluates to unknown and the row is discarded — whoever has an unknown start
date **is not a member on any date**, with no error and no warning.

**What to do differently.** A feature that adds a temporal attribute to a concept
**lists the current consumers** of that concept in `plan.md`, and says for each one
whether it changes or not. A `grep` for the concept's name is the minimum. And every condition
on a nullable column must say explicitly what it does with the null.

**Applied in**: Sprint 028 — US1 and T034 of feature 057 are the fix.

---

## The three squash lessons, closed together — Sprint 028 {#as-três-do-squash-encerradas-juntas--sprint-028}

**L75**, **L83** and **L92** are the same defect seen in three places: squash creates
a **new commit, without the original parents**, and Git loses the information that
that work has already been integrated.

L92 happened **after** L75 and L83 had already been written. That is the finding:
**remembering the lesson at the moment of clicking the button did not work**, and three records
did not prevent the fourth occurrence.

What changed in sprint 028, and why this closes all three:

1. **`AGENTS.md` §12** gained the table of when to use each type — it becomes an obligation
   verifiable in review, and not a reminder;
2. **`.github/pull_request_template.md`** requires the merge type **declared in the
   PR body**, with the reason. Whoever clicks does not need to remember which case this
   PR is: whoever opened it already said.

The difference between reminder and rule is this: the reminder depends on someone remembering
at the worst moment — when their finger is already on the button and the work looks
finished.

**If it recurs anyway**, the next measure is not a fourth lesson: it is
disabling squash in the repository configuration for the cases in which it
destroys, and letting the button offer only what is correct.

### RECURRED — 2026-09-03, and the three are OPEN again {#reincidiu--2026-09-03-e-as-três-voltam-a-estar-abertas}

Release **v0.4.0** entered `main` by **squash**. The count is objective:

```
1b04c53  →  1 pai      v0.4.0, este release
b0fe177  →  2 pais      v0.3.0, feito certo
```

The two layers created in sprint 028 were in place, and neither held:

- `AGENTS.md` §12 had the table, with "release `development` → `main`" =
  **merge commit**, and the reason;
- the template required the declared type, and the body of PR #791 **declared merge
  commit** with the L83 quote inside it.

The divergence came back: `development..main` = 2, `main..development` = 60, with
releases **v0.3.0 and v0.4.0 both without a back-merge**. Undone in PR #793 — four
conflicts, all of content that `development` already had, and the resulting tree
**identical** to it (`git diff --cached origin/development` empty).

**What this teaches, and it is different from the three:** declaring in the PR body is the
third form of reminder, not the first form of guard. A rule in a document,
a field in a template and a reason written by whoever opened it — all three depend on someone
reading at the moment of clicking.

**The measure prescribed above is overdue**, and the configuration today is:

```
allow_merge_commit: true    allow_squash_merge: true    allow_rebase_merge: true
gh api .../branches/main/protection  →  404 Branch not protected
```

Two ways out, and the second costs less: turn off `allow_squash_merge` in the
repository (simple features to `development` lose the squash that
`AGENTS.md` recommends), **or** branch protection on `main` with a merge method per
branch and `quality-gates` required — which solves this **and** the click with CI
pending. The maintainer decided to create the protection on 2026-09-03.

**Until it exists, the three are not closed.**
## L98 — A lesson that does not become a rule recurs in the next sprint {#l98--a-lição-que-não-vira-regra-reincide-no-sprint-seguinte}

**Type**: process · **Origin**: Sprint 028 · **Status**: open

**What happened.** **L95** — requesting a reviewer is not getting a review — was born in
sprint 027 and **recurred in 028**: five PRs merged with zero reviews each.

The same pattern with squash: **L75**, **L83** and **L92**, and the third occurred
after the first two had already been written.

**Why it happened.** The accumulated record is read when **opening** the sprint. The act
that the lesson describes happens weeks later, at the worst possible moment — with the
work looking finished and the finger on the button. Writing the lesson preserves the
reasoning; it does not change behavior.

**What to do differently.** A lesson that describes a **repeatable act** becomes two
things, not one:

1. **a rule in `AGENTS.md`** — an obligation verifiable in review;
2. **a mandatory field in the artifact** where the act happens.

That is what was done with the merge type: `AGENTS.md` §12 plus
`.github/pull_request_template.md`. The accumulated record keeps the **why**; the
artifact carries the **obligation**.

The test to know whether the lesson needs this: *does the error happen at a moment when
nobody is reading lessons?* If so, writing it in the document is not enough.

**Applied in**: Sprint 028 — L92 closed by becoming a rule and a template field.

---

## L99 — Checking issue by issue found what planning did not {#l99--conferir-issue-por-issue-achou-o-que-planejar-não-achou}

**Type**: process · **Origin**: Sprint 028 · **Status**: open

**What happened.** When closing the sprint, `gh issue list --state open` showed that
**T020 and T021 had never been implemented**. The people section had the tasks and
did not have the skills: US4 was half done, with the PR already merged and the
gates green.

**Why it happened.** No gate catches this. Tests prove **what exists**, and
not what was promised — an absent section has no test to fail, and the whole
suite stays green over half of the user story.

The plan had the right tasks; the implementation ran over them when building
the section, and nothing between the two compared one thing with the other.

**What to do differently.** The issue-by-issue check **before** writing the
review is not a formality: it is the only reading that compares what was **promised** with what was
**delivered**. It already entered the sprint DoD because of L96, and in this sprint it
worked in the very sprint that created it.

**Applied in**: Sprint 028 — it found the gap, and PR #762 closed it.

---

## L100 — A documentation branch without a PR makes the code arrive without the spec {#l100--branch-de-documentação-sem-pr-faz-o-código-chegar-sem-a-spec}

**Type**: process · **Origin**: Sprint 028 · **Status**: open

**What happened.** The code PRs were branched from `development`, and the
branch with the spec, the plan, the tasks and the sprint **never had a PR**. The first three
PRs went out without the documents they implemented.

The defect only showed up when a backlog file, written hours earlier, **vanished
from the working tree** — and the search for it revealed six commits stranded on a
branch with no destination.

**Why it happened.** The Spec Kit cycle creates the feature branch and commits the
artifacts on it. Implementation starts with `git checkout development`, and the step
of opening the documents' PR **has no gate** — it is L91 showing up in another
place in the same cycle.

**What to do differently.** When branching to implement, check that the source
branch **is already in `development`**:

```bash
git log development..<branch-da-spec>   # empty = already merged
```

One line answers it. If it is not empty, open its PR **before** starting to
implement — the code PRs depend on those documents to be reviewable.

**Applied in**: Sprint 028 — fixed with PR #760, opened late.

---

## L101 — An issue closed at integration makes a claim about production {#l101--issue-fechada-na-integração-afirma-sobre-a-produção}

**Sprint 029** · process

GitHub's closing keyword fires when the PR enters the **default branch** —
`development`. Production is `main`. Between the two there is a release, and in the interval
the issue is **closed** with the code **not live**.

**What happened.** On 2026-09-03 the two PRs went in out of order, by
fifteen seconds:

```
#791  release v0.4.0   mergeado 13:25:52Z
#792  a FR-012 do 055  mergeado 13:26:07Z
```

v0.4.0 went up **without** T014. Checked at the source, and not through the PR:
`membership_disagreements` does not exist on `main`, it exists on `development`.

**Why it is a defect and not a mishap.** In isolation, code missing from a release is
trivial — it goes out in the next one. The defect is the **combination of two true signals**
that together assert something false: issue #700 is closed, release v0.4.0 is
published with a tag and a green CD, and whoever checks the delivery through the issue concludes that
FR-012 is met in production. The live screen still does not mark the disagreement
between collection and declaration.

Nobody lied and no step failed. It is the family of
[silent success](#o-defeito-que-não-produz-erro): absence of error read as a
result, now on the border between integration and production.

**Why the order was declared and was not enough.** The body of PR #791 carried the
numbered order, with step 1 being "#792 goes in first" and the reason written. Two
PRs ready at the same time, and both buttons green — the order existed in the
document, not in the mechanism. It is the same shape as the squash recurrence on the same
day, and that is why both point to the same measure.

**What to do differently.**

1. **Check on `main`, never on the issue**, if the question is "is it in production":

   ```bash
   git grep -c '<símbolo novo>' origin/main -- lib   # 0 = not live
   ```

2. **When two PRs have an order between them, one of them should not be mergeable.**
   Keeping the release in **draft** until the dependent one goes in turns the order into a
   mechanism, and costs one click;
3. **The issue that closes at integration makes no claim about production**, and the body of the
   release PR is the only place where that difference is recorded. While the
   release has not gone out, a closed issue is a promise, not a delivery.

**Applied in**: Sprint 029 — T014 was left out of v0.4.0, and #700 closed
while production does not have it.

---

## L102 — `git add -A` on a tree shared by agents commits other people's work {#l102--git-add--a-numa-árvore-compartilhada-por-agentes-commita-o-trabalho-dos-outros}

**Type**: process · **Origin**: 2026-09-09 · **Status**: open

**What happened.** Commit `5d02075` said it changed three files — the
MkDocs workflow, `mkdocs.yml` and `docs/README.md` — and it changed six. It took with it **1,450
lines from two other roles** working on the same tree at the same time:

| file | lines | whose |
|---|---:|---|
| `docs/seguranca/2026-09-09-api-com-token.md` | +1,220 | Security, in progress |
| `docs/releases/v0.6.0.md` | +230 | Product Owner, in progress |
| `deps` | −1 | removal of a symbolic link, a separate decision |

The PR body described the three. **Whoever reviewed by the body would approve 1,450 lines
that nobody presented** — and the Security role later reported that its document was
dragged into someone else's commit and, when that commit was undone, **deleted from disk
and from history**. It recovered from its own copy.

**Why it happened.** `git add -A` stages everything that changed in the tree, and the tree is not
mine alone when there are subagents in parallel. The command does not distinguish my work
from another role's work — and there is no warning: `git status` shows the files, and
whoever already knows what they did does not read them.

No gate catches it. The suite passes, Credo passes, formatting passes — the PR is
**technically correct and materially dishonest**.

**What to do differently.**

1. **Explicit paths in `git add`**, whenever there is an agent in parallel:
   `git add lib/x.ex test/x_test.exs`. Never `-A`, never `.`;
2. **Check `git show --stat` before pushing**, and compare it with what the PR
   body promises. One extra file is a signal, not a detail;
3. **Whoever delegates to a subagent that writes to the tree takes on the risk of collision** — and the
   way to eliminate it is to give each one its own worktree, not to trust the discipline of
   `add`.

**The relation to L95.** Independent review would have caught this, and there was none. But the lesson
is not "ask for review": it is that **the commit must tell the truth about itself before
anyone reviews it**, because review by the PR body is the one that actually happens.

**Applied in**: 2026-09-09 — the commit was redone with the three files, and the removal
of the symbolic link became its own PR (#836), with the reason written.

---

## L103 {#l103}

**The prototype is not part of the project. It is the drawing used to build it.**

**Where it appeared.** 2026-09-10. I ran the design checker on the whole repository, found
**262** problems, fixed them all and presented the result as product quality. The 262
were **entirely** in the five HTML prototype files. The product code — `lib` and
`assets` — had **zero** from the start.

Later, with the tool running in full, the same five files gave **1,606**. And the
breakdown says it all:

| family | how many | whose property it is |
|---|---|---|
| contrast, small text, all caps, tight spacing | **1,560** | the **delivered screen**'s — and what delivers the screen is the code |
| color outside the palette, accent border | 46 | and even there: the `--s1/--s2/--s3` colors are colors the product **decided not to have**, with the decision written in `teams_live/show.ex`; the rest is dark-theme tokens measured against the light palette |

**Why the confusion is easy to make.** The prototype is HTML, has CSS, opens in the browser and
looks like a screen. The tool treats it as a screen because that is what it looks like. And the number that comes out
of it is large, which gives the feeling of useful work.

**Why the number misleads.** The prototype exists for one thing: **to be the yardstick against which the
code is checked**. The yardstick does not need accessible contrast — it needs to say, without
ambiguity, what the screen has to do. A prototype with 10px text and 3:1 contrast can be
a perfect yardstick, and an unacceptable screen. The two statements are about different objects.

**What to do differently.**

1. **The design gate is the product code** — `lib` and `assets`. The prototype is exempt, and the exemption
   is written in `.impeccable/config.json` with the reason, not as a convenience;
2. **agreement between prototype and code is checked by people**, not by a tool: QA
   reads the implemented screen against section 3 of the prototype's `PROMPT.md`, item by item. It is the method
   this house already declares, and it does not delegate to any detector;
3. **what is worth preserving in the prototype is the SYSTEM, not the quality** — the type ramp, the
   radii, the absence of an accent border. Because the code reproduces the prototype: if the prototype
   uses thirty-four font sizes, the code ends up using thirty-four. That
   fix was useful for that reason, and not for the one I gave.

**The part of the wrong work that is still true.** The 34 font scales and the 3–4px
colored borders **were** real drift, and fixing them kept prototype and code in the same
system. What was wrong was the announced conclusion — *"repository quality went from 262
to zero"* —, not the fix.

---

## L104 {#l104}

**I silenced the tool's warning and called an undercount an attestation.**

**Where it appeared.** 2026-09-10, in the same session as L103. The design checker needs
four libraries to evaluate color, contrast and interface text size. On this machine
they were not installed, and it printed, **on every run**:

```
impeccable detect: DEGRADED - HTML parser modules unavailable.
Falling back to regex matching. Custom properties, selector matching and computed contrast
are NOT evaluated; findings are an undercount, not a clean bill of health.
```

I ran every command with `2>/dev/null`, because the error output carried compilation
noise. **The warning was there every time, and I threw it in the trash every time.** Then
I wrote *"0 findings"* in three messages, in a commit and in two PR bodies.

With the four libraries installed: **1,606** findings where I had announced zero.

**Why no gate caught it.** The exit code was **0** — legitimately, because no
evaluable rule failed. The tool did not lie about anything: it said exactly what it was not
doing, on the channel I erased. The defect is entirely mine, and it is the opposite of what it seems: it was not
missing information, it was missing not discarding it.

**The relation to silent success.** It is the same family — absence of error read as a
result —, with an aggravating factor: here there **was** an explicit warning, written in plain English,
saying *"not a clean bill of health"*. I built the silence.

**What to do differently.**

1. **Never `2>/dev/null` on a verdict tool.** If the error output has noise, filter the
   noise (`grep -v`), not the channel. The channel is where the tool warns that it is not working;
2. **provisioning the tool is part of the gate.** The four libraries now have a
   `package.json` in `.claude/skills/impeccable/`, with the reason written — a tool that runs
   blind for lack of a dependency is a gate that approves by not looking.

   And the provisioning went into **`make setup`**, not into the documentation: `node_modules` is ignored
   by git, like every `node_modules`, so **each worktree needs to install once**. This
   project had five worktrees open that day, and four stayed blind after the
   fix in the first. The `detector-provisiona` target installs **and checks**, failing if
   `DEGRADED` persists — provisioning that lives only in a document is the kind nobody runs;
3. **"0 findings" is only written with the mode confirmed.** Without that, the sentence is *"0 of the
   evaluable rules, with the checker in reduced mode"* — and that sentence, written down, would have made
   any reader ask which rules were left out.

**The relation to L23.** That lesson says: *a warning of a skipped check is a failure, not an
observation*. It has been written in this file since before, about the knowledge base's Python
validator. I repeated it from the other side — not by ignoring the warning, but **by erasing it before it
could be ignored**.

---

## L105 {#l105}

**The secret reached the text without anyone logging it — and my first test did not reproduce that.**

**Where it appeared.** 2026-09-12. A GitHub access token was left in plaintext inside
[redigido] for [redigido]. No line of code logged it:
there is no `Logger.error(token)` anywhere, and the credential schema's `redact: true` was
there, working, protecting the struct's `inspect`.

**The mechanism.** The token was the second argument of `Client.graphql/5`, a bare `binary`. When the
error arises from **the call itself** — no clause matched —, the virtual machine keeps the list
of arguments in the stack frame. `Exception.format/3` calls `inspect/1` on each one, and the
job runner stores the resulting text. The shape in the database was exactly:

```
graphql("https://github.com", "<40 caracteres>", "# As linhas de ...")
```

**What almost fooled me.** I wrote the test first, as always, and it **failed on
reinjection**: with a bare binary on the same path, the secret did not show up. I was about to treat
that as test noise.

It was information. My test used `raise` inside the function body, and **`raise` does not put the
arguments in the stack frame** — the capture only happens when the error comes from the call itself
(`FunctionClauseError`, `badarg`, `badarith`). A ten-line probe separated the two cases:
with `raise`, the frame shows `Sonda.graphql/3` and nothing else; with a clause that does not match, it shows
the three arguments in full.

If I had adjusted the test to pass instead of asking why it failed, I would have
written a protection against a mechanism that was not the mechanism.

**The rule.** *When reinjection does not reproduce the defect, what is wrong is my hypothesis about the
defect, not the test.* Reinjecting exists to answer **"does the test see it?"** — and the answer
"no" is the more valuable of the two, because it says I was aiming at the wrong place. Adjusting the
test until it passes turns that answer into silence.

**The corollary about secrets.** Forbidding *logging* a secret protects nothing: the value reaches
the text through a path that no code review looking for log calls would find.
The prohibition has to come from the **type** — a value that, asked for its textual form, answers
with a marker. That is what `TheBand.Segredo` does, and it is FR-006 of spec 064.

**The corollary about cleanup.** Redacting the row reaches [redigido]. It does not reach [redigido]. **Only rotation invalidates a value that was readable** —
and treating cleanup as resolution is the same family as L104: calling an attestation what is merely
what I managed to reach.

---

## L106 — The check ran, gave the right answer, and nobody read it {#l106--a-verificação-rodou-deu-a-resposta-certa-e-ninguém-a-leu}

**Type**: process · **Origin**: Sprint 030 (2026-09-13) · **Status**: open

**What happened.** Twice in two days, in both directions.

On 2026-09-13, the v0.8.0 bump: the `sed` matched `version: "0.7.0"$` with an end-of-line
anchor, and the real line ends in a comma. The verification `grep` was **in the same command**,
showed `0.7.0`, and the commit went out saying the version had changed. The check ran, gave
the right answer, and nobody read it — the next command did not depend on it.

On 2026-09-14, a merge conflict resolved by script: the python `assert` **failed**
(the other side of the conflict was a different line), python exited with 1 — and the `git add && git commit`
that came after the heredoc, in the same command, ran anyway. `README.md` was committed
**with the `<<<<<<<` markers**. Local; amended before pushing.

**Why it happened.** In both cases the check existed and was right. What was missing was the
**dependency**: the next step did not wait for the verdict. An informative `grep` prints and
moves on; a `python3 - <<'PY' … PY` followed by a newline is another command, and its exit is lost.
It is the silent success family with an aggravating factor — here the warning was produced, and the flow
ran over it.

**What to do differently.**

1. **the check is a command that fails**, not one that prints: `grep -q` with `|| exit 1`,
   `test "$c" = "0" || exit 1`, `set -e` at the top of every editing script;
2. **check the final artifact, not the step**: before a merge `git commit`,
   `grep -c '^<<<<<<<'` equal to zero; before committing a bump, `grep 'version: "'` **read**;
3. step 5 of the `/release` skill already says "read the output before moving on". It was not enough; that is why
   item 1 turns the reading into a block.

---

## L107 — `git log --merges` counts half the PRs {#l107--git-log---merges-conta-metade-dos-prs}

**Type**: technical · **Origin**: Sprint 030 (2026-09-13) · **Status**: open

**What happened.** When evaluating v0.8.0, I counted the PRs between `main` and `development` with
`git log --merges`: **10**. There were **15** at that moment, and **16** by the end of the day. The
Product Owner role, ratifying, found the missing ones.

**Why it happened.** A squash merge **leaves no merge commit** — it leaves a regular commit with
`(#NNN)` in the subject. In this repository half the PRs go in by squash (by rule: a branch that
dies on merge), so `--merges` sees only the other half. The number looked complete and did not say
it was not — the family of L40 and L70.

**What to do differently.** Count PRs with `git log origin/main..origin/development
--format='%s' | grep -oE '\(#[0-9]+\)|#[0-9]+ from'`, and **cross-check** with
`gh pr list --state merged --base development` over the same interval. Two paths that must
give the same set; if they do not, one of them is losing something. It is in step 2 of the `/release` skill.

---

## L108 — Three features in a row without a sprint backlog, and acceptance with no place to live {#l108--três-features-seguidas-sem-sprint-backlog-e-a-aceitação-sem-lugar}

**Type**: process · **Origin**: Sprint 032 (2026-09-13) · **Status**: open

**What happened.** Features **060**, **064** and **065** went from spec to implementation without a
`sprint-backlog.md`. The skill is "mandatory before implementing" and is in the
`AGENTS.md` cycle — and it did not run three times in a row. Consequences measured on 2026-09-13:

- **060 has no issue at all** — no epic, no user story, no task; 29 tasks
  executed with no trace on the board;
- the **40 issues** of 064 and 065 existed with labels and **no type, no hierarchy, outside the
  project, no iteration**;
- the **065 acceptance** was born as an **issue comment**, because there was no
  `docs/sprints/NNN/aceitacao.md` to live in;
- **none of the four visible deliverables of v0.8.0** had a recorded phase when the release
  was evaluated — the latest `aceitacao.md` was sprint 026's.

Sprints 030, 031 and 032 were written **afterwards**, on 2026-09-13/14, and say so at the top.
The adherence analysis between plan and execution — the reason the backlog exists separately from the
review — **cannot be done** for them.

**Why it happened.** It is L98 again: a lesson that does not become a rule recurs. The obligation lives
in a skill and in a sentence of `AGENTS.md`; nothing on the path `feat/*` → PR → merge **asks**
for the sprint. 052 had already gone through without issues in sprint 026, and the gap was recorded as a
gap — not as a mechanism.

**What to do differently.**

1. **a mechanism, not another lesson**: the PR template gains the **`Sprint:`** field (the
   `docs/sprints/NNN` folder), mandatory on a PR whose title starts with `feat`; the gate that already reads the
   PR body (`pr-tipo-de-merge`) refuses when it is missing. Whoever opens the PR without a sprint is stopped at the
   moment when it is still possible to open one;
2. **`/speckit-taskstoissues` and `/sprint-backlog` are a single step** — a task without an issue does not
   enter a backlog, and a backlog without issues does not exist. 060 showed that it is possible to skip both;
3. creating issues retroactively (as with 052) **does not fix** what the gap cost —
   `flow.wip.count` undercounted three sprints. It recovers traceability from here on, and nothing more.

---

## L109 — A task closed "without code" with the spec's criterion intact {#l109--tarefa-fechada-sem-código-com-o-critério-da-spec-intacto}

**Type**: process · **Origin**: Sprint 032 (2026-09-13) · **Status**: open

**What happened.** Tasks T011 and T012 of 065 (US2 — the claim next to the verdict)
were closed in PR #907 **without code**, with the justification that the divergence "already shows
per row in the main table". The acceptance measured: the row shows both sides and **does not say that they
diverge nor which one was followed** — AC1(b), AC3 and SC-008 of the spec, as written, are not met.
The criterion had not changed; the task was redefined until it fit what existed.

060 has the same mark, seen in the retroactive acceptance of 2026-09-14: **T029** is marked
`[x]` with the task's own text confessing ("Aberto ainda", "Still open") that the *Squads at a
glance* card diverges from the prototype; **T010, T011 and T012** are marked `[x]` without the three
promised test files existing. Marking `[x]` is a manual marking of "done" — exactly what
`sro.rule03` forbids for acceptance.

**Why it happened.** Closing a task is an act of whoever implements, and whoever implements reads the criterion
with the code in front of them. "It already exists" is the cheapest conclusion, and nobody between the closing and the
acceptance checked the criterion **as written**. The task's phase was read as `done` when it
was `performed without success`.

**What to do differently.** Closing a task without code requires, **in the same PR**, one of two things:
the **spec amendment** (the criterion changed, and why is written down), or the **evidence of the criterion
as written** (test, HTML, data). Without one of the two, the phase is
`sro.non_successfully_performed_scrum_development_task` and the issue **does not close** — it stays open
with the reason. The Product Owner role starts looking, in every acceptance, for tasks closed
without a diff.

---

## L110 — The spec used the mechanism's word with another meaning, and the example was never looked up in the data {#l110--a-spec-usou-a-palavra-do-mecanismo-com-outro-sentido-e-o-exemplo-nunca-foi-olhado-no-dado}

**Type**: knowledge · **Origin**: Sprint 032 (2026-09-13) · **Status**: open

**What happened.** US2 of 065 talks about a "rótulo" ("label") — the GitHub *label* — next to the
platform's "verdict", and chooses as its example the Bot issue: label `task`, derived concept
*defect*. The divergence mechanism that the US intended to use (`ConceptLabel`,
`list_divergences/2`) calls "label" the **declared type** (`issue_type`), and divergence there is
*declared type × structure*. The example issue has `divergence_kind: nil`: **for the platform
it is not a divergence**. Among the tenant's 512 real divergences, none is of the kind the US
describes; `label_vs_structure` exists in the code and is never produced.

**Why it happened.** Two things, and both were cheap to avoid. The spec named an
existing mechanism without citing the module — and the word it uses had another meaning. And the
US example was written **without a single query** to its record: one line of SQL would have
shown the `nil`. It is L30 inside the spec: asserting about the data without looking at the data.

**What to do differently.**

1. **when the US cites a real example, `research.md` brings its record** — the row, with
   the fields the US uses. An example that the platform classifies differently from what the US assumes is a
   spec finding, not an implementation finding;
2. **when the spec names a concept that already exists in the code, it cites the module** and confirms the
   meaning of the word there. "Label" in this repository already meant something before 065;
3. `/speckit-clarify` starts asking, for every US with an example: *"was this example
   looked up in the data?"*.
