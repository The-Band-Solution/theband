# Implementation Plan: a jornada de entrar e sair, vista por quem opera

**Branch**: `feature/802-tracing-signoz` | **Date**: 2026-10-03 | **Spec**: [spec.md](spec.md)

**Input**: [spec.md](spec.md), [seguranca.md](seguranca.md), [ADR 0005](../../docs/adr/0005-telemetria-da-jornada.md)
com a emenda de 2026-10-03

> **A ADR 0005 e as dependências foram aceitas em 2026-10-03** (D5), com D1–D7 decididas. **O
> código ainda espera**: o código espera a #1227 mergeada; a #887 tem as tarefas entregues (#871, #872, #873 fechadas) e espera aceitação (D6). As tarefas que tocam `lib/` e `mix.exs` têm a T003
> no `Pronta quando`.

## Summary

Cada passo da J1 — abrir a entrada, entrar com senha, sair, a queda de sessão, definir e trocar a
senha — vira **um span** com desfecho (`concluiu`, `falhou`, `abandonou`) e, se falhou, **o
motivo que o código já produz hoje** e só manda para o log. O span nasce de um evento
`:telemetry` emitido por `TheBand.Tenants.AccessEvents.passo/1` (que só aceita átomos, ids e o
correlator) **depois** da decisão — no caso da entrada, depois da transação, para que o custo não
varie por motivo —, é traduzido por **um** handler, é **reconstruído** por **um** exportador que só
deixa sair o nome de passo declarado, os sete atributos permitidos com o valor na forma certa e um
recurso fixo, e chega por OTLP/HTTP ao coletor do SigNoz numa rede dedicada. Quem
opera lê no SigNoz, por túnel SSH, num painel versionado.

## Technical Context

**Language/Version**: Elixir 1.20.2 / OTP 29 (Dockerfile:17); `mix.exs` exige `~> 1.17`

**Primary Dependencies** (novas, aceitas em 2026-10-03, D5): `opentelemetry_api == 1.5.0`, `opentelemetry == 1.7.0`,
`opentelemetry_exporter == 1.11.0`, e `grpcbox ~> 0.18.0` declarada só pelo teto; transitivas
`ts_chatterbox 0.16.0`, `hpack_erl 0.3.0`, `ctx 0.6.0`, `gproc 1.2.0`, `acceptor_pool 1.0.1`,
`tls_certificate_check 1.35.0`, `ssl_verify_fun 1.1.7` — onze pacotes (ADR 0005, E6; seguranca.md, S9).
Já presentes: `telemetry 1.4.2`, `telemetry_metrics`, `telemetry_poller`.

**Storage**: nenhuma tabela, nenhuma migração (data-model §0). O span mora no ClickHouse do SigNoz.

**Testing**: ExUnit; o exportador real (filtro) com destino `:otel_exporter_pid` (research R4).
Nenhum Mox novo.

**Target Platform**: Phoenix Release no VPS Contabo via Dokploy; SigNoz no mesmo VPS (D3).

**Project Type**: web-service (monólito Phoenix).

**Performance Goals**: custo de uma entrada com a telemetria ligada ≤ 5% acima da mediana sem
ela (SC-006); emissão **igual** entre motivos (FR-009, R9).

**Constraints**: nada de segredo em span (FR-005); exportação sem amostragem (FR-016); o
SigNoz com teto de 3 GB (ADR E3); a aplicação sobe sem a telemetria (FR-015).

**Scale/Scope**: ~300 spans/dia na J1 com 50 pessoas — < 1 MB por semana (ADR E3, medido a
≈ 190 bytes/span).

## Constitution Check

