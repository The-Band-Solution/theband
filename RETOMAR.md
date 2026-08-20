# Retomar — 2026-08-20, início da madrugada

## Primeira coisa ao voltar: conferir se a recoleta terminou

```bash
set -a; . ./.env; set +a
MIX_ENV=dev mix the_band.recollect_changes      # somente leitura, sem --apply
```

Ela lista quantas solicitações integradas ainda estão sem `statusCheckRollup` medido.

**Estava caindo quando parei** — 454, todas no repositório
`leds-conectafapes/leds-conectafapes-backend-pagamento-bolsistas`. Começou em 763.

| momento | faltando |
|---|---:|
| ao abrir a pendência | 763 |
| ifesserra-lab concluído (9 repos) | 650 |
| — | 517 |
| última medida | **454** |

O job `#1088` estava `executing`, a coleta em `running` com 3.136 registros, e o número caía
a cada medição. A expectativa é que tenha chegado a **0** durante a noite.

Se a saída disser **0 repositórios**, a pendência fechou — e vale reconferir
`/work/verifications/people`, porque as **221** vermelhas medidas pela ponta devem ter
crescido. Vale também recontar as **1.705** que entraram sem check: é o número que está
publicado no site, e se ele mudar o site precisa acompanhar.

Se ainda houver faltando **e nenhum sync `running`**, o nó morreu no meio: rode
`mix the_band.recollect_changes --apply` de novo e aperte **Sync** em `/syncs`. O corte já
está zerado, então a recoleta continua de onde parou.

---

## O PR aberto

