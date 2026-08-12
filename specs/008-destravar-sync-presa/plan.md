# Plano de implementação: destravar a sincronização presa

**Feature**: `specs/008-destravar-sync-presa/` · **Branch**: `009-destravar-sync-presa`
**Spec**: [spec.md](spec.md) · **Pesquisa**: [research.md](research.md)
**Constituição**: v1.4.0, dez princípios · **Origem**: issue #175

**O número da branch difere do diretório de propósito.** O diretório é `008` porque era o próximo
livre em `specs/`; a branch é `009` porque `009-aceitacao-sprint-006` já existe como branch de
documento, e duas branches com o mesmo número não se distinguem no `git branch`. Mesma razão de R5
da feature anterior.

---

## Summary

Uma execução de coleta cujo trabalho morreu deixa de bloquear a ferramenta. Encerra sozinha, com o
motivo que a causa determina, e sem apagar nada.

Medido: **2 execuções já foram destravadas por SQL**, há **1 trabalho executando desde 2026-08-09**
num nó que não existe mais, e **5 descartados** — dois deles por um módulo que não existe no
repositório.

## O que este plano descobriu lendo a dependência, e o que a análise corrigiu depois

Três leituras de fonte, e duas mudaram o desenho:

| Antes de ler | Depois de ler |
|---|---|
| "o resgate automático cuida do órfão" | ele resgata por **tempo puro** — `state == "executing" and attempted_at < cut`, e **nada mais**. Nenhuma verificação de nó vivo. Resgataria coleta viva, e ela rodaria duas vezes |
| "handler de telemetria pega o descarte" | o resgate muda linha **em SQL** e emite telemetria de *plugin* — o handler de evento de job **nunca veria** esse descarte |
| "quatro estados significam trabalho ativo" | são **cinco**: `Oban.Job.states/0` tem oito, e faltava `suspended`, que significa trabalho pausado — vai executar |

**A análise mudou a decisão central desta feature.** A versão anterior configurava o resgate com
`rescue_after` de 60 minutos e administrava o risco pelo valor do tempo. A pergunta *"existe
proteção além do tempo?"* tem resposta na implementação: **não existe**. E a constante envelhece com
o crescimento da coleta — 135 repositórios hoje, e a coleta mais longa já em 16 min 25 s.

**O resgate saiu.** A plataforma encerra a execução órfã, e a coleta nova recoleta — seguro porque a
gravação é por chave natural. Menos capacidade, e **nenhum caminho** para execução dupla.

**E a análise achou um terceiro caminho de travamento** que ninguém tinha visto: abrir a execução e
criar o trabalho são operações separadas, e **o resultado da criação é descartado**. Se ela falhar,
o registro fica `running` sem nada para executá-lo.

## Technical Context

| | |
|---|---|
| Linguagem | Elixir 1.20.2 / OTP 29 |
| Framework | Phoenix 1.8.9 + LiveView |
| Fila | Oban 2.23.1, filas `ingestion` e `transformation` |
| Persistência | Ecto + PostgreSQL 17 |
| Escala | 32 execuções registradas, 41 trabalhos na fila (podados em 7 dias) |
| Execução legítima mais longa | **16 min 25 s**, 3 641 registros |

---

## Constitution Check

### I. Domínio organizado pelas ontologias — **conforme**

Nenhum conceito novo. "Execução de coleta" é camada de plataforma, e sempre foi: `syncs` não é
tabela de ontologia. O autor do encerramento é atributo de um registro de plataforma.

### II. Fonte externa não é domínio — **conforme, e reforçado**

O estado do trabalho na fila é **lido para decidir** e **não copiado** para o registro. É a mesma
regra aplicada à API do GitHub: consultar não é absorver. R3 recusou a coluna `oban_job_id`
justamente por isso.

### III. Proveniência e idempotência (NÃO NEGOCIÁVEL) — **conforme, e é o centro da feature**

