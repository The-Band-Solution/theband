# Retomar — estado em 2026-09-03, com o release v0.4.0 esperando decisão

Escrito para a sessão seguinte começar trabalhando, não reconstruindo contexto.

## Onde parei, em uma frase

**O release v0.4.0 está aberto e esperando o Product Owner**, e o sprint 029 tem
cinco das 21 tarefas na `development` — sem nada em tela.

## O primeiro comando

```bash
git checkout development && git pull
mix gates          # o veredito é o CÓDIGO DE SAÍDA, e nada depois dele
```

Estava **0** em 2026-09-03, com 1 665 testes passando.

## O que decide tudo o resto: dois PRs abertos

| PR | O que é | Base | Quem decide |
|---|---|---|---|
| [#792](https://github.com/The-Band-Solution/theband/pull/792) | 055/T014 — a FR-012, as duas afirmações | `development` | entra antes do #791 |
| [#791](https://github.com/The-Band-Solution/theband/pull/791) | **release v0.4.0** — 055, 056, 057 e a 058 parcial | `main` | **Product Owner (FR-016)** |

**Merge no #791 É o deploy** — o CD dispara em push na `main`. A produção está em
**v0.3.0** desde 2026-09-01; a `development` está em `0.4.0` e 59 commits à
frente.

**A ordem importa**: o #792 primeiro. Mergeado o #791 antes dele, a v0.4.0 sobe
com a FR-012 do 055 aberta.

**E nada protege a `main`.** Sem branch protection, o botão de merge aceita
clique com o CI pendente ou vermelho — e o clique é o deploy. O guarda hoje é
disciplina humana, e está registrado como decisão pendente no #791.

---

## Sprint 029 — o que falta

| Tarefa | Issue | O que é |
|---|---|---|
| **T006** ← **começar aqui** | [#773](https://github.com/The-Band-Solution/theband/issues/773) | a marca do período parcialmente desconhecido, na tela |
| **T007** | [#774](https://github.com/The-Band-Solution/theband/issues/774) | a seção na tela do projeto, com a ausência dita |
| T008–T011 | #775–#778 | a US1 — o tempo até a primeira revisão |
| T012–T016 | #779–#783 | a US3 inteira — a taxa do pipeline |
| T017–T021 | #784–#788 | polish, cobertura, gates e PR |

**Feito e MERGEADO**: T001–T005
([#768](https://github.com/The-Band-Solution/theband/issues/768)–[#772](https://github.com/The-Band-Solution/theband/issues/772)
fechadas), pelo squash do #789 em `1e733aa`.

**Começar pela T006, e não pela T008.** A ordem anterior deste arquivo dizia T008,
e estava errada: a US2 é o MVP e ficou sem as duas tarefas de tela.

**O que isso custou, e vale dizer em voz alta**: `who_worked_on/3` e
`TheBand.Periodos` estão na `development` **sem consumidor visível**, e o release
v0.4.0 os leva a produção assim. Ninguém que usa a plataforma vê diferença
nenhuma. O #789 foi mergeado ainda em draft, e a T006 e a T007 são o que fecha
isso — é por elas que a próxima sessão começa.

Tudo em [`specs/058-medidas-da-equipe/tasks.md`](../../specs/058-medidas-da-equipe/tasks.md),
com os quatro campos e o link de cada issue.

### A primeira coisa a fazer, além de código

**Conferir se o release saiu, e o que ele deixou pendente.** Se o #791 já entrou:
medir a produção pelo [runbook](../producao/runbook.md) — SC-001 a SC-005, contra
o endereço real e não pelo painel do Dokploy dizer `Done` (**L84**) — e fazer o
**back-merge `main` → `development` com merge commit** (**L92**).

Se não entrou, ele continua esperando decisão do Product Owner, e a T006 é o
trabalho que não depende disso.

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