| princípio | como esta feature cumpre | situação |
|---|---|---|
| I. Domínio pelas ontologias | jornada **não** é conceito de ontologia (ADR, decisão 4); nada entra em `ontology/` | ✅ |
| II. Fonte externa não é domínio | não toca conector | ✅ n/a |
| III. Proveniência e idempotência | o span não é dado de domínio; não há ingestão | ✅ n/a |
| IV. Semântica em YAML versionado | a taxonomia (passos, motivos, cenário de origem) em `rules/journey_entrar_e_sair.yaml`, com gate (R7, R8) | ✅ |
| V. Monólito multitenant | `tenant.id` em todo passo com conta; o painel é de quem opera a plataforma, e nenhuma organização o vê (ADR E5) | ✅ |
| VI. Spec Kit e sprint backlog | spec → segurança → plano → tarefas; **sem** issues e sem sprint até o aceite da ADR | ✅ em curso |
| VII. Gates e revisão independente | `seguranca.md` por quem não escreveu o desenho; `mix gates` em cada tarefa de código | ✅ |
| VIII. Desenho que o problema justifica | ver *Decisões de desenho*, abaixo, camada a camada | ✅ |
| IX. Ontologias modulares | não toca | ✅ n/a |
| X. Responsabilidade única | emissor (`AccessEvents`), tradutor (`Telemetria.Jornada`), filtro (`Telemetria.Exportador`): três razões para mudar, três módulos | ✅ |
| XI. Estado conferido, sinal nunca silenciado | handler com `rescue` que **conta**; descarte do filtro e da fila **contado**; coletor conferido por recepção, e não por *healthy* | ✅ |
| Restrições: dependência nova | onze pacotes (três diretas, `grpcbox` pelo teto, sete transitivas), com versão, data, licença e manutenção na ADR E6; `hex.audit` e `deps.audit` antes do merge | ✅ D5, 2026-10-03 |
| Restrições: ADR | ADR 0005 emendada e **aceita** em 2026-10-03 | ✅ |
| §14.0 segurança primeiro | [seguranca.md](seguranca.md) feita antes deste plano, por quem não escreveu o desenho: 3 altos (S1, S2, S6), 12 médios, 1 baixo; as emendas que não são da pessoa mantenedora já estão na spec e na ADR. #887 e #1222 antes do código; #1162 antes do deploy | ⏳ o PR #1227; D1–D7 decididas em 2026-10-03 |

**Gate**: passa **condicionado** aos três ⏳. Nenhuma violação a justificar em *Complexity Tracking*.

## Decisões de desenho — as três perguntas do princípio VIII, camada a camada

### 1. O evento `:telemetry` emitido por `AccessEvents`

- **Problema concreto**: os 17 motivos já existem e morrem no log (`access_events.ex:66-140`); a
  pergunta da pessoa mantenedora não é respondível sem agregá-los. **Existe agora**.
- **Por que no domínio, e não no controller**: o controller só vê `:invalid_credentials`
  (`session_controller.ex:35`), e **tem de continuar só vendo isso** (seguranca.md, S4): pôr o
  motivo a uma linha do `put_flash` é o caminho mais curto para o oráculo de enumeração.
- **Por que depois da transação**: `recusar/2` roda dentro do `FOR UPDATE` num ramo e fora no
  outro (`auth.ex:47-73`); emitir ali faria o custo variar por motivo (S4, FR-009).
- **O que fica pior**: `verificar_com_trava/2` passa a devolver um relator interno em vez do
  resultado final, e `authenticate` ganha aridade 3 só para levar o correlator. O domínio passa a
  conhecer o **nome** de um evento de telemetria — não o OpenTelemetry.

### 2. O handler `TheBand.Telemetria.Jornada`

- **Problema**: traduzir evento em span **fora** do domínio (ADR, decisão 1), e sobreviver a
  falha sem sumir (ADR S5). **Existe agora**: o `:telemetry` desanexa handler que falha, e o
  `LogDaConsulta` da #1222 já precisou do mesmo cuidado.
