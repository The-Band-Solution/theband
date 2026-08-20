# T026 — Percurso do quickstart

**Feature**: 027 · **Data**: 2026-08-20 · **Issue**: [#358](https://github.com/The-Band-Solution/theband/issues/358)

O registro que a T026 pede: passo a passo, com o que apareceu, e o que divergiu.

## Como este percurso foi feito, e o que isso limita

**Os sete passos não foram percorridos na tela.** Foram verificados contra o que as quatro
rodadas já gravadas dizem, mais o código que decide cada comportamento.

Isso vale para os passos 1, 3, 4 e 5 — cada um tem no banco ou no código a evidência que o
passo pede. **Não vale para os passos 2, 6 e 7**, e a razão de cada um está escrita abaixo.

Declarar o percurso completo com base nisso seria o mesmo defeito que esta casa mais
combate: ausência de evidência lida como evidência. O que segue diz, por passo, se foi
observado, derivado ou não alcançado.

---

## O que o banco tinha, e é a base do percurso

Credencial de provedor: **uma**, `openai`, validada em 2026-08-16, sem falha registrada.
`default_model` **vazio**.

Automação: **ligada** em 2026-08-16 15:15:21, nunca desligada.

Quatro rodadas, todas com `trigger = "manual"`, 88 pessoas selecionadas:

| rodada | desfecho | geradas | no_material | observation_ended | no_new_work | tokens entrada | duração |
|---|---|---:|---:|---:|---:|---:|---|
| `afc1a255` 08-16 15:15 | completed | 30 | 50 | 4 | **4** | 548.799 | 6 min 35 s |
| `123feb65` 08-16 23:17 | completed | 34 | 50 | 4 | 0 | 651.338 | 6 min 53 s |
| `6ef2fe89` 08-17 00:09 | **ended_early** | 34 | 5 | 0 | 0 | 651.338 | — |
| `2c961687` 08-18 11:18 | completed | 59 | 25 | 4 | 0 | 799.355 | 10 min 25 s |

As somas fecham em 88 nas três completas. A `6ef2fe89` soma 39, o que é consistente com
encerrar no meio.

---

## Passo 1 — Sem chave, nada liga (`FR-011`)

**Não alcançado por observação.** O tenant tem credencial gravada desde 2026-08-16, e apagá-la
para reproduzir o estado inicial destruiria a credencial de trabalho de quem administra.

**Coberto por teste**: `automation_test.exs` exercita `:no_credential`.

**O que fica em aberto**: se a *tela* diz o que o requisito manda — que não é possível ligar
sem credencial da organização — em vez de só recusar. O teste afirma o retorno; a frase na
tela é outra coisa.

---

## Passo 2 — Ligar dispara a primeira rodada (`FR-004a`, `FR-019`)

**Derivado, não observado.** O evento `enabled` está gravado às 15:15:21 de 2026-08-16, e a
rodada `afc1a255` começou **no mesmo segundo**, 15:15:21.

Isso é exatamente o que a `FR-004a` promete: ligar não espera o dia 1. A evidência é forte —
os dois carimbos coincidem ao segundo — e ainda assim é derivação de registro, não observação
de tela.

**O que fica em aberto**: a tela mostrando *ligada, por `<e-mail>`, em `<data>`*. O
`actor_user_id` está gravado (`2d59f3d4`), mas quem o percorreu não viu a frase.

---

## Passo 3 — A rodada seleciona por motivo (`FR-006`, `FR-014`)

**Observado no registro, e um número da spec estava errado.**

Os três motivos de pulo aparecem **separados** nas quatro rodadas, nunca agregados — é a
`SC-005`, e ela passa.

**Divergência 1 — a estimativa de duração estava alta.** A seção *Antes* do quickstart diz
"de 15 a 35 min com 34 pessoas". Medido: 34 pessoas em **6 min 53 s**, e 59 pessoas em
**10 min 25 s**. Cerca de **10,6 s por pessoa gerada**.

A estimativa não errou por pouco: errou por um fator de 2 a 5. Corrigido no quickstart.

**Divergência 2 — "geradas ≈ 6 com N=10" não se aplica a rodada manual.** Nenhuma das quatro
gerou 6; geraram 30, 34, 34 e 59. A razão é o escopo, e é o assunto do passo 5.

---

## Passo 4 — A segunda rodada não começa (`FR-003`)

**Não alcançado por observação**, e a razão é que reproduzi-lo exige uma rodada em curso —
ou seja, uma rodada nova contra o provedor.

**Coberto por teste**: `run_worker_test.exs`.

**Indício de registro**: nenhuma das quatro rodadas tem `started_at` dentro da janela de
outra. As duas de 08-16 estão separadas por oito horas; a de 08-17 começou 45 min depois de a
anterior fechar. Nenhuma sobreposição — o que é consistente com o guarda, e não prova ele.

---

## Passo 5 — Rodar de novo não duplica (`R2`, `FR-006`)

**O passo estava errado, e o erro tem dez minutos de idade.**

O quickstart entrou no commit `4221225`, às **12:22:02** de 2026-08-16. O escopo da rodada
manual mudou para `:todas` em `fa12e89`, às **12:32:01** do mesmo dia. Dez minutos depois, e
o passo nunca foi atualizado.

`RunWorker.escopo/1`:

```elixir
defp escopo(%{trigger: "manual"}), do: :todas
defp escopo(_), do: :mudou
```

E `Regeneration.geracao_seguinte/6` com `:todas` gera sem consultar N nem M. É decisão
registrada no `@moduledoc` — *"pedir a rodada é querer ver escrito"* —, não descuido.

**A evidência bate com o desenho, não com o passo.** Só `afc1a255` registrou `no_new_work`,
e ela é de 15:15 — **anterior** à mudança de escopo. As três seguintes: zero.

**Divergência 3, e é correção de spec.** O passo foi partido em 5a (rodada manual gera para
todo mundo, `no_new_work` em zero, por desenho) e 5b (`no_new_work` é da rodada automática).

O que sobrevive dos dois lados: **dois textos da mesma pessoa sobre o mesmo material** é falha
do guarda em qualquer escopo. Isso é `R2`, e não foi violado em nenhuma das quatro.

---

## Passo 6 — Chave revogada encerra a rodada (`FR-016`)

**Não alcançado, e deliberadamente.** Revogar a chave no provedor é ação na conta de quem
administra, com efeito fora desta plataforma. Não é minha para tomar.

**Mas a `FR-016` foi exercitada por acidente, e passou.** A rodada `6ef2fe89` encerrou no meio
com:

```
ended_reason: "ArithmeticError em Material.veredito — job descartado pelo Oban após
               3 tentativas às 00:17:56Z; consertado em 2026-08-17"
```

As 34 pessoas já geradas **continuaram gravadas**, e o desfecho é `ended_early` — distinto de
`completed` e de não ter executado. É o comportamento que o passo 6 descreve, por uma causa
que ele não previa.

**O que isso não prova**: que a mensagem de encerramento por credencial não exibe a chave
(`FR-013`). Essa causa específica não ocorreu. Vale notar que `credential_last_four` é coluna
da rodada, então o desenho já separa "os quatro últimos" do segredo.

---

## Passo 7 — Desligar vale da próxima (`FR-018b`)

**Não alcançado.** Exige desligar durante uma rodada, e não há rodada em curso. Reproduzir
custa uma rodada contra o provedor.

**Coberto por teste**: `automation_test.exs`, para o par ligar/desligar com autor.

**O que fica em aberto**: o histórico na tela mostrando *quem desligou e quando*. Só há um
evento gravado — `enabled` —, então a tela nunca renderizou a linha de `disabled`.

---

## O achado que não estava em nenhum passo

**A rodada automática nunca disparou.** As quatro rodadas são `manual`. O cron é dia 1 às
03:00, a feature entrou depois de 1º de agosto, e o primeiro disparo real é **1º de
setembro**.

Consequência: o escopo `:mudou` — o único que produz `no_new_work` — está coberto por teste e
**não** por observação. Todo o comportamento mensal da feature é, hoje, promessa verificada
apenas em suíte.

Até setembro, o caminho se verifica chamando `Regeneration.select(tenant, :mudou)` direto,
sem esperar o cron.

**E o custo não pode ser medido**, o que bloqueia a T024. `FR-014` grava tokens de **entrada**;
`FR-021` pede **custo**. O número de saída chega no mesmo mapa `usage` e é descartado.
Registrado como [#454](https://github.com/The-Band-Solution/theband/issues/454) — rodar uma
rodada nova não destrava, porque ela gravaria de novo só metade da conta.

---

## Veredicto da T026

**Não concluída.** Três dos sete passos não foram alcançados, e dois deles exigem ação na
conta do provedor.

| passo | estado |
|---|---|
| 1 — sem chave, nada liga | não alcançado; exige apagar a credencial de trabalho |
| 2 — ligar dispara a rodada | derivado do registro; a tela não foi vista |
| 3 — seleção por motivo | **observado**; duas divergências corrigidas |
| 4 — segunda rodada não começa | não observado; indício consistente |
| 5 — rodar de novo não duplica | **o passo estava errado**; corrigido |
| 6 — chave revogada encerra | não alcançado; `FR-016` exercitada por outra causa |
| 7 — desligar vale da próxima | não alcançado |

### O que falta, e de quem é

**De quem administra**: uma rodada contra o provedor com alguém olhando a tela, para os passos
1, 2, 4 e 7; e a decisão de revogar uma chave de teste para o passo 6.

**Da plataforma**: a [#454](https://github.com/The-Band-Solution/theband/issues/454), sem a
qual a T024 não fecha em rodada nenhuma.

O que **não** falta: as três divergências viraram correção de spec, que é metade do que a T026
define como "feita".
