# Research: geração mensal dos perfis

**Feature**: 027 · **Data**: 2026-08-16

Sete decisões. Cada uma traz o que foi escolhido, por quê, e o que foi recusado — porque a alternativa recusada é o que explica a escolha daqui a seis meses.

---

## R1 — O agendamento é cron próprio, e não um passo do sync

**Decisão**: `Oban.Plugins.Cron` com uma entrada `0 3 1 * *`, que enfileira `MonthlyWorker`. Ele varre os tenants com automação ligada e credencial gravada, e enfileira uma rodada por tenant.

**Razão**: sincronizar é observar; gerar perfil é interpretar. O sync roda a cada poucos minutos, e pendurar a geração nele faria toda observação custar dinheiro. A separação é a mesma que a plataforma já faz entre `connected_tools` e o provedor de modelo.

O plugin `Cron` já está no projeto, com `ReconcileStuckSyncs` a cada cinco minutos — não é tecnologia nova.

**Recusado**: disparar no fim de cada `sync`, que era a proposta original de agosto; e um `GenServer` com `Process.send_after`, que perde o agendamento a cada reinício e não é observável pela tela do Oban.

---

## R2 — A rodada é um job sequencial com checkpoint em tabela

**Decisão**: um job por tenant, que percorre as pessoas selecionadas **em ordem**, gravando uma linha em `profile_run_entries` a cada desfecho. A retentativa do Oban retoma de onde parou, porque quem já tem entrada nesta rodada não é considerado de novo.

**Razão**: três requisitos empurram para cá ao mesmo tempo.

- `FR-016` manda **encerrar a rodada** quando a credencial falha. Com um job por pessoa, encerrar exigiria cancelar jobs enfileirados, e cancelamento parcial é um estado que a tela não sabe nomear;
- `AGENTS.md` §7.5 exige checkpoint persistido, nunca só em memória;
- os perfis são somente-acréscimo (`FR-015` da 026). Sem o guarda da entrada, a segunda tentativa do Oban gravaria um segundo texto sobre o mesmo material — e a série temporal que a 027 cria passaria a ter pontos duplicados que ninguém pediu.

**Recusado**: um job por pessoa com contadores incrementais na rodada. Mais paralelo, e com dois defeitos: o contador diverge da realidade sob retentativa, e o encerramento por falha de credencial vira cancelamento em massa.

---

## R3 — O estado da automação é derivado de eventos

**Decisão**: tabela `profile_automation_events`, somente-acréscimo, com `event`, `actor_user_id` e `occurred_at`. O estado atual é o evento mais recente do tenant.

**Razão**: `FR-019` quer o autor de **ligar e de desligar**. Um booleano em `tenants` guardaria o estado e perderia o autor; um booleano *mais* uma tabela de auditoria guardaria o mesmo fato em dois lugares.

Este projeto já pagou por isso: a issue #178 corrigiu exatamente esse desenho em `ConnectedTool`, onde uma coluna de situação discordava dos eventos de observação. `Sources.situacao/1` passou a derivar, e o defeito sumiu. Não vale a pena reintroduzir a forma que já falhou aqui.

**Recusado**: coluna `profile_automation_enabled` em `tenants`, com uma tabela de log ao lado.

---

## R4 — N e M vão para o YAML que já existe

**Decisão**: uma regra `regeneration` dentro de `priv/knowledge_base/rules/profile_thresholds.yaml`, com `min_new_closed_tasks: 10` e `max_profile_age_months: 3`. Lida por `KnowledgeBase.rule("profile.thresholds")`.

**Razão**: os pisos de material da 026 já moram lá, e pela mesma razão declarada no próprio arquivo — *"cada um deles é uma decisão sobre o que a plataforma afirma a respeito de gente"*. N e M são a mesma categoria: decidem sobre quem a plataforma escreve neste mês.

`FR-009` exige que valor ausente ou inválido **reprove a validação** da base, e não caia num padrão embutido. Um padrão silencioso faria a rodada usar um número que ninguém escolheu — que é a forma exata do defeito que mais reincidiu neste repositório.

**Recusado**: módulo com `@min_new_tasks 10`, e configuração em `config/runtime.exs`. Os dois escondem a decisão de quem precisa revisá-la.

**Atenção registrada**: o arquivo usa a chave de topo `derivation_rule:` por causa da issue #320 — a chave `rules:` não é reconhecida pelo carregador. A regra nova entra sob a mesma chave que já funciona; consertar o carregador é a issue #320, e não esta feature.

---

## R5 — A credencial é por tenant, e não é uma ferramenta conectada

**Decisão**: tabela própria `ai_provider_credentials`, com o mesmo `Ecto.Type` de cifragem da credencial de coleta. **Já implementada nesta branch.**

**Razão**: os tipos aceitos em `connected_tools` — `github`, `gitlab`, `azure_devops`, `jira`, `sonar` — são todos **fontes de observação**: a plataforma coleta deles e grava proveniência apontando para eles. Um provedor de modelo não produz dado sobre a organização; interpreta o que já foi observado. Guardá-lo lá faria a tela de ferramentas oferecer sincronizar algo que não tem o que sincronizar.

O que se reúsa é o que importa: a cifragem.

**Recusado**: `connected_tools` com `tool_type: "openai"`; e chave única de instalação em variável de ambiente, que é o que a 026 fazia e o que `FR-011` agora proíbe para a rodada.

---

## R6 — O consumo é medido em tokens de entrada, gravado por pessoa

**Decisão**: a borda já devolve `usage` do provedor. A entrada de rodada grava `input_tokens` de cada geração; o total da rodada é `sum` sobre as entradas.

**Razão**: `FR-020` quer o custo visível. Tokens de entrada é o número que o provedor devolve, que domina a conta neste uso (48 mil de entrada contra ~2 mil de saída, medidos), e que não exige a plataforma conhecer a tabela de preços de ninguém — preço muda, token não.

Guardar por pessoa, e não só o total, é o que permite responder *"por que esta rodada custou o dobro da anterior"*.

**Recusado**: converter para moeda na gravação, o que congelaria um preço; e guardar só o total da rodada, o que responde menos pelo mesmo esforço.

---

## R7 — A tela é própria, em `/profiles`

**Decisão**: `TheBandWeb.ProfileRunLive.Index`, rota `/profiles`, perfil `admin`, com duas partes: o estado da automação (ligada/desligada, por quem, quando, com o botão) e a lista de rodadas com os nove números de cada uma.

**Razão**: princípio X. `/ai` responde *com que conta trabalhamos*; `/syncs` responde *o que foi coletado*; esta responde *a geração automática está funcionando*. Três perguntas diferentes.

Juntar automação e credencial na mesma tela pareceria econômico e produziria o efeito errado: ligar a automação e configurar a chave viram o mesmo gesto, quando um é decisão sobre pessoas e o outro é decisão sobre dinheiro.

**Recusado**: uma aba dentro de `/ai`; e um cartão dentro de `/syncs`, que misturaria coleta com interpretação — a fronteira que a `FR-002` existe para manter.
