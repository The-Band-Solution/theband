# Quickstart: provar que a rodada funciona

**Feature**: 027 · **Data**: 2026-08-16

Como verificar a feature ponta a ponta. Não traz código de implementação — traz o que rodar e o que precisa aparecer.

## Antes

```bash
set -a && . ./.env && set +a      # a chave mestra da cifragem mora aqui
mix ecto.migrate
mix knowledge.validate            # reprova se N ou M faltarem no YAML — FR-009
mix phx.server
```

Uma organização com pessoas observadas e material acima dos pisos da 026. No banco de desenvolvimento, 88 pessoas são selecionadas e de 30 a 59 passam nos pisos, conforme o material que entrou.

**A estimativa de duração desta seção estava alta.** Medido em 2026-08-20: 34 pessoas em **6 min 53 s**, 59 pessoas em **10 min 25 s** — cerca de **10,6 s por pessoa gerada**. O percurso está em [percurso-t026.md](./percurso-t026.md).

---

## 1. Sem chave, nada liga — `FR-011`

1. entre em `/ai` como admin, sem credencial gravada;
2. entre em `/profiles`.

**Esperado**: a tela diz que a geração está desligada, e que **não é possível ligar sem credencial da organização**. O botão de ligar não promete uma execução que não vai acontecer.

---

## 2. Ligar dispara a primeira rodada — `FR-004a`, `FR-019`

1. grave a chave em `/ai` — ela é conferida contra `/models` antes de ser aceita;
2. volte a `/profiles` e ligue.

**Esperado**: a tela passa a mostrar *ligada, por `<seu e-mail>`, em `<data>`*, e uma rodada **aberta** aparece na lista sem esperar o dia 1.

---

## 3. A rodada seleciona por motivo — `FR-006`, `FR-014`

Espere a rodada fechar (~10,6 s por pessoa gerada, medido; muito menos se poucas passarem na regra de mudança).

**Esperado** na linha da rodada:

- **consideradas** = todas as pessoas do tenant que a `select/1` avaliou;
- **geradas**: numa rodada **manual**, quase todas as que passam nos pisos — o escopo é `:todas`. O `≈ 6 com N=10` da `SC-002` vale para a rodada **automática**, que usa `:mudou` e nunca disparou até 2026-08-20 (ver o passo 5b);
- **puladas** separadas em `no_material`, `no_new_work` e `observation_ended` — três números, nunca um só (`SC-005`);
- **falhas** e **tokens de entrada**.

Abra uma pessoa gerada: o perfil dela é indistinguível de um pedido a mão — mesma marca de derivado, mesma proveniência (`FR-015`).

---

## 4. A segunda rodada não começa — `FR-003`

Com a rodada da etapa 3 ainda aberta, peça uma rodada manual.

**Esperado**: recusa nomeada — *já existe uma rodada em execução* —, e nenhuma segunda linha na lista.

---

## 5. Rodar de novo não duplica — `R2`, `FR-006`

> **Corrigido em 2026-08-20, ao percorrer a T026.** A versão anterior deste passo esperava
> `no_new_work` numa rodada **manual**, e isso está errado desde o mesmo dia em que foi
> escrito: este arquivo entrou às 12:22 (`4221225`), e o escopo da rodada manual mudou para
> `:todas` às 12:32 (`fa12e89`). Dez minutos.
>
> `RunWorker.escopo/1` é explícito: `manual → :todas`, qualquer outro → `:mudou`. Com
> `:todas`, `Regeneration.geracao_seguinte/6` gera sem consultar N nem M — o que é decisão
> registrada, não descuido: quem clica quer ver escrito.

Este passo tem **duas metades**, e só a segunda vale para rodada manual.

### 5a. Rodada manual gera para todo mundo — por desenho

Dispare uma rodada manual logo depois de a anterior fechar.

**Esperado**: quase todo mundo **gerado de novo**, e `no_new_work` em **zero**. Os pulos que
sobram são `no_material` e `observation_ended` — de fato, não de política.

Medido no banco de desenvolvimento: quatro rodadas manuais, e só a primeira
(`afc1a255`, de 2026-08-16 15:15, anterior à mudança de escopo) registrou
`no_new_work` — quatro. As três seguintes registraram **zero**.

### 5b. `no_new_work` é da rodada automática, e ela nunca rodou

