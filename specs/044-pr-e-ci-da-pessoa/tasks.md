# Tasks: Os três papéis na solicitação de mudança, e a verificação do commit

**Feature**: 044 · **Spec**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md)

**Feature branch**: `044-pr-e-ci-da-pessoa`

---

## O que esta feature NÃO tem

Não há fase de coleta, migração ou modelo. **O dado já está no banco** — 5.635
solicitações, 4.233 avaliações com 4.127 pessoas identificadas, 15.671 execuções de
verificação. Toda tarefa aqui é de **leitura e tela**.

Duas versões anteriores da spec planejaram coletar o que já era coletado. O registro está
em `research.md` R1, e o que ele custou foi tempo.

---

## Phase 1: Setup

Nenhuma. A feature não acrescenta dependência, arquivo de configuração nem migração.

---

## Phase 2: Foundational

Bloqueia todas as user stories: sem a tradução do veredito, a US2 não existe, e a US1 não
consegue separar endosso de objeção.

- [x] **T001** Traduzir o estado da revisão para a rede
  - **Pronta quando**: nada além do repositório — o `value_map` já está em
    `priv/knowledge_base/mappings/github/qapo/review.yaml`, versão 3, e a base de
    conhecimento é carregada no boot
  - **Descrição**: `lib/the_band/quality/verdict.ex`, com `traduzir/1` conforme
    `contracts/leituras.md`. Lê o `value_map` do mapeamento pela `KnowledgeBase`, e **não**
    reescreve o mapa em código — duas cópias divergem. `DISMISSED` e `PENDING` devolvem
    `{:ciclo_de_vida, _}` e nunca veredito (FR-008); valor fora do mapa devolve
    `{:error, :nao_mapeado}`, porque `unmapped: reject` está declarado (FR-004 da #526)
  - **Feita quando**: os três estados de posição devolvem o conceito da rede; os dois de
    ciclo de vida devolvem ciclo de vida; um sexto valor devolve erro em vez de escolher o
    mais plausível
  - **Teste**: `test/the_band/quality/veredito_test.exs` — um caso por estado, mais um com
    `"SOMETHING_NEW"` que **deve** devolver `{:error, :nao_mapeado}`. E a injeção: trocar o
    `value_map` do YAML por um mapa vazio faz o teste reprovar, provando que a tradução vem
    da base e não de código

- [x] **T002** Nomear o veredito na interface
  - **Pronta quando**: T001 concluída
  - **Descrição**: os rótulos que a tela mostra para cada conceito — `qapo.endorsing_verdict`
    → "endorsed", `qapo.objecting_verdict` → "objected", `qapo.abstaining_verdict` →
    "abstained". Vive junto de `Verdict`, e não na LiveView: um segundo uso divergiria do
    primeiro. **Nenhum rótulo repete o enum do GitHub** (FR-007)
  - **Feita quando**: cada conceito tem rótulo; `APPROVED` e `CHANGES_REQUESTED` não
    aparecem em lugar nenhum da camada de interface
  - **Teste**: no mesmo arquivo de T001 — `refute` que qualquer rótulo contenha `APPROVED`
    ou `CHANGES_REQUESTED`

---

## Phase 3: US1 — Os três papéis na solicitação de mudança (P1)

**Goal**: quem abre a página vê, separados, quantas solicitações a pessoa abriu, revisou e
integrou, cada um com a lista.

**Independent test**: abrir `/people/<id>` de `vinicius-je` e ver **793** abertas, **844**
integradas, **627** revisadas — e nenhuma soma dos três.

- [x] **T003** [US1] Contar os três papéis numa consulta
  - **Pronta quando**: `contracts/leituras.md` está escrito — é o contrato de
    `participacao_da_pessoa/2`, e a constituição exige o contrato antes da primeira função
    pública
  - **Descrição**: `TheBand.Changes.Queries.participacao_da_pessoa/2`, exposta pela fachada
    `TheBand.Changes`. **Uma consulta**, com `filter (where ...)` para as seis contagens —
    nove consultas levariam a página a 32 por render, e o teto é 25. Filtra por tenant na
    cláusula (princípio V). `abriu`/`integrou`/`revisou` contam **solicitações distintas**;
    `endossou`/`objetou`/`absteve` contam **avaliações** — as unidades diferem de propósito,
    e `contracts/leituras.md` diz por quê
  - **Feita quando**: devolve os seis números para `vinicius-je` com os valores medidos;
    o `EXPLAIN` mostra **uma** passagem, e não seis; revisão de `Bot` não entra em nenhuma
    contagem
  - **Teste**: `test/the_band/changes/participacao_test.exs` — um caso por contagem, mais
    o de fronteira: uma pessoa de **outro tenant** com os mesmos dados devolve zeros. E a
    injeção que prova cada `filter`: trocar `APPROVED` por `CHANGES_REQUESTED` no filtro de
    endosso reprova o caso de endosso e **nenhum outro**

- [x] **T004** [P] [US1] Listar as solicitações por papel
  - **Pronta quando**: T003 concluída — a contagem é o que decide se a lista aparece
  - **Descrição**: `TheBand.Changes.solicitacoes_da_pessoa/3`, com o papel como terceiro
    argumento. Devolve as mais recentes até um limite constante do módulo. `desfecho` é
    derivado: `MERGED` → integrada, `CLOSED` com `external_merged_at` nulo → fechada sem
    integrar, o resto → aberta (FR-001, spec US1 cenário 3)
  - **Feita quando**: cada papel devolve a lista correta; solicitação fechada sem integrar
    vem com desfecho distinto de integrada; o limite é constante nomeada, e não literal
    espalhado
  - **Teste**: no mesmo arquivo — três casos, um por papel, e um que cria uma solicitação
    `CLOSED` sem merge e verifica o desfecho. A asserção que importa: `refute` que ela venha
    como `:integrada`

- [x] **T005** [US1] Mostrar os três papéis na aba
  - **Pronta quando**: T003 e T004 concluídas
  - **Descrição**: seção nova em `lib/the_band_web/live/people_live/show.ex`, dentro da aba
    de trabalho. Os três números **separados**, e **em nenhum lugar a soma** (FR-013). A
    carga só acontece quando `@ve_o_trabalho?` — a recusa vem antes da carga, e não só antes
    do render (#369 FR-012h). Ausência é nomeada, nunca zero solto (FR-012)
  - **Feita quando**: a página de `vinicius-je` mostra 793, 844 e 627; a página de alguém
    sem solicitação diz que a plataforma não a viu abrir nenhuma; a aba fechada não dispara
    a consulta
  - **Teste**: `test/the_band_web/live/painel_da_pessoa_test.exs` — um caso que afirma os
    três números, um que afirma a frase de ausência, e o que mais importa: **a aba fechada
    custa menos consultas que a aberta**, medido com `ContadorDeConsultas`

---

## Phase 4: US2 — O veredito de cada revisão (P1)

**Goal**: quem vê "revisou 627" vê também como revisou.

**Independent test**: na mesma pessoa, ver **634** endossos, **57** objeções, **30**
abstenções — com os nomes da rede, e nunca os do GitHub.

- [x] **T006** [US2] Mostrar os vereditos na aba
  - **Pronta quando**: T002 e T003 concluídas — os números vêm da mesma consulta de T003, e
    os rótulos de T002
  - **Descrição**: os três vereditos na seção de revisão, nomeados pelo conceito (FR-002,
    FR-007). A tela **não** apresenta endosso como "sem problemas encontrados" (FR-011): a
    rede declara que aprovar é ausência de bloqueio, e não de não conformidade
  - **Feita quando**: os três aparecem separados; nenhum texto da página contém `APPROVED`
    nem `CHANGES_REQUESTED`; nenhum texto associa endosso a ausência de problema
  - **Teste**: no arquivo de tela — `assert` dos três números e dos três rótulos, e
    `refute html =~ "APPROVED"`. Mais a injeção: trocar o rótulo de endosso por "no issues
    found" reprova

- [x] **T007** [P] [US2] Dizer por que 721 não é 627
  - **Pronta quando**: T006 concluída
  - **Descrição**: a frase que explica a diferença entre a contagem de solicitações
    revisadas e a soma dos vereditos. Medido: `vinicius-je` revisou **627** solicitações com
    **721** avaliações — quem revisou a mesma solicitação duas vezes conta uma vez em
    "revisou" e duas em veredito. Sem a frase, o leitor conclui que um dos números está
    quebrado — foi exatamente o que aconteceu com `fatasy` em 2026-08-27, com 8 e 233
  - **Feita quando**: a frase aparece quando os dois números divergem, e **não** aparece
    quando coincidem — texto que explica o que não aconteceu é ruído
  - **Teste**: dois casos — um com revisão dupla, que **deve** mostrar a frase; um sem, que
    **não deve**

- [x] **T008** [P] [US2] Excluir a revisão retirada da contagem
  - **Pronta quando**: T001 concluída
  - **Descrição**: `DISMISSED` (52 no banco) **não** entra em veredito algum, e a tela pode
    dizê-lo — a avaliação aconteceu e foi tirada de circulação (FR-008, US2 cenário 2). A
    exclusão acontece na consulta de T003, e não na tela: filtrar na tela carregaria linha
    para descartar
  - **Feita quando**: uma pessoa com revisões retiradas tem os três vereditos sem elas; a
    soma dos vereditos é menor que o total de avaliações dela
  - **Teste**: em `participacao_test.exs` — uma pessoa com uma `DISMISSED` e uma `APPROVED`
    devolve `endossou: 1` e nada mais. A injeção: incluir `DISMISSED` no filtro de endosso
    reprova

---

## Phase 5: US3 — A verificação do commit (P1)

**Goal**: quem abre a página vê quantas execuções de CI/CD dispararam sobre commits dessa
pessoa, por desfecho.

**Independent test**: `vinicius-je` mostra **985** que passaram, **79** que quebraram, **6**
outras. **Não depende das US1 e US2.**

- [x] **T009** [US3] Contar o desfecho da verificação por pessoa
  - **Pronta quando**: `contracts/leituras.md` está escrito
  - **Descrição**: `TheBand.Verifications.por_pessoa/2`. **Uma consulta**, ligando
    `commit_authors` → `collected_commits` → `collected_verifications` por `sha` = `head_sha`.
    Co-autoria **conta** — `is_primary` não filtra, e ignorá-lo apagaria participação real.
    `skipped`, `cancelled` e nulo vão para `outras`, e **nunca** para passou ou quebrou
    (FR-004). Conta **execuções**, e não commits: nova tentativa é execução nova (FR-005)
  - **Feita quando**: devolve os três números medidos para `vinicius-je`; um commit com duas
    tentativas conta duas execuções; um commit com dois autores aparece nas duas pessoas
  - **Teste**: `test/the_band/verifications/por_pessoa_test.exs` — um caso por desfecho,
    um com duas tentativas do mesmo commit, e um com co-autoria. A injeção que importa:
    somar `skipped` a `passou` reprova o caso de `outras`

- [x] **T010** [P] [US3] Medir a parcela sem autoria identificada
  - **Pronta quando**: T009 concluída
  - **Descrição**: `sem_autoria_no_tenant` — quantas execuções do tenant **não** casam com
    pessoa alguma. Medido: **7.313 de 15.671, 47%**. É contexto sobre o alcance da medida, e
    **não** parte da contagem da pessoa: vai ao lado, nunca descontada nem somada (FR-010).
    Sai da mesma consulta de T009, com `filter`, e não de uma segunda ida ao banco
  - **Feita quando**: o número aparece; a soma dos números da pessoa **não** o inclui
  - **Teste**: no mesmo arquivo — uma execução sem autoria não entra em `passou`, `quebrou`
    nem `outras`, **e** aparece em `sem_autoria_no_tenant`

- [x] **T011** [US3] Mostrar a verificação na aba
  - **Pronta quando**: T009 e T010 concluídas
  - **Descrição**: seção nova na aba de trabalho, com os três desfechos e a parcela ao lado.
    Carga só quando `@ve_o_trabalho?`. A lista das execuções mais recentes vem de
    `execucoes_da_pessoa/2`, com o corte dito na tela — lista truncada em silêncio parece a
    lista inteira
  - **Feita quando**: a página de `vinicius-je` mostra 985, 79 e 6, e a frase dos 47%; a
    contagem não é rotulada como número de commits
  - **Teste**: no arquivo de tela — `assert` dos três números e da frase da parcela, e
    `refute` que qualquer rótulo diga "commits" onde conta execuções

---

## Phase 6: Polish

- [x] **T012** Subir o teto de consultas, com a conta nomeada
  - **Pronta quando**: T005, T006 e T011 concluídas — o número final só é conhecido com as
    três seções na página
  - **Descrição**: `test/the_band_web/live/person_detail_test.exs` — o teto passa de 23 para
    25, e as **duas** consultas acrescentadas são nomeadas no comentário que enumera as
    outras: a de participação (T003) e a de verificação (T009). O teste manda derivar antes
    de subir; derivar foi tentado e é impossível — nenhuma consulta da página tocava
    `collected_change_requests`, e o plano registra
  - **Feita quando**: o teste passa com 25; o comentário nomeia as duas; a frase que diz "a
    página está exatamente no teto" continua verdadeira
  - **Teste**: o próprio `person_detail_test.exs` — e a conferência de que ele reprova em
    26, injetando uma consulta a mais

- [x] **T013** [P] Percorrer o quickstart na tela
  - **Pronta quando**: T012 concluída
  - **Descrição**: os cinco percursos de `quickstart.md`, com navegador, contra o banco de
    desenvolvimento. Registrar o resultado em `specs/044-pr-e-ci-da-pessoa/percurso.md`,
    incluindo **as divergências** — a feature 042 achou cinco fazendo isso, e quatro foram
    corrigidas na hora
  - **Feita quando**: os cinco percursos foram feitos; cada número da tela bate com o
    medido, ou a divergência está registrada com a causa
  - **Teste**: o próprio `percurso.md`, com captura de tela dos números — é o artefato que
    prova que alguém olhou, e não só que a suíte passou

- [x] **T014** [P] Atualizar a documentação derivada
  - **Pronta quando**: T001 concluída — o módulo `qapo.evaluation_verdict` entrou na base
  - **Descrição**: rodar `scripts/generate_docs.py`. A base foi de 234 para **238
    conceitos** e de 173 para **174 relações** com o veredito, e `docs/ontology/qapo.md`
    ainda não os traz
  - **Feita quando**: `docs/ontology/qapo.md` contém os quatro conceitos novos e a relação;
    `docs/ontology/concept-index.md` e o README batem com os números do validador
  - **Teste**: `mix gates` — o gate "derivação reproduzível" reprova se a documentação
    estiver desatualizada em relação aos YAML.

    ⚠️ **Esse gate NÃO pega tudo**, e a issue #527 registra: um módulo presente em
    `modules/` mas ausente da lista `modules:` do `ontology.yaml` passa em silêncio — os
    conceitos entram na contagem e no índice, e a página da ontologia os omite. Aconteceu
    com este mesmo módulo. A conferência aqui é **abrir `docs/ontology/qapo.md` e ver a
    seção**, e não confiar no gate

---

## Dependências

```
T001 ──┬── T002 ──┐
       │          ├── T006 ── T007
       └── T008    │
                   │
T003 ──┬── T004 ── T005
       └───────────┘
                   
T009 ── T010 ── T011

T005 ┐
T006 ├── T012 ── T013
T011 ┘

T001 ── T014
```

**US3 (T009–T011) não depende de US1 nem de US2.** Pode ser feita primeiro, e entregue
sozinha.

## Paralelismo

| podem correr juntas | por quê |
|---|---|
| T004 e T008 | arquivos diferentes, sem dependência entre si |
| T007 e T010 | uma é texto de tela, a outra é consulta |
| T013 e T014 | percurso manual e documentação derivada não se tocam |
| **US3 inteira** com **US1** | domínios diferentes, tabelas diferentes |

## Estratégia de entrega

**MVP**: US1 (T001–T005). Entrega os três papéis, que é o pedido central, e já vale
sozinha.

**Incremento 2**: US2 (T006–T008) — o veredito, que transforma "revisou 627" em informação.

**Incremento 3**: US3 (T009–T011) — a verificação. Independente, e pode vir antes se a
prioridade mudar.

**Fechamento**: T012–T014.

---

## O que nenhuma tarefa faz

- **Nenhuma escreve no banco.** A feature é de leitura.
- **Nenhuma dispara coleta.** SC-006, e `research.md` R1 explica por quê.
- **Nenhuma cria migração.** `data-model.md` lista as cinco tabelas, todas existentes.
- **Nenhuma atravessa fronteira de domínio.** `Changes` não pergunta a `Quality`; a tela
  compõe as três leituras, e é ela quem tem o direito.
