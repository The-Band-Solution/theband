# Data model — spec 065

**Data**: 2026-09-13 · Deriva de [research.md](research.md).

**Nenhuma tabela nova. Nenhuma coluna nova. Nenhuma migração.** Este documento descreve o que
já existe e o que passa a ser **lido**.

---

## O que já está guardado

### `issue_labels` — o rótulo do campo

| campo | o que é |
|---|---|
| `name` | o texto como o time escreveu |
| `color` | a cor que a origem definiu |
| `no_longer_observed_at` | quando a origem deixou de mostrá-lo |

**Recoleta marca, não apaga.** O rótulo que a issue teve é fato sobre como o time a
classificou, e some da tela sem sumir do registro.

1 733 vínculos, 138 nomes distintos.

### `collected_issues.title` — a segunda origem, já ali

O prefixo entre colchetes não é campo; é os primeiros caracteres do título. **Nada precisa ser
coletado** para esta feature existir.

---

## O rótulo, como o item de trabalho passa a expô-lo

Não é tabela — é o que a leitura monta.

| atributo | valores | de onde |
|---|---|---|
| `texto` | livre | o nome no campo, ou o prefixo como escrito |
| `origem` | `campo` · `titulo` | qual das duas vias |
| `cor` | hex, ou **ausente** | só o rótulo do campo tem; ninguém escolheu cor para um prefixo |

### A origem decide a forma, e a forma não é só cor

| origem | preenchimento | o que significa |
|---|---|---|
| `campo` | **sólido** | alguém clicou no campo de rótulo |
| `titulo` | **hachurado 135°** | convenção de escrita, não clique |
| ausência | **tracejado** | não há rótulo, e isso está escrito |

Sempre com **texto e `title` redundantes** — remover a cor não remove a informação.

### O que NÃO acontece com o rótulo

- **não é deduplicado**: `backend` do campo e `Back-end` do título aparecem os dois;
- **não é normalizado**: `[Back-end]` vira `Back-end`, não `backend`;
- **não é interpretado**: `prioridade:alta` é texto; `epic:base` é texto;
- **não vira tipo**: é a razão de o prefixo qualificar — ele já foi **recusado** como tipo.

---

## Quais prefixos qualificam

A lista vive em `github_issue_pattern_catalog.yaml`, seção `not_type_patterns`, e é **lida**,
nunca copiada.

| qualifica | não qualifica |
|---|---|
| `Devops` 369 · `Back-end` 316 · `Front-end` 303 | `TASK` 1 188 — é o tipo |
| `Dados` 267 · `QA` 113 · `Backend` 83 | `FEATURE` 312 · `BUG` 170 — são o tipo |
| `Front` · `Infra` | `Portal ADM` 68 — **não está declarado** |

`Portal ADM` é o caso que prova a regra: tem 68 issues, tem colchete, e **não vira rótulo**.
Verificado contra o dado real antes de existir código.

---

## A identidade do item na tela

**O armazenamento não muda.** O índice único em `(tenant_id, source_system, source_instance,
external_id)` já garante identidade; 5 033 issues, 5 033 `external_id`.

O que muda é o que a tela **mostra**: hoje `#2`, que existe em vários repositórios — 5 033
issues em apenas 2 699 números distintos.

### O caminho até o nome

```
collected_issues → observed_repositories → cmpo_source_repositories
                                              └── qualified_name
```

Duas junções. E **a terceira não é necessária**: `qualified_name` já traz a organização —
`leds-conectafapes/conectafapes-project`. Um campo, não dois.

### O que a tela passa a mostrar

`leds-conectafapes/conectafapes-project` **#2**, com o nome truncado e o valor inteiro
disponível ao apontar. Dentro de um repositório o número nunca colide; a colisão é **entre**
repositórios, e é isso que o nome resolve.

---

## Ordem

Os rótulos de um item saem **sempre na mesma ordem** para os mesmos dados.

Não é preferência estética: sem ordem declarada, ela vem do plano de execução e muda entre
execuções. Um teste que compara listas passa hoje e falha na semana que vem sem ninguém tocar
em nada, e uma tela que se reordena sozinha faz quem compara duas capturas concluir que algo
mudou.