O escopo `:mudou` só vale para o gatilho da `FR-004`, no dia 1 às 03:00.

**Nenhuma rodada automática aconteceu até 2026-08-20**: as quatro do banco têm
`trigger = "manual"`. A feature entrou depois de 1º de agosto, então o primeiro disparo
real é **1º de setembro**.

Isso significa que o caminho que produz `no_new_work` está coberto por teste
(`regeneration_test.exs`, os seis ramos da `due?/3`) e **não** por observação. Até setembro,
este passo se verifica assim:

```elixir
# escopo :mudou explícito, sem esperar o cron
Regeneration.select(tenant, :mudou)
```

e conferindo que quem acabou de ser gerado sai como `{:skip, :no_new_work}`.

**O que continua valendo dos dois lados**: se aparecerem **dois textos da mesma pessoa sobre
o mesmo material**, o guarda da entrada falhou. Isso é `R2`, e vale em qualquer escopo.

---

## 6. Chave revogada encerra a rodada — `FR-016`

Grave uma chave válida, comece uma rodada, e revogue a chave no provedor durante a execução.

**Esperado**: a rodada fecha como **encerrada no meio**, com o motivo; as pessoas já geradas continuam gravadas; a tela distingue isso de *não executou*. Nenhuma mensagem exibe a chave (`FR-013`).

---

## 7. Desligar vale da próxima — `FR-018b`

Desligue durante uma rodada.

**Esperado**: a rodada corrente termina; a próxima automática não acontece; o histórico mostra **quem desligou e quando**.

---

## O que a suíte cobre, e o que só o passo manual cobre

| verificação | teste automatizado | manual |
|---|---|---|
| seleção por motivo, os seis ramos da `due?/3` | `test/the_band/profiles/regeneration_test.exs` | |
| checkpoint: rodar duas vezes não duplica | `test/the_band/profiles/run_worker_test.exs` | |
| encerramento por falha de credencial | idem, com Mox devolvendo `401` | |
| ligar/desligar com autor, e `:no_credential` | `test/the_band/profiles/automation_test.exs` | |
| tela: três estados, contagens por motivo, isolamento entre organizações | `test/the_band_web/live/rodada_test.exs` | |
| **custo real de uma rodada completa** — `FR-021` | não | **bloqueado**, ver abaixo |
| **duração real** | não | **medido**: ver a tabela de rodadas abaixo |
| **a rodada automática de fato disparando** | `run_worker_test.exs` | **não, até 1º de setembro** |

As três últimas são medições contra o provedor de verdade. Nenhuma suíte as substitui, e
nenhuma delas pode ser declarada por estimativa.

### Duração, medida

Quatro rodadas manuais no banco de desenvolvimento, 88 pessoas selecionadas:

| rodada | desfecho | geradas | tokens de entrada | duração |
|---|---|---:|---:|---|
| `afc1a255` 08-16 15:15 | completed | 30 | 548.799 | 6 min 35 s |
| `123feb65` 08-16 23:17 | completed | 34 | 651.338 | 6 min 53 s |
| `6ef2fe89` 08-17 00:09 | **ended_early** | 34 | 651.338 | — |
| `2c961687` 08-18 11:18 | completed | 59 | 799.355 | **10 min 25 s** |

A estimativa de "15 a 35 min com 34 pessoas" na seção *Antes* estava alta: 59 pessoas
levaram 10 min 25 s. Cerca de **10,6 s por pessoa gerada**.

`6ef2fe89` encerrou no meio por `ArithmeticError` em `Material.veredito` — o job foi
descartado pelo Oban após três tentativas, e o motivo está gravado em `ended_reason`. É a
`FR-016` funcionando para uma causa que ela não previa, e o defeito foi consertado em
2026-08-17.

### O custo está bloqueado, e não por falta de rodada

`FR-014` manda gravar "o total de **tokens de entrada**". `FR-021` manda medir "o **custo** de
uma rodada completa". Os dois não fecham: token de saída é cobrado a uma taxa mais alta que o
de entrada, e a soma de entrada não permite chegar ao valor.

O número de saída **já chega** na resposta do provedor. `GenerateWorker.tokens_de_entrada/1`
lê `usage["prompt_tokens"] || usage["input_tokens"]` do mesmo mapa que carrega o de saída, e
descarta o resto.

Rodar uma rodada nova não resolve: ela gravaria de novo só metade da conta. Registrado como
issue própria.
