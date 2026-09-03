# Retomar — estado em 2026-09-02 (noite)

Escrito para a sessão seguinte começar trabalhando, não reconstruindo contexto.

## Onde parei, em uma frase

**Sprint 029 aberto e a implementação começada**: `TheBand.Periodos` e a US2
prontas na branch `058-medidas-da-equipe`, cinco commits empurrados, **sem PR
aberto ainda**.

## O primeiro comando

```bash
git checkout 058-medidas-da-equipe && git pull
mix gates          # o veredito é o CÓDIGO DE SAÍDA, e nada depois dele
```

Estava **0** ao desligar.

---

## Sprint 029 — o que falta

| Tarefa | Issue | O que é |
|---|---|---|
| **T008** ← **começar aqui** | [#775](https://github.com/The-Band-Solution/theband/issues/775) | recortar a espera por revisão pela equipe |
| T009 | [#776](https://github.com/The-Band-Solution/theband/issues/776) | espera em curso, que não é tempo zero |
| T010, T011 | #777, #778 | por pessoa, e a seção na tela |
| T012–T016 | #779–#783 | a US3 inteira — a taxa do pipeline |
| T017–T021 | #784–#788 | polish, cobertura, gates e PR |

**Feito**: T001–T005 ([#768](https://github.com/The-Band-Solution/theband/issues/768)–[#772](https://github.com/The-Band-Solution/theband/issues/772)),
25 testes passando. **T006 e T007** (a marca do parcial e a seção na tela) ainda
não.

Tudo em [`specs/058-medidas-da-equipe/tasks.md`](../../specs/058-medidas-da-equipe/tasks.md),
com os quatro campos e o link de cada issue.

### A primeira coisa a fazer, além de código

**Abrir o PR desta branch.** Os cinco commits estão no remoto e sem PR — foi
exatamente esse o defeito da **L100** no sprint passado, e ele reincidiria aqui.

Usar o template novo: `.github/pull_request_template.md`. **Tipo de merge é campo
obrigatório** — esta branch é `squash` (nada ramifica dela).

---

## O que esta sessão entregou

### Sprint 028 — feature 057, incorporado

Cinco PRs em `development`, **todos merge commit**, `mix gates` verde depois.

A tela da equipe passou a responder as quatro perguntas de gestão; a equipe
composta mostra as subequipes **sem somar**; burn-up/burn-down com o que resta
como faixa derivada; previsão de Monte Carlo determinística; tarefas e
habilidades por pessoa.

**42 das 43 issues fechadas.**

### Fora da feature

- **Sprint 027 fechado** — não estava: 13 tarefas entregues, zero issues
  fechadas, nenhuma review;
- **site publicado** no `gh-pages` — seção nova em PT e EN;
- **`AGENTS.md` §12** e o **template de PR** — o tipo de merge deixou de ser
  escolha do botão;
- **lições reorganizadas**: 99 em sete famílias, com índice. Antes eram 3 330
  linhas sem índice nenhum;
- **higiene do CI** — seis ações em `node24` (PR [#764](https://github.com/The-Band-Solution/theband/pull/764));
- **épico #504 revisto** — foi o que originou o sprint 029.

---

## O que está aberto, e não escondido

### A revisão independente, pelo terceiro sprint

**Os cinco PRs do sprint 028 foram incorporados com ZERO revisões.** A lacuna
está declarada em cada um, e a issue
[#753](https://github.com/The-Band-Solution/theband/issues/753) segue aberta.

O princípio VII manda declarar, nunca marcar como cumprida. **CI verde não é
revisão**: os gates dizem que o código compila e não regride, e não dizem que
alguém leu o desenho.

### A chave mestra não está neste ambiente

`mix run` contra o banco falha com `:missing_master_key`. Isso bloqueia:

- **T020** — medir a cobertura do dado antes de aceitar a US3;
- qualquer conferência contra a origem (**L30**).

Se os vínculos equipe ↔ projeto forem zero, **a US3 entrega só o ramo da
recusa** — e isso é **resultado**, não falha. Está na spec e na DoD.

### Duas limitações que se acumulam

**O sprint não tem iteration** — o terceiro seguido. Acrescentá-la recria as
existentes: a **L11** mediu 97 itens órfãos.

**As user stories ficam sem tipo** — `User Story` não existe na organização.
Criar o tipo altera a configuração e **não foi autorizado**. Sem tipo é ausência;
com o tipo errado é afirmação falsa.

---

## Dois erros meus nesta sessão, com a correção registrada

**Afirmei que `linked_at` era anulável.** É `NOT NULL` — conferi a migração só
depois de o teste falhar. É a **L51**, e a correção está em `research.md` (R2a)
com a tabela das seis colunas.

**Tratei `fim` nulo como desconhecido, e ele significa vigente.** O primeiro erro
escondia este, que é pior: marcaria **quase toda linha** como duvidosa, até a
marca deixar de significar alguma coisa. Só a ponta de início produz
`{:parcial, _}` agora.

Os dois estão em `research.md`, não corrigidos em silêncio.

---

## Decisões desta sessão que valem para as próximas

**O tipo de merge é declarado no PR**, não escolhido no botão. Três lições
nasceram do squash (L75, L83, L92) e a terceira aconteceu com as duas já
escritas — por isso virou regra e campo, e não uma quarta lição.

**Lição que descreve ato repetível vira regra no `AGENTS.md` e campo no artefato
onde o ato acontece.** O registro guarda o porquê; o artefato carrega a
obrigação. É a **L98**.

**Conferir issue por issue antes da review** achou que T020 e T021 da 057 nunca
foram implementadas — com o PR incorporado e os gates verdes. Nenhum gate pega
isso: os testes provam o que **existe**, não o que foi prometido. É a **L99**, e
está na DoD.

---

## Onde ler, na ordem

1. [`docs/sprints/029-medidas-da-equipe/sprint-backlog.md`](029-medidas-da-equipe/sprint-backlog.md) — o objetivo e a DoD
2. [`specs/058-medidas-da-equipe/tasks.md`](../../specs/058-medidas-da-equipe/tasks.md) — o que fazer
3. [`specs/058-medidas-da-equipe/research.md`](../../specs/058-medidas-da-equipe/research.md) — **R1 e R2a**, as duas decisões que mudaram o plano
4. [`docs/sprints/licoes-aprendidas.md`](licoes-aprendidas.md) — as **sete famílias** no topo levam um minuto