**[#453](https://github.com/The-Band-Solution/theband/pull/453)** — branch
`fix/pendencias-recalculo-e-corte-incremental`. 13 gates verdes, código de saída 0, revisor
`the-band` pedido. Não fecha issue por closing keyword de propósito: conserta duas coisas
que não tinham issue própria, e abriu a #452 para a causa.

**A branch atual é essa.** Árvore limpa, nada sem commitar.

---

## O que foi feito hoje

### Mergeado

**#449** (rastro do defeito) e **#451** (documentação de estado). O #449 levou a correção
dos números — conferi que o conteúdo chegou na `main` pelo squash, ainda que o hash não
sobreviva.

### A correção que vale lembrar

Eu tinha escrito, em quatro lugares, que o `statusCheckRollup` acha **mais** vermelhas que o
casamento por `head_sha` — "349 contra 284, 23% mais". O banco diz o contrário:

```
casamento por head_sha    296 vermelhas
statusCheckRollup         221 vermelhas
nos dois                   82
união                     435
```

Sobreposição de 82 em 435: **não são duas precisões do mesmo fenômeno, são dois
fenômenos.** Das 214 que só o casamento acha, **186 estão verdes na ponta** — a vermelha
estava num commit intermediário, consertada antes do merge. Conferido no `#13`: 33 commits,
três vermelhas no meio, ponta verde com 2 contextos.

A troca continua certa, por um motivo melhor: o casamento **supercontava** justamente o caso
que a tela declara recusar contar. Lição **L67**.

### Três defeitos que só apareceram rodando

1. **`Jobs.RecomputePromotions` estourava depois de fazer o trabalho.**
   `Mapping.recompute/2` devolve `%{written:, concept_changed:}` e o job interpolava como
   inteiro. `Protocol.UndefinedError` **após** o recálculo: trabalho feito três vezes, job
   `discarded`, tela sem aviso. E o broadcast ia para `"tenant:<id>"`, tópico sem assinante.

2. **O teste passava com metade do defeito.** `config :logger, level: :warning` faz
   `Logger.info/1` sair antes de avaliar o argumento — esse defeito **não existe no ambiente
   de teste**. `capture_log([level: :info], ...)` não resolve: filtra o que captura, não o
   que o Logger emite. Lição **L69**.

3. **Eu pausei o servidor sem perceber.** `Oban.pause_all_queues(local_only: true)` casa por
   `Config.to_ident/1` = `inspect(name) <> "." <> to_string(node)`, e o nó de um `mix` e de
   um `mix phx.server` são **os dois** `nonode@nohost`. Os jobs ficaram `available` com
   `attempt: 0` por 23 minutos, sem log nenhum. Voltaram com `resume_all_queues/0`.

Também cancelei o job `#5`, órfão em `executing` desde 2026-08-09 — **sem** adicionar o
`Lifeline`, cuja recusa está medida em `specs/008-destravar-sync-presa/research.md` R1.

### O site

[the-band-solution.github.io/theband](https://the-band-solution.github.io/theband/) —
`gh-pages`, commit `525f07c`. Quatro números atualizados, quatro novos, e a frase sobre as
**1.705** que entraram sem verificação nenhuma.

### A documentação

O README dizia "Aplicação Phoenix: **não iniciada**". E as páginas geradas estavam nove
features atrás: afirmavam 12 ontologias quando a base tem 13, e a CMO não tinha página
nenhuma. Nova página `docs/integrations/verificacao-continua.md` explica os dois eixos do
modelo de CI.

---

## Próximos passos, na ordem que eu recomendaria

### 1. As quatro decisões que só você pode tomar

| | pergunta |
|---|---|
| [#367](https://github.com/The-Band-Solution/theband/issues/367) | qual é o quadro do projeto no Conecta Fapes, e o que fazer com as 275 issues fora dele |
| [#368](https://github.com/The-Band-Solution/theband/issues/368) | qual campo de data é o prazo, por quadro |
| [#369](https://github.com/The-Band-Solution/theband/issues/369) | quem vê o painel de trabalho de quem |
| [#370](https://github.com/The-Band-Solution/theband/issues/370) | qual movimentação marca o início de um trabalho |

Cada uma bloqueia uma feature, nenhuma é implementação. Meia hora sua destrava mais que um
dia meu.

### 2. [#452](https://github.com/The-Band-Solution/theband/issues/452) — a causa do corte incremental

`GithubChangeRequests.collect/1` para de paginar em `changes_collected_at`. Quando a consulta
ganha campo, os registros antigos ficam de fora **para sempre** — e o sintoma é silencioso: a
tela não diz "faltou coletar", diz "não dá para saber".

Três alternativas escritas na issue. A terceira — disciplina no processo, sem mecanismo — é a
que vale hoje **por omissão**. A issue existe para a escolha ser feita de propósito.

Vale para todas as fases incrementais, não só as mudanças: commits, arquivos, verificações e
comentários têm o mesmo `*_collected_at`.

### 3. [#358](https://github.com/The-Band-Solution/theband/issues/358) — percorrer o quickstart a mão

Barato, e é o tipo de coisa que acha quebra real. Os três defeitos de hoje só apareceram
rodando. **Eu posso fazer, é só dizer.**

### 4. [#356](https://github.com/The-Band-Solution/theband/issues/356) — medir o custo real de uma rodada de perfis

Medição, não implementação.

---

## Features prontas para especificar

| issue | o que é |
|---|---|
| [#397](https://github.com/The-Band-Solution/theband/issues/397) | equipe composta por equipes, com rollup das competências |
| [#363](https://github.com/The-Band-Solution/theband/issues/363) | a competência como unidade do perfil |
| [#364](https://github.com/The-Band-Solution/theband/issues/364) | as tarefas que a pessoa abre para outras entram no material |
| [#317](https://github.com/The-Band-Solution/theband/issues/317) | sugerir papel a partir de evidência |
| [#81](https://github.com/The-Band-Solution/theband/issues/81) | filtro por organização nas telas |
| [#176](https://github.com/The-Band-Solution/theband/issues/176) | criar as iterações que faltam no Projects v2 |

**#317 não está feito** — conferi. O que existe em `/roles` sugere os quatro papéis da
ontologia, não papel por pessoa a partir de evidência.

**#81 está feito só em `/work/verifications`.** As outras telas não têm seletor de
organização.

**[#442](https://github.com/The-Band-Solution/theband/issues/442) (ArgoCD)** continua fora
por sua decisão, e são quatro decisões antes de qualquer código.

---

## Higiene, quando quiser

**9 branches locais com remoto apagado.** Conferi uma a uma: nenhuma tem conteúdo que a
`main` não tenha. A `049-timeline-atividade` aparecia 7 commits à frente e é absorção por
squash; a `027-geracao-mensal-de-perfis` parecia ter `github_sprints.ex` exclusivo, e o
arquivo virou `github_projects.ex` num refactor.

```bash
git branch -vv | grep ": gone"          # ver antes
git fetch -p                            # depois decidir a poda
```

---

## Estado da cota do GitHub

`graphql 2285/5000` quando parei — a recoleta está consumindo. Se algum comando `gh` falhar
com *rate limit*, o REST continua servindo:

```bash
gh api -X POST /repos/The-Band-Solution/theband/issues --input arquivo.json
```

Foi assim que abri a #450 e a #452, com o GraphQL esgotado.

---

## Lembretes que custaram caro

- **`mix gates` — o veredicto é o código de saída**, nunca a última linha:
  `mix gates > /tmp/g.log 2>&1; ec=$?; tail -30 /tmp/g.log; exit $ec`
- **Ao trocar uma medida por outra**, medir a sobreposição e amostrar o que só a antiga acha.
  Comparar totais engana (L67).
- **Não colocar em interpolação de log nada que possa levantar** — no teste não avalia, em
  produção derruba o trabalho já feito (L69).
- **`local_only` do Oban não isola** um `mix` de um `mix phx.server` sem `--sname`.
- **Consulta schemaless com lista de UUID** precisa de `type(^ids, {:array, :binary_id})`.
