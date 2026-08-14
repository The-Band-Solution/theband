# Data model — coletar só o que mudou

**Feature** `020-coletar-so-o-que-mudou` · **Data**: 2026-08-14

A feature **não cria entidade**. Ela acrescenta um estado, e muda o significado de duas colunas
que já existem — e a mudança de significado é a parte que precisa estar escrita.

---

## O que entra

### `syncs.mode` — `"complete"` ou `"incremental"`

| | |
|---|---|
| Tipo | texto, com `check_constraint` — estado nunca é string livre |
| Padrão | `"complete"`, que é o que toda execução gravada até hoje foi |
| Nulo | não |

**Por que uma coluna, e não derivação.** As outras situações deste repositório são derivadas de
evento — a da ferramenta é, e a issue #178 tirou uma coluna que discordava dos eventos. Aqui é o
contrário: o modo é uma **decisão tomada no início da execução**, não um estado que muda depois.
Derivá-lo exigiria reconstruir a decisão a partir do que a execução fez, e uma execução
incremental que não achou nada é indistinguível de uma completa num banco vazio.

**Quem lê**: a tela, para dizer o que aquela execução foi; e a rede de segurança da FR-012, para
saber quando foi a última completa.

---

## O que muda de significado

### `observed_repositories.issues_collected_at`

**Hoje**: quando as issues daquele repositório foram gravadas pela última vez.

**Passa a ser**: quando aquele repositório foi **percorrido por inteiro** pela última vez.

A diferença aparece na coleta interrompida. Hoje o campo é gravado ao gravar issues; passa a ser
gravado **ao terminar o repositório**, e só então.

> **É a FR-010, e é antiacoplamento temporal.** Gravar antes faria a coleta seguinte pular um
> repositório que não foi terminado — e o pulo seria permanente, porque o critério de pular olha
> justamente este campo. Uma interrupção congelaria o repositório para sempre, sem erro e sem
> aviso.

### `decomposition_links.last_observed_at` — o que a comparação significa

O valor não muda. O que muda é **contra o que ele é comparado**.

| | Hoje | Passa a ser |
|---|---|---|
| Universo | todos os pais do repositório | os pais **efetivamente percorridos** nesta execução |
| Leitura de "não apareceu" | "a origem não declara mais" | a mesma coisa — mas agora é verdade também na coleta incremental |

Sem esta mudança, uma coleta que relê 34 de 4295 issues marcaria os vínculos dos outros 4261 pais
como ausentes. A marca não deixaria de funcionar: **marcaria tudo**.

---

## O que não muda, e é o que garante que nada se perde

| Campo | Continua sendo |
|---|---|
| `collected_at` | quando o registro foi visto pela primeira vez |
| `last_observed_at` | quando foi visto pela última vez — em issue, vínculo, designação, rótulo |
| `no_longer_observed_at` | quando a plataforma concluiu que a origem não o mostra mais |
| `raw_payloads` | preservado por execução, e é sobre ele que o reprocessamento trabalha |

**Nada é apagado, e nada muda de forma.** Uma issue que não entrou na janela de uma coleta
incremental **não** é tocada: não ganha marca, não perde vigência, e o `last_observed_at` dela
continua sendo o da última vez em que ela foi de fato vista. Que é a verdade.

---

## Invariantes que os testes têm de afirmar

1. **Duas coletas sem atividade na origem não mudam data alguma** — nem `last_observed_at`, nem
   `issues_collected_at` dos repositórios pulados.
2. **Nenhum vínculo é marcado num repositório que não foi percorrido.**
3. **Coleta interrompida no meio de um repositório não grava `issues_collected_at` dele**, e a
   seguinte o percorre inteiro.
4. **A soma bate**: `records_created + records_updated + inalterados + pulados` é o total
   percorrido.
5. **Uma coleta completa depois de várias incrementais produz o mesmo estado** que uma sequência
   só de completas — é a idempotência do princípio III, e é o que a rede de segurança precisa
   garantir.