O motivo e o autor **são** proveniência do encerramento: quem decidiu, e por quê. E FR-014 exige
idempotência explícita — encerrar duas vezes não altera o primeiro motivo nem o primeiro autor.

**Recoletar** depende da idempotência que já existe: chave natural na gravação, upsert. Se ela não
valesse, encerrar a execução órfã obrigaria a limpar o que ela coletou — e limpar é o que a
plataforma não faz.

### IV. Semântica declarada em YAML versionado — **não se aplica**

Nenhum conceito, regra ou mapeamento novo. Nada a declarar na base de conhecimento.

### V. Monólito modular multitenant — **conforme**

A decisão vive em `TheBand.Ingestion`, atrás da fronteira, recebendo `%Tenant{}`. Execução de outro
tenant responde **não encontrado** — FR-013.

O trabalho periódico atravessa tenants por natureza: ele reconcilia o que estiver preso, em
qualquer tenant. Isso **não** é vazamento de escopo — é manutenção da plataforma, e nenhum dado de
um tenant chega a outro. A distinção está declarada aqui para não parecer descuido.

### VI. Spec Kit e sprint backlog antes do código — **conforme**

Spec, checklist, pesquisa, este plano, data-model, contrato e quickstart antes da primeira linha. É
a terceira feature seguida na ordem certa.

### VII. Quality gates e revisão independente — **conforme por construção**

Dez gates por `mix gates`. O contrato vem antes da primeira função pública, em
[contracts/](contracts/stuck-sync-reconciliation.md).

### VIII. Desenho que o problema justifica — **conforme, com quatro padrões e cinco recusas**

Ver a seção abaixo. **A recusa mais importante é a telemetria**, e a razão é técnica, não estética.

### IX. Ontologias modulares e autônomas — **não se aplica**

A feature não atravessa fronteira entre ontologias. `syncs` e `oban_jobs` são plataforma.

### X. Responsabilidade única, em módulo e em tela — **conforme, e decidiu contra criar submódulo**

A tela de sincronizações continua respondendo uma coisa: *o que aconteceu nas coletas*. Encerrar uma
execução presa é parte dessa pergunta — não é painel de fila, e FR-015 fecha o escopo.

E o princípio decidiu contra `Ingestion.Reconciliation`: um submódulo para uma função é divisão por
antecipação. `Ingestion` é um módulo só neste projeto, diferente de `WorkItems` e `CMPO`.

---

## Registro dos padrões introduzidos (princípio VIII)

### P1 — A carência da execução recém-aberta, e o resultado da criação conferido

**Qual problema concreto resolve?** Dois: a corrida entre abrir o registro e o trabalho existir — no
intervalo, a execução tem a assinatura exata de "presa" —, e a criação de trabalho que **falha** sem
ninguém conferir, deixando o registro `running` para sempre.

**O problema existe agora?** A corrida, sim, em toda abertura de coleta. A falha na criação é
caminho aberto: o resultado é descartado hoje, então se já aconteceu, ninguém saberia.

**O que fica pior?** Uma constante de tempo a mais — um minuto —, e constante de tempo é o que
envelhece. Mitigação: ela cobre uma corrida de **milissegundos**, com três ordens de grandeza de
margem, e não cobre falha nenhuma: falha na criação encerra **na hora**, com motivo próprio.

### P2 — `Oban.Plugins.Cron` e um trabalho periódico de reconciliação

**Qual problema concreto resolve?** FR-006: o bloqueio precisa sair sem ninguém abrir a tela. E
cobre o caso que a telemetria não cobriria — o trabalho que morreu com o nó, sem emitir evento
nenhum.

**O problema existe agora?** Sim: os 5 descartados nunca encerraram os registros deles.

**O que fica pior?** Um trabalho a mais rodando a cada 5 minutos, para sempre, mesmo quando não há
nada preso — e uma configuração de agendamento que ninguém lê até quebrar. O custo é consulta
pequena numa tabela de 41 linhas.

