# Modelo de dados — Feature 008

**Uma coluna.** Nenhuma tabela nova, nenhuma removida, nenhum estado novo, nenhum índice novo.

---

## `syncs.interrupted_by_user_id`

| Coluna | Tipo | Nulo | Nota |
|---|---|---|---|
| `interrupted_by_user_id` | `binary_id`, FK para `users` | **sim** | nulo = **quem encerrou foi a plataforma** |

### O nulo é afirmação, não lacuna

| valor | significa |
|---|---|
| preenchido | **uma pessoa** decidiu encerrar, e o registro diz quem |
| nulo, com `status = interrupted` | **a plataforma** encerrou, porque o trabalho não existia mais |
| nulo, com outro `status` | não houve encerramento por decisão — a execução terminou ou falhou por conta própria |

Ler o nulo como "não se sabe quem" seria errado: a plataforma **sabe** que não foi pessoa. É a
mesma natureza de `no_longer_observed_at`, que afirma ausência em vez de registrar desconhecimento.

### Por que **sem** check constraint exigindo autor

`observed_repositories.excluded_by_user_id` **tem** constraint —
`observed_repositories_exclusion_has_author` — porque exclusão só acontece por decisão de alguém.

Aqui há **dois encerradores legítimos**, e exigir autor forçaria uma das duas mentiras: um
usuário-sistema falso, ou o encerramento automático atribuído a quem não decidiu.

### O que esta coluna **não** faz

| Não faz | Por quê |
|---|---|
| guardar o id do trabalho na fila | identificador de infraestrutura no domínio — R3 |
| guardar o estado do trabalho | é lido para decidir, e não copiado; princípio II |
| substituir `error_reason` | uma diz **quem**, a outra diz **por quê**; juntar apagaria uma das duas |

---

## O que o encerramento escreve, e o que preserva

**Escreve**: `status`, `finished_at`, `error_reason`, `interrupted_by_user_id`.

**Preserva, sempre** — FR-004:

| Preservado | Por quê importa |
|---|---|
| `sync_checkpoints` | é o que permite retomar; apagar faria o trabalho recomeçar do zero |
| `raw_payloads` do `sync_id` | é a evidência do que foi coletado naquela execução |
| `records_collected`, `created`, `updated`, `skipped` | a execução trouxe isso, e continua tendo trazido |

**Encerrar não é apagar.** Muda o estado e diz por quê.

---

## Os quatro estados continuam quatro

```text
running ──→ completed     terminou, e trouxe o que trouxe
        ──→ failed        o trabalho executou e falhou
        ──→ interrupted   não terminou, e não vai terminar
```

`interrupted` já cobria interrupção pedida. Passa a cobrir também abandono pelo processo, e a
**distinção vive no motivo e no autor** — não num estado novo. Um `stuck` a mais obrigaria toda
consulta de estado a saber que ele existe, e a tela a explicar a diferença entre dois estados que
levam à mesma ação: coletar de novo.

## Os motivos, por causa

| Causa | Motivo gravado |
|---|---|
| trabalho descartado | a falha que o trabalho registrou, com o número de tentativas |
| trabalho não existe mais | `o processo que a executava não existe mais` |
| decisão humana | `encerrada por <pessoa>`, com o que ela informou |

**Um motivo genérico apagaria a distinção entre falha transitória e permanente** — a distinção que
custou 899 issues fora de circulação (L29).