- **O que fica pior**: mais um handler anexado no boot, cuja ordem importa (antes dos filhos);
  um `catch kind, reason` (S11: `rescue` não pega `exit` nem `throw`) que, se mal escrito, esconde
  bug — por isso ele **conta** em `:counters`, loga só o tipo, e o `telemetry_poller` confere a
  cada rodada que o handler segue anexado.

### 3. O exportador-filtro `TheBand.Telemetria.Exportador`

- **Problema**: S1 da ADR exige *"filtro no exportador, não disciplina de quem escreve"*. Sem ele,
  o primeiro instrumentador ligado depois (Phoenix, Ecto) exporta por fora do handler.
  **Existe agora** como requisito normativo, e a #1222 mostrou que o caminho que ninguém escreveu
  ainda é o que vaza.
- **Padrão**: decorador sobre `:opentelemetry_exporter` — a única implementação do behaviour que
  envolve. Não é abstração para um segundo backend: é o ponto único onde a lista permitida é
  aplicada.
- **O que fica pior**: um módulo entre o SDK e o exportador oficial, que precisa acompanhar o
  formato do registro `span` entre versões do SDK — por isso as versões ficam fixadas com `==`, e
  o teste das sentinelas quebra se o registro mudar.

### 4. A taxonomia em `rules/` (e não em `journeys/`)

- research R7. **Problema**: o gate precisa de uma lista declarada. **Por que não a pasta da
  ADR**: uma jornada não paga schema e validador novos. **O que fica pior**: `rules/` mistura dois
  tipos de declaração até a terceira jornada.

### 5. O plug do correlator

- **Problema**: correlacionar abertura e tentativa para derivar `abandonou` (FR-010). **Existe
  agora**: o pedido nomeia o abandono como desfecho. LiveView não escreve cookie (R5).
- **O que fica pior**: um valor a mais na sessão do Phoenix para todo visitante da tela de
  entrada, inclusive anônimo e robô; e uma regra de apagamento que precisa ser **a mesma** em todo
  desfecho, porque o cookie é legível pelo cliente (S4, S5).

### 6. O profile `telemetria` no compose

- **Problema**: medir localmente sem tocar no Postgres de desenvolvimento (FR-014). Precedente:
  os profiles `producao` e `backup` do `compose.yaml`.
- **O que fica pior**: ~2,6 GB de imagens para quem liga o profile; nada para quem não liga.

### O que **não** entra, e por quê

Instrumentadores automáticos (ADR E6), tabela própria de passos, *tail sampling*, log no
SigNoz, painel dentro da aplicação. Cada um é ou outra fatia, ou generalidade sem problema hoje.

## Project Structure

### Documentation (this feature)

```text
specs/074-jornada-entrar-e-sair/
├── spec.md
├── seguranca.md          # avaliação do agente security, antes deste plano
├── plan.md               # este arquivo
├── research.md           # R1–R12
├── data-model.md         # taxonomia, correlator, atributos
├── quickstart.md         # validar local e o roteiro 👤 do Dokploy
├── contracts/jornada.md  # o evento, as funções de AccessEvents, o span, o handler, o filtro
├── checklists/requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
lib/the_band/tenants/access_events.ex        # passo/1 — a única função nova, só de emissão
lib/the_band/tenants/auth.ex                 # authenticate/3; relator interno; emite depois da transação
lib/the_band_web/plugs/current_scope.ex      # a queda de sessão emite o passo
lib/the_band_web/live/session_live/new.ex    # abrir_a_entrada no mount conectado
lib/the_band_web/telemetry.ex                # o poller loga os contadores e confere o handler
lib/the_band/telemetria/jornada.ex           # NOVO — o handler
lib/the_band/telemetria/exportador.ex        # NOVO — o filtro (lista permitida)
lib/the_band/application.ex                  # anexa o handler antes dos filhos
lib/the_band_web/plugs/jornada_de_entrada.ex # NOVO — gera e substitui o correlator na sessão
lib/the_band_web/controllers/session_controller.ex  # sair, definir e trocar a senha emitem
lib/the_band_web/router.ex                   # o plug só no GET /sign-in
config/config.exs, config/test.exs, config/runtime.exs
mix.exs, mix.lock                            # D5, aceitas
priv/knowledge_base/rules/journey_entrar_e_sair.yaml
deploy/signoz/                               # o compose gerado e fixado (ADR E2) e o painel
compose.yaml                                 # profile telemetria
docs/producao/runbook.md                     # §2 (variáveis) e um § novo para o SigNoz

test/the_band/telemetria/
├── regua_test.exs
├── sentinelas_test.exs
├── taxonomia_test.exs
├── handler_resiliente_test.exs
└── tempo_por_motivo_test.exs
test/support/spans.ex                        # extrai o registro :span (research R4)
```

