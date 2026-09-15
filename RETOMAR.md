# Retomar — estado em 2026-09-14, a v0.8.0 preparada e três sprints registrados depois do fato

**Este é o único documento de estado.** `docs/sprints/RETOMAR.md` aponta para cá (AGENTS.md §5).

Escrito para a sessão seguinte começar trabalhando, não reconstruindo contexto.

---

## Onde parei, em uma frase

**A v0.8.0 está avaliada, ratificada pelo papel de Product Owner e à espera de dois merges**
— o bump (#916, `chore/release-v0.8.0 → development`) e depois o PR de release
(`development → main`, que ainda não existe e é `/release --executar`). A 065 tem as três user
stories com veredito **proposto** nas issues: US1 e US2 **não aceitas**, US3 aceita pendente de
confirmação. Sete PRs de docs (#909–#915) estão verdes esperando revisão.

## O primeiro comando

```bash
git fetch origin --prune && git status --short     # 1. NADA fora de commit — antes de tudo
git checkout development && git pull
mix gates                                          # o veredito é o CÓDIGO DE SAÍDA, e nada depois dele
```

O CI estava verde em `development` em `0ccf02b` (run 34779226200) em 2026-09-13. A contagem
"16 gates, 2149 testes" **não foi remedida** hoje — o servidor dev estava de pé na porta 4000 e
a suíte com ele fica inviável. Se ainda estiver: `pgrep -fl phx.server`.

---

## O que está no ar

A **v0.7.0** (`dd4272f`, 2026-09-10). **`GET https://app.theband.dev/version` devolve 404** —
a produção não sabe dizer que versão serve. O endpoint existe em `development` desde o #859 e
sobe com a v0.8.0; o CD passa a **falhar** se a produção responder outra versão.

### Em `development` e ainda não em produção — 16 PRs desde a v0.7.0

Medidos por `git log origin/main..origin/development` lendo `(#NNN)` (squash) e `#NNN from`
(merge commit) — **`--merges` perde metade**. Funcionalidade visível: **#853** conta desativada
conforme o protótipo, **#860** aba Flow per person, **#863** vincular pessoa a equipe (FR-003 da
055, o achado de 2026-09-10 — fechado), **#907** rótulos no item. Segurança: **#864**
`TheBand.Segredo`, **#859** `/version` + verificação no CD (H7, H8). Processo: **#889**
constituição 1.8.0, **#861** MinIO como destino do ensaio, **#856** back-merge da v0.7.0,
#854, #855, #857 (subequipe numa transação — o defeito *a* de 2026-09-10, fechado), #858,
#862, #865, #908. Lista completa em `docs/releases/v0.8.0.md`, na branch do #916.

---

## O que fazer, em ordem

### 1. A release — e a decisão que ela pede

1. **Mergear o #916** (squash, por comando: `gh pr merge 916 --squash`). Leva `mix.exs` a
   0.8.0, `docs/releases/v0.8.0.md` com o veredito do PO, o agente `aceitacao-em-producao`, o
   §6 do runbook exercitado de ponta a ponta (260 MB → MinIO em 16 partes → restaurado, sha256
   igual) e as `MINIO_*` declaradas opcionais;
2. **`/release --executar`** (skill no #910 — se ainda não mergeado, o procedimento é a seção
   *Como executar* do doc da release): PR `development → main`, **merge commit**, nunca squash.
   **Não criar a tag** — o CD a cria e reprova se ela já existir;
3. **A decisão que só a pessoa mantenedora toma (FR-016):** o #907 embarca com a **US1 não
   aceita** e a **US2 conceitualmente errada**, e o #853 é retrabalho da D06 recusada na v0.7.0
   **sem reavaliação do papel**. Ou embarca como **exceção nomeada** (como v0.4.0 e v0.5.0), com
   a página da aplicação não anunciando o que não foi aceito — ou aceita-se antes;
4. **Depois do deploy, a primeira medida é sempre**
   `curl -s https://app.theband.dev/version`. Depois `deploy-producao` (plataforma) e
   `aceitacao-em-producao` (o que quem usa vê) — são medidas diferentes.

### 2. Os vereditos — confirmar ou recusar (PR #918)

**Doze fases propostas esperam a pessoa alocada ao papel**: nove no sprint 030 (060 e a
herança) e três no 032 (065). Registro em `docs/sprints/030-a-tela-da-equipe-por-vinculo/aceitacao.md`
e `docs/sprints/032-rotulos-no-item/aceitacao.md`.

| Sprint 030 | fase proposta | o que fecha |
|---|---|---|
| 060/US4 · #857 subequipe numa transação | **aceitos** | — |
| 060/US2, US3, US5 | não aceitas — **critério não medido** | medir na confirmação (SC-013 cronometrado; AC2 decidida; SC-005/FR-081 com duas equipes) |
| 060/US1 | não aceita — três testes prometidos **não existem** (T010–T012 marcadas `[x]`) | tarefa nova; a sonda do papel é o esqueleto |
| 060/US9 | não aceita — **defeito**: cartão *Squads at a glance* ≠ protótipo (T029 confessa) | Design antes; depois o cartão |
| #853 (D06 refeito) | não aceito — os 5 pontos da v0.7.0 **fecharam**; restam 4 cláusulas sem teste e a conferência do QA | quatro testes + §3 com captura; a 045 declara a US que falta |
| #863 (FR-003 com tela) | não aceito — o README do protótipo diz **"aprovação pendente"**, o código diz "aprovado"; §3.4/§3.7 furadas; recusa em **português** no flash | P1–P3 respondidas → republicação → §3 → catálogo → testes → QA |
| #860 (aba *Flow per person*) | **não avaliado** — não é T026–T029; é US10–US12 da extensão, **sem tarefa** | registro próprio depois do #913 |

#### Os vereditos da 065 (sprint 032)

Propostos pelo papel em 2026-09-13, com evidência executada, nos comentários de
[#904](https://github.com/The-Band-Solution/theband/issues/904),
[#905](https://github.com/The-Band-Solution/theband/issues/905) e
[#906](https://github.com/The-Band-Solution/theband/issues/906). **Nenhuma fechada** — a
aceitação é ato da pessoa alocada ao papel.

| US | veredito proposto | por quê | destino proposto |
|---|---|---|---|
| **US1** rótulos na lista | **não aceita** | a listagem cumpre; o campo `labels` do **detalhe** (`work_item_live/show.ex`) mostra só o observado, sem origem e sem o derivado — e nenhum dos três protótipos cobre esse campo | próximo sprint, em primeiro: protótipo do campo **antes** do código; testes de tela devidos (T005, T007, T012); decisão sobre as **47 variantes de caixa** |
| **US2** alegação ao lado do veredito | **não aceita** | "rótulo" na spec é o label do GitHub; "label" no mecanismo de divergência é o **tipo declarado**. A plataforma **nunca produz** `label_vs_structure` — as 512 divergências reais são todas `user_story_without_parts`. A tela mostra os dois lados e não diz que divergem nem qual foi seguido | **product backlog**, até três decisões (abaixo) |
| **US3** rótulo nunca vira conceito | **aceita** | 8 de 8 critérios conformes, `prefixo_vira_rotulo_test.exs` 9 passed | fechar **depois** da confirmação e da revisão pós-merge do #907 (ou atestado datado com exceção) |

Mais três coisas que a avaliação achou: **SC-002 não reproduz** — a spec diz 1 519 issues com
prefixo, a função entregue mede **1 489** sobre os 5 033 títulos reais (`[backend]`, `[DADOS]`,
`[DevOps]`… não derivam: comparação sensível a caixa, coerente com o catálogo); **cinco arquivos
de teste prometidos no `tasks.md` não existem** (`prefixos_test.exs`, os de tela de T005/T007/T012,
`divergencia_com_rotulo_test.exs`); e **não há `prototipo/PROMPT.md` nem item em `docs/backlog/`**
para a 065 — a T013 leu código, não tela, e foi feita por quem implementou.

**T014 (#903) está fechada** com a evidência do CI; a caixa em `tasks.md` foi marcada neste PR.

### 3. Sete PRs de docs esperando revisão

Todos verdes, todos com revisor `the-band` pedido e no projeto (feito em 2026-09-13 — tinham
nascido sem, os oito, contra a regra do `AGENTS.md`):

| PR | o quê | pede decisão? |
|---|---|---|
| #909 | 17 specs sem issue — decidido **não** preencher | não |
| #910 | fluxo de release ponta a ponta + skill `/release` | não |
| #911 | paridade compose–Dokploy | **sim** — bloqueada em decisão |
| #912 | superfície de risco do destino de backup em segundo host | não |
| #913 | requisitos da aba Flow per person, transcritos do protótipo | não |
| #914 | MinIO como destino de **produção**, e a chave mestra que não viaja no dump | **sim** |
| #915 | protótipo do vínculo declarado e os requisitos que gerou | não |

### 4. A spec 064 — segredo em repouso

**O token de sessão continua em claro no banco** (`users.session_token`, `character varying`).
22 issues abertas (T001–T019, US1–US3) mais o épico #888. A rotação do token `…omAX` foi adiada
para **2026-10-12**; ele esteve legível de 2026-09-04 a 2026-09-12. O objeto no balde do MinIO
tem o banco de desenvolvimento inteiro com dois tokens de sessão em claro.

### 5. Limpeza local — o classificador negou apagar

Branches redundantes: `065-divergencias` (idêntica a `origin/docs/specs-antigas-sem-issue`) e
`docs/065-escopo-reescrito` (mergeada). Worktrees limpos de branches mergeadas: `theband-api`,
`theband-docs`, `theband-fluxo`, `theband-fr041`, `theband-modelos`, `theband-release`,
`theband-subequipe`, `theband-t001`, `theband-vinculo`. Comandos na seção *Comandos*.

**Não tocar em `theband-relnote`**: `docs/releases/v0.6.0.md` modificado sem commit (461+/169−),
sem PR — reescrita da nota da v0.6.0 que ninguém decidiu. Olhar antes.

### 6. O que sobra de 2026-09-10

- **a reavaliação da D06** (#853) — ato do papel, ainda não feito;
- **revisão pós-merge**: 21 PRs da v0.7.0 e 16 da v0.8.0 sem revisão registrada. A API não
  aceita pedido em PR mergeado — é **resíduo**; o que se recupera é o atestado datado;
- **segurança**: H9 (`ssl: true`, depende da topologia — pergunta para quem opera), H13
  (`PHX_HOST` com fallback), H5, H10, H11, H14–H16. H7 e H8 fecham com a v0.8.0.

---

## Features especificadas e sem código

| spec | o que é |
|---|---|
| **061** | API pública com token — bloqueia *"conta desativada não autentica por token"* |
| **062** | MCP |
| **063** | issue ausente da origem (estado `deleted`) |
| **064** | segredo em repouso — **em curso**, só `TheBand.Segredo` e a redação entregues |

Issues abertas que pesam: **#397** (equipe composta por equipes), **#568** (marca de
administrador com guarda do último), **#801** (Oban pode parar sem erro), **#802**
(OpenTelemetry), **#621** (050/US2: os dados sobrevivem — a evidência do §6 está no #916;
a aceitação é do papel).

---

## Decisões esperando a pessoa mantenedora

1. **A exceção da release** (seção 1.3) — embarcar sem aceitação registrada, ou aceitar antes;
2. **US2 da 065**: rótulo × conceito é divergência que a plataforma computa? a linha diz qual
   lado seguiu? "no label" basta para a AC2?
3. **As 47 variantes de caixa** do prefixo — manter sensível a caixa e corrigir o SC-002 para
   1 489 (recomendado), ou normalizar;
4. **MinIO em produção** (#914) e a paridade compose–Dokploy (#911);
5. **H9** — a topologia do banco decide se `ssl: true` entra;
6. Sem resposta registrada desde 2026-09-10: instalar `puppeteer`; o *eyebrow* mono;
   sucessor de quem sai como campo; desabilitar o *rebase merge* no repositório.

---

## O que este ciclo ensinou

1. **A verificação rodou, deu a resposta certa, e ninguém a leu.** O `sed` do bump casava
   `"0.7.0"$` e a linha termina em vírgula; o `grep` na mesma saída mostrou `0.7.0`; o commit
   saiu dizendo que a versão tinha mudado. **Ler a saída é o passo**, não rodar o comando.
2. **`git log --merges` perde os squash.** Contei 10 PRs; eram 15, depois 16. Ler `(#NNN)`.
3. **Oito PRs abertos no mesmo dia sem revisor e fora do projeto** — a regra existe desde o
   #89 e está no `AGENTS.md`. Reincidiu porque `gh pr create` não a exige. Conferir com
   `gh pr view <n> --json reviewRequests,projectItems` **ao abrir**.
4. **"Criar a tag depois do merge" reprovaria o próprio deploy.** O CD cria a tag e falha
   nomeando se ela já existir. O doc da release mandava criá-la à mão; corrigido.
5. **O agente de Product Owner travou uma vez (600s) e escreveu na segunda.** A avaliação
   direta é ponte, e o documento **diz** que foi feita assim — quatro afirmações dela estavam
   erradas, e foi o papel que as pegou.
6. **`sprint-backlog` não rodou para 060, 064 e 065.** Os sprints **030, 031 e 032** foram
   escritos depois, em 2026-09-13/14 (PR **#918**), e dizem isso no topo: backlog, review e
   aceitação **proposta** pelo papel. O que a aceitação achou está lá — e pede confirmação (L108).

---

## Comandos

```bash
set -a; . ./.env >/dev/null 2>&1; set +a   # segredos, sem imprimir
mix gates                                  # a definição única de verde
gh pr checks <n>                           # o veredito da CI
gh pr view <n> --json reviewRequests,projectItems   # vazio = a regra foi violada
curl -s -o /dev/null -w '%{http_code}' https://app.theband.dev/version   # 404 até a v0.8.0

# revisor e projeto, para PR que nasceu sem
gh api -X POST repos/The-Band-Solution/theband/pulls/<n>/requested_reviewers -f 'team_reviewers[]=the-band'
gh project item-add 2 --owner The-Band-Solution --url <url do PR>
# Status: PVTSSF_lADODHSRm84BAAnTzgy8XSQ, In review = aba860b9 · Iteration: PVTIF_lADODHSRm84BAAnTzgy8XUE

# limpeza negada ao agente
git branch -D 065-divergencias docs/065-escopo-reescrito
for wt in theband-api theband-docs theband-fluxo theband-fr041 theband-modelos theband-release theband-subequipe theband-t001 theband-vinculo; do git worktree remove "/Users/paulossjunior/projects/$wt"; done
```

## Referências

- `docs/releases/v0.8.0.md` (no #916) — a avaliação, o veredito do PO, e *Como executar*
- `docs/producao/fluxo-de-release.md` e `.claude/skills/release/SKILL.md` (no #910)
- `.claude/agents/aceitacao-em-producao.md` (no #916) — quem mede a funcionalidade no ar
- `docs/seguranca/2026-09-13-o-caminho-completo-do-backup.md` (no #916) — o §6 exercitado
- `docs/seguranca/2026-09-09-o-que-consertar-agora.md` — os 16 achados
- `specs/065-rotulos-no-item/` — spec, plan, tasks, research; protótipos linkados no #903
