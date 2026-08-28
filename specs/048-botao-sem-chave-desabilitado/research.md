# Research — 048 Gerar só com chave

Medições de 2026-08-28 na main pós-sprint 023.

## R1 — A chave é do tenant, e a leitura de estado já existe

**Decisão**: a tela lê `TheBand.AI.origem_da_chave/1` — que já devolve os três
fatos: `{:tenant, cred}` (gravada), `{:ambiente, last4}` (herdada do processo),
`:nenhuma`. Nenhuma função de leitura nova.

**Medido**: `ProviderCredential` tem chave por `tenant_id + provider`
(`lib/the_band/ai.ex:30`). NÃO há chave por organização — a frase da tela ("This
organisation has no provider key") usa "organisation" coloquialmente para o tenant.

**Correção de spec registrada**: o edge case "organização com chave e outra sem,
no mesmo tenant" descrevia um modelo que não existe (chave é uma por tenant —
decisão da pessoa mantenedora em 2026-08-28: "o IA pode ser por tenant").
Corrigido na spec no mesmo commit deste plano.

## R2 — "Chave utilizável" difere por botão, e a diferença já é regra da casa

**Decisão**: dois predicados de habilitação, um por caminho:

| Botão | Utilizável quando | Por quê |
|---|---|---|
| Generate profile / Generate again (página da pessoa) | `origem_da_chave != :nenhuma` | o worker usa `AI.opcoes/1`, que cai na chave do ambiente — é como o dev roda |
| Turn on / Run now (geração mensal) | `AI.fetch/1` = `{:ok, _}` (credencial do TENANT) | `Runs.credencial/1` recusa ambiente por FR-011 da 044 — a conta de uma organização não paga pela outra |

**Medido**: `lib/the_band/profiles/runs.ex:313` (tenant-only, comentário FR-011);
`lib/the_band/ai.ex:71` (`opcoes/1` com fallback de ambiente).

## R3 — A defesa do caminho da pessoa NÃO existe hoje, e a spec supunha que sim

**Medido**: `Profiles.request/3` (`lib/the_band/profiles.ex:79`) enfileira o job
SEM conferir chave; sem chave nenhuma, a falha só aparece no worker
(`{:error, {:rejeitada, "no key was given"}}` no cliente HTTP) — e a tela fica em
"perfil pendente" sem desfecho: o padrão sucesso-silencioso que mais reincide na
casa. A rodada mensal, ao contrário, recusa antes (`{:error, :no_credential}`).

**Decisão**: `Profiles.request/3` ganha a guarda — recusa `{:error, :sem_chave}`
quando `origem_da_chave == :nenhuma`, ANTES de enfileirar. É o que torna o
cenário 4 da spec verdadeiro (evento disparado por fora do botão é recusado pelo
domínio). Contrato de `request/3` atualizado antes do código.

**Correção de spec registrada**: a assumption "a defesa já existe
(Profiles.request recusa sem chave)" era falsa para o caminho da pessoa —
corrigida no mesmo commit, com esta medição como razão. A feature deixa de ser
"só comunicação": inclui UMA guarda de domínio, mínima, no ponto que a spec já
exigia existente.

## R4 — A frase adaptada a quem lê usa o que o hook já assina

**Decisão**: a frase da lacuna usa `@operacao_menu` (assign do hook da 046/FR-023,
uma consulta por navegação, já presente em toda LiveView): quem opera recebe o
caminho ("configure it in AI provider"); quem não opera recebe "someone who
operates this organisation configures it". Nenhuma consulta nova (edge case da
spec: custo por página, uma vez).

**Medido**: `lib/the_band_web/live/hooks.ex` assina `:operacao_menu` para o menu;
`/ai` é área operacional desde o PR #567.

## R5 — Reavaliação a cada render, sem recarregar

**Decisão**: o estado da chave entra como assign no `mount` das duas telas
(1 leitura por página, edge case atendido). "Habilita sem recarregar a
plataforma" = voltar à página (patch/navigate) reavalia; não há subscription de
credencial — criar PubSub para isso seria estrutura sem problema real
(princípio VIII): a chave muda numa tela operacional e quem a configura é quem
volta para gerar.
