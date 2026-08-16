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

Uma organização com pessoas observadas e material acima dos pisos da 026. No banco de desenvolvimento, 34 pessoas passam.

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

Espere a rodada fechar (de 15 a 35 min com 34 pessoas; muito menos se poucas passarem na regra de mudança).

**Esperado** na linha da rodada:

- **consideradas** = todas as pessoas do tenant que a `select/1` avaliou;
- **geradas** ≈ 6 com N=10, na base medida em 2026-08-16 (`SC-002`);
- **puladas** separadas em `no_material`, `no_new_work` e `observation_ended` — três números, nunca um só (`SC-005`);
- **falhas** e **tokens de entrada**.

Abra uma pessoa gerada: o perfil dela é indistinguível de um pedido a mão — mesma marca de derivado, mesma proveniência (`FR-015`).

---

## 4. A segunda rodada não começa — `FR-003`

Com a rodada da etapa 3 ainda aberta, peça uma rodada manual.

**Esperado**: recusa nomeada — *já existe uma rodada em execução* —, e nenhuma segunda linha na lista.

---

## 5. Rodar de novo não duplica — `R2`, `FR-006`

Dispare uma rodada manual logo depois de a anterior fechar.

**Esperado**: quase todo mundo pulado por `no_new_work` — ninguém fechou tarefa nova nesse intervalo —, e **nenhum** perfil novo para quem acabou de ser gerado. Se aparecerem dois textos da mesma pessoa sobre o mesmo material, o guarda da entrada falhou.

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
| **custo real de uma rodada completa** — `FR-021` | não | **sim**, e precisa ser medido antes de N e M serem fixados |
| **duração real com 34 pessoas** | não | **sim** |

As duas últimas são medições contra o provedor de verdade. Nenhuma suíte as substitui, e nenhuma delas pode ser declarada por estimativa.
