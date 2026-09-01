# Implementation Plan: O domínio próprio, e a origem que passa a ser declarada

**Branch**: `feat/054-dominio-proprio` | **Date**: 2026-09-01 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/054-dominio-proprio/spec.md`

## Summary

A plataforma passa a atender em dois endereços ao mesmo tempo, e a lista de
origens aceitas para a conexão viva passa a ser **declarada** em vez de derivada
do endereço que gera links. O trabalho de código é pequeno e cabe em três
arquivos; o trabalho de verdade é **provar os invariantes** que a correção fácil
quebraria — ausência restringe, e a medida cobre o socket, não o HTTP.

O resto da feature não é código: é a ordem dos passos no provedor de DNS e no
painel, que vira seção do runbook. Errar essa ordem produz exatamente os
sintomas que esta feature existe para eliminar, e nenhum teste os pegaria.

## Technical Context

**Language/Version**: Elixir 1.17, Erlang/OTP 27

**Primary Dependencies**: Phoenix 1.8 (endpoint e transporte do socket), Bandit

**Storage**: nenhuma mudança — esta feature não toca o banco

**Testing**: ExUnit; o alvo testável é uma função pura sobre a lista de origens

**Target Platform**: contêiner Linux atrás de dois intermediários (o proxy do
Dokploy e, agora, o da rede que está à frente dele)

**Project Type**: web — monólito modular Phoenix

**Performance Goals**: nenhuma nova; a mudança é de configuração de aceitação de
conexão, e não entra em caminho quente

**Constraints**: a lista de origens MUST mudar sem novo release (FR-006); a
ausência de declaração MUST restringir (FR-007)

**Scale/Scope**: dois endereços hoje; a lista aceita N, e é isso que a torna
resposta e não remendo

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio | Situação |
|---|---|
| **I. Domínio pelas ontologias** | não se aplica — nenhum conceito de domínio muda. Endereço público é ambiente, não é entidade observada |
| **III. Proveniência e idempotência** | não se aplica — nada é coletado nem gravado |
| **V. Monólito modular multitenant** | preservado; a mudança é do endpoint, acima de qualquer tenant |
| **VI. Spec Kit antes do código** | cumprido — spec e checklist escritos antes deste plano |
| **VII. Gates e revisão independente** | os 14 gates rodam; a revisão independente é pedida ao abrir o PR e **conferida depois de pedir** (L89, desta mesma sessão) |
| **VIII. Desenho que o problema justifica** | ver as quatro decisões abaixo, com as três respostas cada |
| **X. Responsabilidade única** | o módulo novo faz uma coisa: transformar declaração em lista de origens |
| **XI. Estado conferido, sinal nunca silenciado** | a medida de aceitação lê o socket, e o veredito dos gates é o código de saída lido em comando separado |

### As decisões de desenho, com as três respostas (princípio VIII)

**1. Um módulo pequeno com função pura para montar a lista de origens.**

- *Que problema resolve*: o FR-005 e o FR-007 são invariantes — sem declaração,
  restringe; nunca "aceita todas". Invariante que não é testado não é invariante,
  e `config/runtime.exs` **não é testável**: roda uma vez, no boot, fora do
  alcance do ExUnit.
- *Existe agora ou é previsão*: **existe agora**. Sem o módulo, o SC-006 não tem
  como ser provado, e o caso que mais importa — o valor vazio — passaria
  despercebido.
- *O que fica pior*: uma indireção. Quem lê `runtime.exs` para saber quais
  origens valem precisa abrir outro arquivo. É o preço de poder testar, e está
  pago por um teste que reprova se a ausência passar a liberar.

**2. A lista vem de uma variável de ambiente própria, separada do endereço que
gera links.**

- *Que problema resolve*: hoje as duas coisas são o mesmo valor, e por isso
  publicar um segundo endereço quebra o socket de um dos dois. São perguntas
  diferentes: *que endereço a plataforma escreve nos links* e *por onde as
  pessoas chegam*.
- *Existe agora ou é previsão*: **existe agora** — o domínio foi comprado, e o
  endereço antigo continua respondendo.
- *O que fica pior*: mais uma variável para quem opera configurar errado. Mitigado
  porque a ausência é o comportamento de hoje (FR-005): quem não mexer não quebra
  nada, e quem mexer errado recebe recusa visível, não silêncio.

**3. NÃO escrever registro próprio para a recusa de origem.**

- *Que problema resolveria*: nenhum. O Phoenix **já** registra a recusa em nível
  de erro, nomeando a origem que tentou (`Phoenix.Socket.Transport`, no ramo que
  devolve 403). O FR-008 já está atendido pelo que existe.
- *Existe agora ou é previsão*: o problema **não existe**. Escrever nosso registro
  seria padrão sem problema — o que o princípio VIII chama de antipadrão.
- *O que ficaria pior*: duas mensagens para o mesmo evento, e a nossa competindo
  com a da biblioteca no dia em que a biblioteca mudar. O que o plano faz é
  **provar** que a mensagem existe, com um teste que a captura.

**4. NÃO criar entidade nem tabela de "endereços declarados".**

- *Que problema resolveria*: nenhum que a variável não resolva. Endereço público é
  configuração de ambiente, e o FR-006 exige justamente que ele mude **sem
  release** — uma tabela exigiria migração, tela e cuidado de tenant para um dado
  que não é do domínio.
- *Existe agora ou é previsão*: **previsão**, e das ruins: a de que um dia alguém
  vá querer administrar endereços pela interface.
- *O que ficaria pior*: um conceito novo na rede sem ontologia que o sustente, e
  uma tela para manter. A `data-model.md` desta feature registra a ausência de
  entidade como decisão, não como esquecimento.

## Project Structure

### Documentation (this feature)

```text
specs/054-dominio-proprio/
├── spec.md
├── plan.md              # este arquivo
├── research.md          # Fase 0
├── data-model.md        # Fase 1 — declara a ausência de entidade, com a razão
├── quickstart.md        # Fase 1 — como medir, incluindo o socket
├── contracts/
│   └── origens-aceitas.md
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

```text
lib/the_band_web/
└── origens.ex                    # NOVO — a função pura que monta a lista

config/
└── runtime.exs                   # passa a declarar check_origin pela função

docs/producao/
└── runbook.md                    # NOVA seção §9 — a ordem dos passos do domínio

test/the_band_web/
└── origens_test.exs              # NOVO — os invariantes, violação primeiro
```

**Structure Decision**: monólito Phoenix já existente. Um arquivo novo em
`lib/the_band_web/` porque a decisão é da borda web — não é domínio, não é
tenant, e não pertence a `lib/the_band/`. O teste espelha o caminho, como o resto
do repositório.

## Complexity Tracking

Nenhuma violação do Constitution Check a justificar. As quatro decisões de
desenho estão registradas acima, e **duas delas são decisões de NÃO fazer** — o
que o princípio VIII pede explicitamente que apareça no plano.