E um custo que a análise nomeou: ele **compete por slot** na fila `ingestion`, que tem concorrência
5. Com cinco coletas em andamento, a reconciliação espera — o destravamento atrasa, e não deixa de
acontecer. Aceito: fila própria para um trabalho de 5 em 5 minutos é desenho por antecipação, e o
gatilho de revisão é a fila passar a ter espera observável.

Mitigação: o trabalho é **idempotente e silencioso quando não acha nada** — nenhum log de
"reconciliei 0", que é ruído que treina a pessoa a ignorar o log.

### P3 — A decisão de reconciliar, em `TheBand.Ingestion`

**Qual problema concreto resolve?** Decidir se uma execução `running` ainda tem trabalho vivo, e
encerrá-la quando não tem, com o motivo que a causa determina.

**O problema existe agora?** Sim, e é a feature.

**O que fica pior?** `Ingestion` cresce, e passa a conhecer a forma dos args da fila. É acoplamento
real, declarado em R3, com critério de reversão escrito.

### P4 — `syncs.interrupted_by_user_id`, anulável e sem constraint

**Qual problema concreto resolve?** Distinguir encerramento por decisão humana de encerramento pela
plataforma. FR-009 exige, e sem a coluna as duas coisas ficariam indistinguíveis no registro.

**O problema existe agora?** Sim: os dois encerramentos manuais que aconteceram não têm autor
registrado em lugar nenhum — só no `error_reason` que eu escrevi à mão no SQL.

**O que fica pior?** Uma coluna anulável a mais, e a tentação de ler nulo como "não se sabe". A
mitigação é a tela: ela diz **"the platform"** por extenso, nunca `—`.

### Padrões **recusados**, e por quê

| Recusado | Por quê |
|---|---|
| **`Oban.Plugins.Lifeline`** | resgata por tempo puro, **sem verificar se o processo vive** — `basic.ex:189`. A constante envelhece com o crescimento da coleta, e no dia em que a coleta passar dela há duas execuções da mesma coleta sem aviso. É a L02, e administrar isso por constante é o que ela proíbe |
| claim do sync pelo trabalho, para proteger o resgate | resolveria de verdade, e é desenho maior que a feature — para recuperar 16 minutos de coleta. `DynamicLifeline`, que faz isso, é do Oban Pro |
| **handler de telemetria de job** | não veria o descarte feito por plugin, que muda linha em SQL e emite telemetria de *plugin*; e handler não registrado é sucesso silencioso — L22/L23/L26 |
| coluna `oban_job_id` no sync | identificador de fila dentro do domínio, e contradiz a decisão já escrita em `enqueue/3` — R3 |
| decidir por idade do sync | não distingue coleta viva de coleta morta, e FR-005 proíbe encerrar coleta viva |
| status novo — `stuck`, `abandoned` | `interrupted` já significa "não terminou e não vai terminar"; o que faltava era motivo e autor |
| `Ingestion.Reconciliation` como submódulo | divisão por antecipação para uma função — princípio X |
| `rescue_after` de 5 minutos | resgataria a coleta de 16 minutos no meio, e ela rodaria duas vezes — L02 |

---

## Project Structure

```text
specs/008-destravar-sync-presa/
├── spec.md          15 FR, 11 SC, 3 user stories, 5 casos de borda
├── research.md      R1 a R6 — R1 e R2 vêm da fonte da dependência
├── plan.md          este documento
├── data-model.md    uma coluna
├── contracts/
│   └── stuck-sync-reconciliation.md
├── quickstart.md    V1 a V8
└── checklists/requirements.md
```

```text
config/config.exs                          + Cron, com o intervalo explícito
lib/the_band/ingestion.ex                  + a decisão, e o motivo por causa
lib/the_band/ingestion/sync.ex             + interrupted_by_user_id no cast
lib/the_band/jobs/reconcile_stuck_syncs.ex + o trabalho periódico
lib/the_band_web/live/sync_live/index.ex   + a ação e quem encerrou
priv/repo/migrations/*_add_interrupted_by_user_id.exs
```

