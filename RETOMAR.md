# Retomar

Última sessão: 2026-08-18, noite. Branch `037-coleta-do-ci`.

## O que acabou de ser feito — feature 037, o CI (#401)

PR **#435** aberto (base `036-fases-e-antipadrao-do-ci`), 13 gates verdes, 1.038 testes
mais 26 novos. Dois commits: a feature e a correção do rate limit.

**O achado que reorientou a feature.** A primeira versão mapeava toda execução do
Actions para `ciro.continuous_integration_process`. O dado real desmentiu: das 1.051
execuções do primeiro repositório, as cinco mais frequentes são `Sync to GitLab` (264),
`Deploy Docs to GitHub Pages` (247), `Deploy Backoffice and Front-office` (235),
`Sprint Rollover` (109) e `Release ConectaFapes` (90) — **nenhuma integra código**.

O tipo passou a ser derivado dos componentes dos jobs: CIRO, CDRO, ou **vazio** quando
não há nenhum (399 execuções, que a tela nomeia em vez de esconder). A limitação estava
escrita no mapeamento desde a versão 1 e o código a ignorava.

**As três fases de ontem se confirmaram**: 55 falhas e 54 cancelamentos. Contar
cancelado como falha levaria a taxa de quebra de 5,2% para 10,4%.

**Dois padrões saíram por inventarem**: `artifact` casava com `Upload Pages artifact` e
produzia 238 entregas inexistentes; `package` casava com `Install npm packages`. Virou
memória: [padrao-largo-inventa-mais].

**`ci.ap02` estreitou** (751 defeitos falsos → 0, só vale dentro de execução de CI) e
**`ci.ap01` alargou** (502 jobs `Deploy backoffice` fazem build e deploy no mesmo job).

## Estado das coletas — as duas estão PARADAS

| coleta | onde parou | como retomar |
|---|---|---|
| arquivos dos commits | 8.438 de 16.416 | `mix run <scratchpad>/coleta_arquivos.exs` |
| verificações do CI | 4 de 160 repositórios | `mix run <scratchpad>/coleta_ci.exs` |

**As duas competem pela mesma janela de 5.000 req/h**, e rodar juntas esgota tudo. A do
CI faz uma requisição por execução (para os jobs); a de arquivos, uma por commit.
Rodar **uma de cada vez**.

Nenhum checkpoint ficou sujo: a coleta do CI só marca o repositório com os jobs todos
coletados, e a de arquivos marca por commit.

## Falta na 037

- rodar as duas coletas até o fim, uma de cada vez;
- capturar as telas `/work/verifications` e `/work/verifications/:id` com dado real;
- sprint backlog e review da 037.

## Os seis PRs abertos, e um problema que atinge todos

| PR | base | estado | fecha issue? |
|---|---|---|---|
| ~~#430~~ | main | **MERGEADO** | não tinha keyword — #395/#396 seguem abertas |
| #431 | main | conflito **resolvido**, mergeable | **não tem keyword** |
| #432 | main | aberto | sim, #428 |
| #433 | 033-… | aberto | `Closes #429` mas **não vincula** |
| #434 | 035-… | aberto | **não tem keyword** |
| #435 | 036-… | aberto | `Closes #401` mas **não vincula** |

**O #430 foi mergeado por squash**, e foi isso que gerou o conflito do #431: o git passou
a ver `changes.ex` e `changes_test.exs` como criados dos dois lados. Resolvido conferindo
que a versão da branch é superconjunto estrita — nada existia só no main.

À medida que a pilha for mergeando, os PRs de cima vão repetir esse conflito. A conferência
é sempre a mesma: `diff` entre a versão do main e a da branch, e só aceitar "ficar com a
minha" quando o lado do main não tiver nada exclusivo.

**Descoberto hoje**: closing keyword do GitHub **só cria vínculo quando a base é a
branch padrão**. PR empilhado nunca fecha issue, mesmo com a sintaxe certa. É o terceiro
jeito de essa promessa falhar em silêncio — memória [fecha-em-portugues-nao-fecha-issue]
atualizada.

Ao mergear a cadeia, **fechar #395, #396, #401, #427, #429 à mão** e conferir com
`gh issue view`.

## Ordem sugerida dos merges

`#430` → `#431` → `#433` → `#434` → `#435`, e `#432` a qualquer momento (independente).