**Structure Decision**: `TheBand.Telemetria` é um subsistema novo **fora** de `ontology/` e de
`tenants/`, como `TheBand.Repo.LogDaConsulta` é fora de `repo/`: ele não pertence a nenhum domínio,
e nenhum domínio depende dele (só do nome do evento).

## Como o teste prova o desfecho certo e a ausência de segredo

1. `config/test.exs`: `config :opentelemetry, traces_exporter: :none, processors:
   [{:otel_simple_processor, %{}}]` — síncrono, sem rede;
2. em cada caso, `:otel_simple_processor.set_exporter(TheBand.Telemetria.Exportador,
   %{destino: {:otel_exporter_pid, self()}})` — **o filtro real no caminho** (R4);
3. o caso faz as requisições reais (`ConnTest`) dos quatro passos com sentinelas em **todo**
   campo de credencial (seguranca.md, S15): a senha tentada, o identificador digitado, o e-mail da
   conta, o valor do `password_hash`, a senha temporária, a atual e a nova da troca, o cookie
   `_the_band_key` inteiro e o token de CSRF — e `assert_receive {:span, span}` para cada passo;
4. **desfecho**: casa `name`, `attributes["outcome"]` e `attributes["failure.reason"]`;
5. **ausência**: serializa o span inteiro (`inspect(span, limit: :infinity)`) e afirma que
   nenhuma sentinela aparece — nome, atributos, eventos, links, status e recurso —, em claro, em
   Base64 e em `inspect`, como o PR #1227 faz com o TOTP;
6. **o teste prova que mede**: antes do `refute`, um `assert` de que pelo menos um span chegou
   (lição da #1222: log vazio passaria o `refute` sem provar nada);
7. **defeitos a injetar, um por vez** (seguranca.md, S1): (a) sem o filtro; (b)
   `inspect(changeset)` em `failure.reason`; (c) `OpenTelemetry.Tracer.set_attribute("depuracao",
   senha)` direto no span corrente, por fora do handler; (d) `OTEL_RESOURCE_ATTRIBUTES` com uma
   sentinela; (e) `record_exception` com a sentinela na mensagem. O teste reprova nos cinco. Copiar
   o arquivo antes de injetar (memória: *git checkout apaga trabalho não commitado*).

**O teste troca só o destino, nunca o filtro** (S15): se o teste trocasse o exportador inteiro, o
filtro de produção nunca rodaria nele, e o verde não provaria nada.

## A ordem, e o que bloqueia o quê

| item | bloqueia |
|---|---|
| ~~aceite da ADR 0005 e dos onze pacotes (D5)~~ | **feito em 2026-10-03** |
| PR #1227 (#1222) mergeado em `development` (D6) | toda tarefa que toca `lib/` ou `mix.exs` — §14.0, item 2 |
| #887 (064/US3) | **não bloqueia**: as tarefas #871, #872 e #873 estão fechadas; a US espera só a aceitação do Product Owner |
| #1162 (distribuição Erlang em `0.0.0.0`) | a implantação do SigNoz no mesmo VPS (opção A) |
| os seis itens de S6 com evidência lida | a implantação do SigNoz |

## Complexity Tracking

Nenhuma violação.
