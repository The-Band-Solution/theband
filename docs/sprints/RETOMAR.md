# Retomar — estado em 2026-08-14, depois da coleta e do conserto do CI

Escrito para a sessão seguinte começar trabalhando, não reconstruindo contexto.

## Onde o trabalho parou

**Nenhum PR aberto.** Onze foram incorporados nas últimas duas sessões:

| PR | O que é |
|---|---|
| [#296](https://github.com/The-Band-Solution/theband/pull/296) · [#297](https://github.com/The-Band-Solution/theband/pull/297) · [#298](https://github.com/The-Band-Solution/theband/pull/298) | validador à paridade · estado na URL · lições L54–L57 |
| [#299](https://github.com/The-Band-Solution/theband/pull/299) | este documento, reescrito |
| [#301](https://github.com/The-Band-Solution/theband/pull/301) | credencial ilegível vira atenção, e não exceção |
| [#302](https://github.com/The-Band-Solution/theband/pull/302) | renomear, remover, trocar token, corrigir cadastro |
| [#303](https://github.com/The-Band-Solution/theband/pull/303) · [#305](https://github.com/The-Band-Solution/theband/pull/305) | a tabela em seis telas — e o resgate do que o merge empilhado deixou fora |
| [#306](https://github.com/The-Band-Solution/theband/pull/306) | o português que sobrou · lição L58 |
| [#307](https://github.com/The-Band-Solution/theband/pull/307) | **spec 020**, pronta para `/speckit-plan` |
| [#308](https://github.com/The-Band-Solution/theband/pull/308) | o Oban derrubava a aplicação em teste |

A `main` está verde em `a32f17b9` — `quality-gates` e `cobertura`. A execução anterior tinha
falhado pelo defeito que o #308 consertou.

## A coleta aconteceu, e provou três features

Rodou em **2026-08-14 03:33**, nas três organizações, com um PAT novo cadastrado pela tela.

| Medida | Antes | Depois | O que a spec previa |
|---|---:|---:|---|
| repositórios inacessíveis | 1 | **0** | zero |
| vínculos marcados como ausentes | 0 | **52** | os 52 — `eo_lib` 29, `theband` 15, `ResearchDomain` 8 |
| pessoas | 75 | **88** | sair de 75 |
| `sofialctv` | não existia | **existe** | passa a existir |
| issues com autor sem pessoa | 286 | **3** | cair |

**Os 52 bateram exatamente**, e repartidos como previsto. É a feature 012 provada no dado real,
depois de três sprints esperando por uma coleta.

## O que a plataforma sabe hoje

```
160 repositórios observados · 5031 issues · 3 organizações · 88 pessoas
1727 vínculos · 52 marcados como ausentes · 101 evidências de vínculo · 0 membros promovidos
atendimento 3965 · user story atômica 814 · defeito 194 · épico 58
```

**Zero membros promovidos, e 101 evidências.** O vínculo da ontologia exige papel
organizacional, e nenhum papel foi cadastrado — é a dupla #99 e #100, e continua sendo a P1 mais
barata que não depende de chave nem de coleta.

## O que precisa de você, e eu não consigo fazer

**Três conferências, todas de olho humano, e agora com dado fresco.**

| Onde | O quê |
|---|---|
| `/people/<id>` de `vinicius-je` | **350 e 609, nunca 959** — a soma é proibida |
| `/work/repositories/<id>` de `eo_lib` | as **29** issues dizendo, em texto, que a decomposição acabou |
| qualquer tela em **360 px** | nona vez que este item aparece |

As duas primeiras fecham as issues [#277](https://github.com/The-Band-Solution/theband/issues/277)
e [#265](https://github.com/The-Band-Solution/theband/issues/265).

**A de 360 px é a primeira com chance de aprovar.** O componente de tabela emite `data-label`, e
é o que a classe `stacked` usa para escrever o nome da coluna ao lado do valor em tela estreita.
Antes disso, olhar reprovaria.

## Duas decisões pendentes, e as duas são suas

**1. A migração do Oban.** O repositório está em `Oban.Migration.up(version: 12)` e a biblioteca
2.23.1 exige **14**. Descoberto porque `testing: :manual` — o modo documentado — confere isso na
subida. O conserto do CI **não** subiu a migração de carona: é mudança com efeito em produção.

**2. A FR-012 da spec 020.** A marca de ausência das features 009 e 012 depende de percorrer a
lista inteira; uma coleta incremental não vê o que sumiu. As duas saídas — coleta completa
periódica, ou a origem informar remoção — têm custo diferente, e a spec deixou a decisão para o
plano de propósito.

## Product backlog — o que está por cima

| # | O que é | Prioridade |
|---|---|---|
| [#99](https://github.com/The-Band-Solution/theband/issues/99), [#100](https://github.com/The-Band-Solution/theband/issues/100), [#98](https://github.com/The-Band-Solution/theband/issues/98) | cadastrar papel e alocar pessoa a papel — **transformaria as 101 evidências em vínculos** | P1 |
| **spec 020** | `/speckit-plan`, com três perguntas a responder — ver abaixo | P1 |
| [#277](https://github.com/The-Band-Solution/theband/issues/277), [#265](https://github.com/The-Band-Solution/theband/issues/265) | as conferências acima | P1, e só você |
| [#179](https://github.com/The-Band-Solution/theband/issues/179) | coletar comentários e timeline | P2 |
| [#180](https://github.com/The-Band-Solution/theband/issues/180), [#181](https://github.com/The-Band-Solution/theband/issues/181) | quadros, campos e iterações do Projects v2 | P2 |
| [#176](https://github.com/The-Band-Solution/theband/issues/176) | criar as iterações que faltam | decisão pendente desde o sprint 004 |
| [#81](https://github.com/The-Band-Solution/theband/issues/81), [#82](https://github.com/The-Band-Solution/theband/issues/82), [#104](https://github.com/The-Band-Solution/theband/issues/104), [#107](https://github.com/The-Band-Solution/theband/issues/107), [#108](https://github.com/The-Band-Solution/theband/issues/108) | escopo de observação, quadros, quem atravessa organizações | |

**O `/speckit-plan` da 020 precisa responder três coisas** que a spec deixou abertas: se o
GraphQL do GitHub filtra issues por `updatedAt`, se comentário altera esse campo, e qual das duas
saídas da FR-012.

## Dívida conhecida, e não esquecida

| Dívida | Onde |
|---|---|
| **migração do Oban em v12, biblioteca exigindo v14** | `priv/repo/migrations/20260809120100_add_oban_jobs_table.exs` |
| `records_created` e `records_updated` zerados nas 38 execuções | `github_work_items.ex:121` e `:408` chamam `tally(:unchanged)` fixo — virou a história 1 da spec 020 |
| `list_parents/2` e `fetch_parent/2` coexistem | duas funções para a mesma relação vista de baixo |
| **quatro** funções de marcação de ausência, sem abstração comum | os cortes não são iguais |
| `SchemaCheck` implementa um subconjunto do JSON Schema 2020-12 | oito construtos; construto não implementado **reprova** |
| dois validadores da mesma regra, em linguagens diferentes | o gate `validadores concordam` é o que impede a divergência |
| as tabelas menores não buscam nem ordenam | corte **medido**: 4,4 partes por issue, 1 credencial por ferramenta |
| `mapping/queries.ex` mantém a segunda definição de promoção vigente | ADR 0003 |

## O que continua valendo, e não muda

- **`mix gates` é a definição única dos treze gates**, e o veredito é o código de saída;
- **nunca se apaga dado** — ausência é marcada, nunca removida;
- **a chave mestra e o token nunca entram no chat**, nem no repositório;
- **o ciclo Spec Kit vem antes do código**, e a fase de análise achou defeito de desenho em
  **oito** features seguidas — na 020, que a coleta incremental cega a marca de ausência;
- **depois do merge, conferir o que o merge não fez** — L48 para a palavra de fechamento, e
  **L58** para o conteúdo: `git branch -r --contains <sha> | grep origin/main`;
- **PR empilhado é incorporado antes da sua base**, ou reapontado para a `main` depois — L58;
- **veredito que muda com o gatilho não vale** — L59, e ela custou 197 testes falhando por um
  ciclo de reinício que ninguém lia havia meses;
- **barulho tolerado é defeito não medido** — a mesma L59;
- **uma feature por branch**, e a pergunta é no primeiro commit de código — L52;
- **ausência de erro não é resultado** — L54 a L57.
