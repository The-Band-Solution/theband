# Protótipo — o aviso de fila parada em `/syncs` (issue #801, parte 3)

| | |
|---|---|
| endereço | https://claude.ai/artifact/P1rCXLJdM4EqQCoUYZLjci (privado) |
| cópia que vale | `syncs-queue-stalled.html`, nesta pasta |
| publicado | 2026-10-01, versão 1 |
| aprovação | **Decided 2026-10-01**, pela pessoa mantenedora: D1–D8 aprovadas, Q1–Q3 pela opção A (a recomendação). Republicado no mesmo endereço |
| contrato do verificador | `docs/producao/saude-da-fila.md`, `TheBand.Saude.fila/2` (PR #1029) |
| tela atual | `lib/the_band_web/live/sync_live/index.ex` |

## O dado, e de onde veio

**Real**, do banco de desenvolvimento (`the_band_dev`, contêiner `the_band_postgres`), lido
em 2026-10-01 às 10:15:13 UTC, numa transação `BEGIN READ ONLY` só com `SELECT`:

| fato | valor | consulta |
|---|---|---|
| último job completado | 2026-10-01 10:15:00 UTC | `max(completed_at)` em `oban_jobs`, `state='completed'` |
| job esperando (`available`) | nenhum | `min(scheduled_at)` em `available` → nulo |
| estados em `oban_jobs` | 1 157 `completed`, nada mais | `group by state` |
| completados na última hora | 14 | `completed_at > now() - 1h` |
| workers completados | `ReconcileStuckSyncs` 578, `ScheduleDueSyncs` 578, `SyncGitHubEO` 1 | `group by worker` |
| syncs | 4 `completed`, 4 `interrupted`, 2 `failed`, **nenhuma `running`** | `group by status` |
| ferramenta | `example-org`, intervalo `manual` | `connected_tools` |
| última execução (tela 1) | 2026-09-28 12:49 → 15:03 UTC; 1 240 coletados, 601 criados, 588 atualizados, 0 pulados, 55 vínculos sem papel; fases 1 / 64 / 8 / 59 / 131 de 131 / 5 624 de 5 624 / 610 / 28 de 64 | `syncs` e `sync_checkpoints` |

**Exemplo** (marcado `example` na tela): as telas 2, 3 e 4 inteiras. A fila do
desenvolvimento estava andando, e não havia execução `running`. Os números de exemplo
seguem o incidente de 2026-09-04: último job 47 min antes, uma execução que ficou
`running` no meio das issues.

## Decisões (numeradas)

*Decided 2026-10-01* — pessoa mantenedora — todas como propostas: D1–D8 abaixo, e Q1–Q3 pela
opção A (ver a seção das perguntas).

1. **D1 — fato, veredito, ação, nessa ordem.** O horário do último job leva a marca
   `observed`; "parada" leva a marca `derived` e escreve a regra (15 min, três ciclos de
   5 min). O aviso nunca diz *error*, *failure* nem *down*. Cor âmbar e faixa hachurada,
   nunca clay: é conclusão sobre o dado, não falha observada.
2. **D2 — o registro da execução não é reescrito.** O badge `running` fica; ao lado, a marca
   `not advancing · queue stalled`, e as duas afirmações lado a lado ("the run record says"
   / "the queue says"), como manda 055 FR-012.
3. **D3 — só tempos; nenhuma contagem, nenhum worker, nenhum tenant.** `oban_jobs` é
   compartilhada entre tenants, e quem vê `/syncs` pode ter só escopo de organização.
   Contar jobs esperando diria a esse viewer quanto os outros tenants enfileiraram. Mesma
   razão do `/health`.
4. **D4 — o número anda sem recarregar.** Com a fila parada nenhum evento de progresso chega
   à LiveView, e um número calculado no `load/1` congelaria. A tela reconfere a cada minuto
   e mostra a hora da conferência (`checked 10:15 UTC`).
5. **D5 — "Close stuck sync" mantém a regra de hoje.** Execução com trabalho `available` não
   oferece o botão (`Ingestion.interruptible?/1` já é assim), e o cartão diz por quê e manda
   reiniciar primeiro. Execução com job órfão em `executing` mantém o botão e o texto de
   confirmação atuais.
6. **D6 — formato da duração.** `47 min`; `3 h 12 min`; `4 d 2 h`. Sempre com o horário
   absoluto em UTC ao lado. O `espera_em_texto/1` de hoje arredonda `4 d 2 h` para `4 d`,
   e para o aviso isso não basta.
7. **D7 — o caso "nunca completou" escreve a ausência.** `last job finished: absent — none
   on this installation`, e o relógio passa a ser o job esperando mais antigo, que é o único
   que esse caso tem. A execução sem checkpoint diz `no page collected yet` em vez de
   esconder a linha, como faz hoje.
8. **D8 — instalação nova (`:ok` sem histórico e sem espera) não é aviso.** Uma linha com a
   marca `absent`: *no job has run yet*. Desenhada só na tabela dos estados.

> **Dado real substituído por exemplo em 2026-10-01** (decisão P-3, achado S7): o repositório é
> público. Login da organização e números da coleta trocados por `example-org` e valores
> ilustrativos. O artifact privado guarda a versão com o dado real.

## Premissas que a spec carrega até serem contestadas

- **P1 — a seção do runbook precisa existir.** `docs/producao/runbook.md` **não tem** seção
  de fila parada hoje (conferido em `origin/development`, 2026-10-01). O link e os passos do
  aviso dependem dela. Recomendação: escrevê-la na mesma entrega, antes de a tela linkar.
- **P2 — o que a tela afirma sobre produção é só o que está medido.** O healthcheck marca
  `unhealthy` e `/health` responde `503` por construção (mesma regra). *Se o Dokploy
  reinicia sozinho* **não** foi medido, e a tela diz exatamente isso.
- **P3 — avaliação de segurança antes do código.** *Em curso desde 2026-10-01*, por outro agente `security`, em paralelo. A tela passa a mostrar a quem tem escopo
  de organização um estado lido de uma tabela global. D3 reduz isso a tempos, mas é dado
  entre tenants e exposição nova: pede o agente `security`, de quem não desenhou isto.

## Perguntas — respondidas em 2026-10-01 pela pessoa mantenedora, todas pela recomendação

| | pergunta | opções | decisão |
|---|---|---|---|
| Q1 | No estado normal, mostrar a linha discreta da fila? | A. sim (tela 1) · B. nada até parar | ***Decided 2026-10-01*: A** — sem ela, "não há aviso" e "a conferência não rodou" ficam iguais |
| Q2 | Sync e Reprocess com a fila parada | A. desabilitados com a razão ao lado · B. habilitados, com aviso | ***Decided 2026-10-01*: A** — apertar Sync cria outro `running` que não anda, o defeito que o aviso expõe |
| Q3 | A tela precisa de mais do que `fila/2` devolve | A. função de leitura nova ao lado, `fila/2` e `/health` intactos · B. mudar `fila/2` | ***Decided 2026-10-01*: A** — `{:parada, minutos}` não diz qual dos dois casos é, e mudar `fila/2` mexe no contrato do healthcheck por uma necessidade de tela |

## Medidas que precisam de nome na base antes do código (princípio IV)

> **Decisão de implementação, 2026-10-01: estas três NÃO entram em `priv/knowledge_base/`.** O
> princípio IV pede semântica **de domínio** em YAML: necessidades de informação sobre a
> Engenharia de Software medida, com `required_concepts` da rede SEON/Continuum, conferidos pelo
> validador. "A fila do Oban andou" é **sinal de operação da própria plataforma**, e não há
> conceito para ele em ontologia nenhuma da rede. Declarar um seria inventar conceito para caber
> no formato. O contrato do sinal, com regra, limiar e porquê, vive em
> `docs/producao/saude-da-fila.md`. A tabela abaixo fica como registro do que se propôs, e a
> decisão fica no PR, para a revisão contestar.


| nome proposto | o que é | tipo |
|---|---|---|
| `operation.queue.time_since_last_completed_job` | agora − `max(completed_at)` | duração, observada |
| `operation.queue.oldest_waiting_job_age` | agora − `min(scheduled_at)` de `available`, usada só quando nunca houve completado | duração, observada |
| `operation.queue.stalled` | veredito: uma das duas acima ≥ `fila_parada_apos_minutos` (15) | indicador, derivado |

Hoje `priv/knowledge_base/measurements/` não tem nenhuma medida de operação; estas seriam as
primeiras, e a necessidade de informação ("a plataforma está processando trabalho em segundo
plano?") também precisa ser declarada.
