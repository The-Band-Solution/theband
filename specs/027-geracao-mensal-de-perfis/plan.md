# Implementation Plan: Geração mensal dos perfis de competência

**Branch**: `027-geracao-mensal-de-perfis` · **Spec**: [spec.md](./spec.md) · **Data**: 2026-08-16

## Summary

A rodada mensal que escreve os perfis sozinha, a tela que mostra o que ela fez, e a credencial por organização que decide de quem é a conta.

A fatia vertical é: **estado da automação** (ligar/desligar, com autor) → **rodada** (seleção pela regra de mudança, geração sequencial, registro por pessoa) → **tela de administração** que exibe as duas coisas. A credencial já está entregue nesta branch e é a terceira parte, sem a qual a rodada de uma organização gastaria a conta de outra.

Nada aqui muda **o que** o perfil diz. Muda **quando** ele é escrito, e quem pagou por ele.

## Technical Context

| | |
|---|---|
| **Linguagem** | Elixir 1.20 / OTP 29, Phoenix LiveView |
| **Persistência** | PostgreSQL, Ecto, multitenant por `tenant_id` |
| **Agendamento** | `Oban.Plugins.Cron`, já em uso para `ReconcileStuckSyncs` |
| **Trabalho de fundo** | Oban; fila nova `rodadas` com concorrência 1, separada de `perfis` |
| **Borda externa** | a mesma da 026 — `TheBand.Integrations.LLM.HTTP`, agora com `verify/2` |
| **Credencial** | por tenant, cifrada com `TheBand.Encrypted.Binary`; ambiente só em desenvolvimento |
| **Base de conhecimento** | `priv/knowledge_base/rules/profile_thresholds.yaml`, regra nova `regeneration` |
| **Escala medida** | 34 pessoas elegíveis num tenant; rodada completa de 15 a 35 min; ≤ 1,63M tokens de entrada, a recontar |
| **Testes** | ExUnit, Mox **só** na borda HTTP do provedor |

Nenhum `NEEDS CLARIFICATION` restante. As quatro decisões abertas foram tomadas em 2026-08-16 e estão em [spec.md §Clarifications](./spec.md).

## Constitution Check

*GATE: passa antes da Fase 0, e revisto depois da Fase 1.*

| princípio | como esta feature atende |
|---|---|
| **I — domínio vem das ontologias** | nenhum conceito ontológico novo. Rodada, entrada de rodada e estado da automação são **operacionais**: descrevem a plataforma trabalhando, não a organização observada. É a mesma fronteira que separa `syncs` de `eo.person` |
| **II — fonte externa não é domínio** | o provedor de modelo não é fonte de observação e não ganha `connected_tool`; a razão está na migração da credencial e em [research.md R5](./research.md) |
| **III — proveniência e idempotência** | a rodada é retomável por checkpoint em tabela, não em memória. Rodar o mesmo job duas vezes não gera dois perfis da mesma pessoa — a entrada já gravada é o guarda |
| **IV — semântica em YAML** | N e M vão para `profile_thresholds.yaml`, junto dos pisos da 026, porque são a mesma categoria de decisão. Valor ausente reprova `mix knowledge.validate` |
| **V — monólito modular multitenant** | toda consulta leva tenant; a listagem de rodadas é por organização (`FR-017`) |
| **VI — fatia vertical** | a entrega inclui a tela. Sem `/profiles`, a rodada seria infraestrutura sem consumidor visível — e o primeiro enunciado da feature seria "nada ainda" |
| **VII — revisão independente** | PR com revisor pedido à equipe `the-band`. **Esta condição não pode ser satisfeita por mim**, e fica declarada como lacuna |
| **VIII — desenho que o problema justifica** | tabela abaixo |
| **X — uma tela faz uma coisa** | `/profiles` responde *"a geração automática está funcionando?"*. `/ai` responde *"com que conta trabalhamos?"*. `/syncs` responde *"o que foi coletado?"*. Três perguntas, três telas — `FR-024` |

### Os padrões que esta feature introduz

Princípio VIII exige três respostas por padrão. O que já está justificado em `AGENTS.md` §7.7 não é rejustificado.

| padrão | que problema concreto resolve | existe agora? | o que fica pior |
|---|---|---|---|
| **Tabela de entradas por pessoa como checkpoint** (`profile_run_entries`) | a rodada leva de 15 a 35 min e pode morrer no meio; sem checkpoint, a retentativa do Oban regeraria quem já foi gerado, e a tabela somente-acréscimo guardaria os dois textos | **sim** — a duração está medida, e `max_attempts` do Oban é 3 | uma tabela a mais, e as contagens da `FR-014` passam a ser **derivadas** por agregação em vez de lidas de uma coluna. É mais lento e é o que impede contador e realidade divergirem |
| **Estado da automação derivado de eventos**, não de coluna booleana | `FR-019` exige quem ligou **e** quem desligou; um booleano guardaria o estado e perderia o autor | **sim** — é requisito | duas leituras (evento mais recente) onde uma coluna bastaria. É exatamente o desenho que a issue #178 corrigiu em `Sources.situacao/1`, e pelo mesmo motivo: coluna e evento divergem |
| **Fila Oban própria (`rodadas`)** | a fila `perfis` tem concorrência 1; uma rodada de 35 min nela deixaria toda geração pedida a mão esperando | **sim**, aritmética direta da medição | mais uma fila para observar, e duas rodadas de tenants diferentes passam a poder chamar o provedor ao mesmo tempo |
| **Seleção sequencial dentro de um job**, e não um job por pessoa | `FR-016` precisa **encerrar a rodada** quando a credencial falha; com um job por pessoa já enfileirado, encerrar exigiria cancelar jobs — e cancelamento parcial é estado que a tela não sabe nomear | **sim** — é requisito | um job longo, que a fila segura por 35 min. Mitigado pela fila própria e pelo checkpoint, que torna a retentativa barata |