---

## Fases, e por que esta ordem

### F1 — A decisão, e o motivo por causa

A função em `Ingestion`, a coluna de autor, e os motivos distintos. **Primeiro porque é o que os
três gatilhos chamam** — implementar gatilho antes da decisão produziria a decisão escrita três
vezes, que é o que FR-007 proíbe.

Entregável sozinha? **Não visível**, e é a exceção declarada: a função sem gatilho não destrava
nada. É a razão de F2 vir no mesmo sprint — a L21 proíbe entregar função pública sem consumidor.

### F2 — O gatilho automático

`Cron` na configuração, e o trabalho periódico chamando a decisão de F1. **Sem `Lifeline`** — R1.

**Aqui o bloqueio sai sozinho**, e é o valor central da feature — SC-001 e SC-002 passam a valer.

### F3 — A tela

Reconciliar ao carregar, a ação de encerrar com confirmação, e **quem encerrou** por extenso.

**Por último**, porque é a única parte que depende das duas anteriores para ter o que mostrar.

---

## Riscos

| Risco | Mitigação |
|---|---|
| **resgatar coleta viva e duplicar registros** | **eliminado**: o resgate automático não entra. Órfão é encerrado, e a coleta nova recoleta com upsert |
| encerrar coleta que acabou de começar | carência de 1 minuto, três ordens de grandeza acima da corrida real |
| trabalho que não nasce e ninguém confere | o resultado da criação passa a ser conferido, e a falha encerra na hora com motivo próprio |
| lista de estados ativos escrita de memória | o teste compara com `Oban.Job.states/0`, e não com uma lista copiada |
| encerrar sync de coleta viva | a decisão exige **ausência de trabalho ativo**, nunca idade; teste com job `executing` de verdade |
| a ligação por args se perder em silêncio | os args são escritos no mesmo módulo que os lê; o contrato exige a chave, e o teste falha sem ela |
| ler nulo de autor como "não se sabe" | a tela escreve **"the platform"** por extenso; SC-007 exige distinguir |
| o trabalho periódico virar ruído | silencioso quando não acha nada — log só quando encerra algo |
| dois gatilhos encerrando ao mesmo tempo | FR-014: encerrar o já encerrado não muda motivo nem autor; a decisão só age sobre `running` |

---

## Complexity Tracking

| Item | Custo | Aceito porque |
|---|---|---|
| um plugin de fila (`Cron`) | uma configuração que ninguém lê até quebrar | é o único gatilho que vê **estado** em vez de evento |
| recoletar em vez de retomar | ~16 min de consulta repetida à origem, no pior caso medido | é o preço de **não** ter caminho para execução dupla |
| trabalho periódico a cada 5 min | consulta pequena, para sempre | é o único gatilho que vê **estado** em vez de evento, e sobrevive a reinício |
| `Ingestion` conhece a forma dos args | acoplamento à fila | a alternativa punha identificador de fila no domínio; critério de reversão escrito em R3 |
| coluna anulável de autor | um nulo a mais para interpretar | sem ela, decisão humana e automática ficam indistinguíveis |

---

## Reavaliação da constituição, pós-desenho

Dez princípios: oito conformes, dois não aplicáveis (IV e IX). **Três** padrões introduzidos, **oito**
recusados — o resgate automático entre eles, depois de a análise mostrar que ele não verifica nada
além do tempo.

O princípio III é o que sustenta a feature: o motivo com o autor é proveniência do encerramento, e
**recoletar só é seguro porque a gravação é por chave natural**.

O princípio VIII produziu as duas recusas mais valiosas, e as duas pareciam o caminho óbvio: a
telemetria, que não veria o descarte feito em SQL; e o **resgate automático**, que a primeira versão
deste plano tinha aceito com uma constante de tempo por mitigação. A pergunta *"o que fica pior?"*
não tinha resposta honesta ali — o que fica pior é a plataforma coletar duas vezes, e o número
duplicado passar por correto.
