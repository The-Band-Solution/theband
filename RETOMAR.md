# Retomar — 2026-08-19, fim do dia

## O que foi mergeado hoje

**#430, #431, #432, #433, #434, #435, #441, #444, #445, #447, #448.**
Issues fechadas: **#395, #401, #428, #429, #436, #437, #438, #440, #443, #446**.

## O único PR aberto

**[#449](https://github.com/The-Band-Solution/theband/pull/449)** — `041-rastro-do-defeito`,
fecha **#439**.

⚠ **O corpo do PR está com números errados.** Ele foi escrito quando eu media pelo casamento
por `head_sha`; depois troquei para o `statusCheckRollup` da ponta, e os números mudaram:

| | no corpo do PR | correto |
|---|---:|---:|
| integradas vermelhas | 349 | **221** |
| entraram sem check | 2.038 | **1.705** |
| verde | 2.345 | **2.129** |
| não medidas | — | **763** |

**Atualizar o corpo antes de mergear.**

## O que a 041 mudou de fundamental

A pergunta *"tem como saber se o CI funcionou?"* expôs que eu tinha declarado limitação sem
esgotar a origem. O `statusCheckRollup` é campo do **commit** e cobre duas camadas que a
coleta de `workflow_run` não vê — os `check_run` da API de Checks e os `status` da API antiga.

Consequência: **1.705 solicitações entraram sem verificação nenhuma**. Pelo caminho antigo
isso aparecia como "não dá para saber", junto com lacuna de coleta.

## Próximos passos, na ordem que eu recomendaria

### 1. Recoletar as 763 não medidas

São solicitações coletadas antes de eu pedir `statusCheckRollup`. A recoleta usa
`recoleta_rollup.exs` no scratchpad, e roda **uma ferramenta de cada vez** — as três
compartilham a janela de rate limit (issue #446).

### 2. Despachar as cinco decisões que só você pode tomar

**#367, #368, #369, #370, #397.** Cada uma bloqueia uma feature, e nenhuma é implementação.
Vale um bloco de meia hora.

### 3. Fechar duplicatas do backlog

**#400 e #318 são a mesma issue** — "Coletar os comentários das issues" — e **as duas já
foram implementadas** na feature 030. Fechar as duas.

**#317** ("Sugerir papel a partir de evidência") precisa ser conferido: pode ter sido feito.

### 4. O ArgoCD — #442

Quatro decisões antes de qualquer código: qual API, como a ferramenta entra em
`connected_tools` (será o primeiro tipo que não é forja de código), onde o `Application`
encontra o repositório observado, e se *drift* vira conceito novo — a CDRO não tem "estado
divergente".

### 5. O resto do #440, que ficou

O levantamento encontrou **três** mapeamentos sem dado. Dois foram implementados (review e
branch); o terceiro virou o #442. Mas ficaram itens de custo zero:

- **2.137 labels já coletados** e nunca interpretados — falta decidir o conceito
- **`workflow_run.path`** — 13 definições de workflow explicam 15.375 execuções, e faria
  `ci.ap01` apontar o arquivo em vez do nome do job
- **`flow_work_in_progress`** — necessidade declarada, sem resposta possível hoje: exige
  histórico de transição de estado do quadro, que a rede ainda não modela

## Lições registradas hoje

**L61** a **L66**, e as três que mais custaram:

- **L64** — denominador que inclui o caso impossível esconde o sinal. Aconteceu **três
  vezes**: os 83% de amostra de três, os `pull_requests` de 3 em 1.052, e a taxa de 462% com
  unidades diferentes.
- **L66** — script que monta o contexto à mão esconde o contrato que o job real quebra. Foi
  o que deixou o `KeyError :started_at` invisível por duas semanas.
- **Sem número ainda**: *todo teste escrito para pegar um defeito precisa ser rodado contra o
  código defeituoso, no estado exato do defeito.* Aconteceu duas vezes — o teste do
  `started_at` passava com e sem a correção, e o da paginação só reprovava com **os dois**
  ausentes.

## Coletas

| coleta | estado |
|---|---|
| CI (verificações) | **completa** — 151 de 160 repositórios, 15.375 execuções |
| arquivos dos commits | 8.194 de 16.416 — parada |
| `statusCheckRollup` | 4.819 de 5.556 — 763 faltando |

Rodar **uma de cada vez**: as três ferramentas compartilham a janela de 5.000 req/h.

## Um stash que não é meu

`stash@{1}` — `fix/320-axiomas-alcancaveis: meu refactor de axioms sobre o #359 ja mergeado`.
De outra sessão. Não toquei.