**Nenhum padrão especulativo.** Não há abstração para "quando houver outro provedor" nem para "quando a rodada for diária": a cadência é uma linha de crontab e o provedor tem uma implementação só.

## Project Structure

### Documentation (this feature)

```text
specs/027-geracao-mensal-de-perfis/
├── plan.md              # este arquivo
├── research.md          # Fase 0 — as sete decisões e o que foi recusado
├── data-model.md        # Fase 1 — três tabelas novas
├── quickstart.md        # Fase 1 — como provar que funciona
├── contracts/           # Fase 1 — as funções públicas, antes da implementação
│   ├── automation.md
│   ├── runs.md
│   └── regeneration.md
└── tasks.md             # Fase 2 — /speckit-tasks, não criado aqui
```

### Source Code (repository root)

```text
lib/the_band/
├── ai.ex                             # entregue — credencial por tenant
├── ai/provider_credential.ex         # entregue
└── profiles/
    ├── automation.ex                 # NOVO — ligar, desligar, estado, com autor
    ├── automation_event.ex           # NOVO — schema somente-acréscimo
    ├── regeneration.ex               # NOVO — quem entra na rodada, e por qual motivo não
    ├── runs.ex                       # NOVO — abrir, encerrar, listar, resumir
    ├── run.ex                        # NOVO — schema da rodada
    ├── run_entry.ex                  # NOVO — schema da entrada por pessoa
    ├── run_worker.ex                 # NOVO — a rodada de um tenant, sequencial
    ├── monthly_worker.ex             # NOVO — o cron: enfileira uma rodada por tenant elegível
    └── generate_worker.ex            # ALTERADO — recebe a rodada, devolve o consumo

lib/the_band_web/live/
└── profile_run_live/index.ex         # NOVO — /profiles

priv/repo/migrations/                 # três migrações novas
priv/knowledge_base/rules/profile_thresholds.yaml   # ALTERADO — regra `regeneration`

test/the_band/profiles/
├── automation_test.exs               # NOVO
├── regeneration_test.exs             # NOVO
├── runs_test.exs                     # NOVO
├── run_entry_test.exs                # NOVO
├── run_worker_test.exs               # NOVO
├── monthly_worker_test.exs           # NOVO
├── material_test.exs                 # ALTERADO — a regressão do material acumulado
└── generate_worker_test.exs          # ALTERADO — o consumo devolvido
test/the_band_web/live/
└── rodada_test.exs                   # NOVO
```

**Structure Decision**: monólito modular, como as 26 features anteriores. O novo mora sob `TheBand.Profiles`, que já é o contexto do perfil — a rodada é sobre perfis, e não sobre pessoas nem sobre coleta.

## Constitution Check — revisão depois da Fase 1

O desenho detalhado mudou duas coisas em relação à primeira passagem, e as duas **reforçam** os princípios em vez de pedir exceção:

- **III (idempotência)**: o desenho inicial contava com a retentativa do Oban. A modelagem mostrou que isso não basta — perfil é somente-acréscimo, então retentar geraria texto duplicado. O guarda virou `unique_index [:profile_run_id, :person_id]`, **constraint de banco**, e não só validação de changeset;
- **VIII (booleano no lugar do relator)**: `due?/3` ia devolver booleano. Passou a devolver `:generate` ou `{:skip, motivo}`, porque a `FR-014` conta por motivo e um booleano obrigaria quem chama a redescobrir o porquê.

Nada a registrar em Complexity Tracking por conta da revisão.

## Complexity Tracking

Nenhuma violação de princípio a justificar.

Dois pontos merecem nota, e não são violações:

**A rodada é um job longo.** Trinta e cinco minutos num job Oban é fora do comum neste repositório, onde a coleta pagina em jobs curtos. A alternativa — um job por pessoa — foi recusada por `FR-016`, e a razão está na tabela acima. O custo real é que uma reinicialização do nó no meio da rodada devolve o job à fila, e o checkpoint é o que impede isso de custar dinheiro.

**As contagens são derivadas, e isso é lento de propósito.** `FR-014` pede nove números por rodada, e todos saem de agregação sobre `profile_run_entries`. Guardá-los em colunas seria mais rápido e criaria o defeito que este projeto já teve duas vezes: dois lugares guardando o mesmo fato, e eles discordando. Com 34 entradas por rodada, a agregação é irrelevante.
