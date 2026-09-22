# Implementation Plan: o servidor MCP — as perguntas da equipe, respondidas a um agente

**Branch**: `062-servidor-mcp` | **Data**: 2026-09-21 | **Spec**: [spec.md](./spec.md)

**Input**: `specs/062-servidor-mcp/spec.md`

## Summary

Quatro ferramentas MCP que respondem as perguntas da tela da equipe — quem está nela, o que
cada um tem aberto, quanto o trabalho espera por revisão, o que está parado — servidas de
dentro do monólito, autenticadas pelo token da 061, e com **a ressalva viajando dentro de
cada resposta**.

A fatia existe porque a 061 terminou: as quatro perguntas já têm caminho de dados provado em
`GET /api/v1/teams/:id`, `/members` e `/measures` (medido contra o código em 2026-09-21). O
que esta feature acrescenta não é acesso ao dado — é a **forma** que um consumidor que não
sabe perguntar pela ressalva precisa receber.

> **A frase que justifica a feature inteira**: uma pessoa que vê `0,2 h` na tela vê, ao lado,
> *"23 revisadas; outras 79 ainda aguardam, há 46 dias"*. Um agente que recebe `0.2` num
> campo JSON relata `0.2`. A ressalva não some por má-fé — some porque ninguém a pediu.

## Technical Context

**Linguagem**: Elixir 1.20 / OTP, como o resto do repositório.

**Dependência nova**: **uma só** — `{:ex_mcp, "~> 1.5"}`. Escolha medida em
[research.md, D1](./research.md), com o que piora declarado: é biblioteca jovem, e a
mitigação é a camada fina.

**Armazenamento**: nenhum novo. Nenhuma tabela, nenhuma migração. O servidor **não guarda
nada** — nem token, nem escopo, nem resposta (FR-003, FR-005, FR-006).

**Testes**: ExUnit, como o resto. As funções de ferramenta são exercidas **sem** a biblioteca
MCP — é o que prova que a camada é fina e que a dependência é trocável.

**Plataforma**: o mesmo endpoint Phoenix. Transporte HTTP, sob `/mcp`.

**Projeto**: monólito modular multitenant (princípio V). Módulo novo: `TheBand.MCP`.

**Escala**: quatro ferramentas. As outras 73 perguntas de competência ficam fora, e o motivo
está declarado — não têm tela, e portanto não têm caminho provado (FR-021).

**Desempenho**: o mesmo teto de consultas da 061. Uma chamada de ferramenta MUST custar o
mesmo que a rota HTTP equivalente — e há teste comparando os dois, porque duas portas para o
mesmo dado com custos diferentes significam que uma delas tem consulta a mais.

## Constitution Check

*GATE: passa antes da Fase 0, reconferido depois da Fase 1.*

| Princípio | Como esta fatia o cumpre |
|---|---|
| **I** — domínio pelas ontologias | nenhuma ferramenta inventa pergunta: as quatro derivam de perguntas de competência declaradas (FR-020) |
| **II** — fonte externa não é domínio | o MCP é **porta**, não fonte. Nada entra por ele |
| **III** — proveniência (não negociável) | é o coração da feature: FR-010 e FR-014 põem origem, composição, janela e data de coleta **dentro** do objeto |
| **IV** — semântica em YAML versionado | `limitations` e `misinterpretations` são lidas da base em tempo de resposta, nunca escritas no código |
| **V** — monólito modular multitenant | módulo novo `TheBand.MCP`, tenant sempre do token (FR-002) |
| **VI** — Spec Kit antes do código | esta é a fase do plano; nenhum código antes de `tasks.md` |
| **VII** — gates e revisão independente | `mix gates` no fim; revisão independente **a declarar**, nunca a marcar |
| **VIII** — desenho que o problema justifica | ver *Decisões de desenho* abaixo, com as três respostas |
| **IX** — ontologias autônomas | nenhuma ontologia muda |
| **X** — responsabilidade única | uma ferramenta, uma pergunta. Uma ferramenta com argumento `pergunta` seria consulta arbitrária (FR-023) |
| **XI** — estado conferido, sinal nunca silenciado | o gate no fim termina em `exit $ec`; o veredito é lido, não presumido |

**Nenhuma violação a justificar.** A tabela *Complexity Tracking* fica vazia de propósito.

### Decisões de desenho — as três respostas do princípio VIII

**1. O registro de ferramentas (lista fechada, casada uma a uma)**

- *Que problema resolve*: o protocolo MCP tem `tools/list` — o servidor precisa **enumerar**
  o que oferece. E a FR-023 proíbe consulta arbitrária: sem lista fechada, o jeito natural
  seria uma ferramenta genérica com filtro livre;
- *O problema existe agora?* **Sim, duas vezes**: o protocolo exige a enumeração, e a 061 já
  sofreu a versão HTTP disto — o teste que percorre a tabela de rotas existe porque a lista
  escrita à mão envelheceu e uma rota entrou sem recusa de escrita;
- *O que fica pior*: acrescentar ferramenta passa a exigir tocar o registro. Não dá para
  ligar uma por configuração — e isso é intencional.

**2. O envelope de proveniência em toda resposta de medida**

- *Que problema resolve*: o consumidor é um modelo, e ele relata o campo que recebe. Sem a
  ressalva no mesmo objeto, ela não é lida;
- *O problema existe agora?* **Sim, e foi medido**: 23 esperas revisadas com mediana de
  `0,2 h` contra 79 aguardando há `46 dias`, na mesma equipe. Um número só diria
  *"12 minutos"*. Não é previsão;
- *O que fica pior*: toda resposta cresce, e montar o envelope custa uma leitura da base de
  conhecimento por medida. O custo é real e está aceito — a alternativa é a resposta mentir
  de graça.

**3. A camada fina sobre `ex_mcp`**

- *Que problema resolve*: a biblioteca é jovem (13 mil downloads, `1.5.0` publicada no dia da
  escolha). Se precisar ser trocada, o que se troca tem de ser o adaptador;
- *O problema existe agora?* **É previsão**, e está dito como previsão. O que existe agora é
  o dado que a sustenta: a alternativa mais usada não publica há treze meses, num protocolo
  que revisou neste ano;
- *O que fica pior*: uma camada a mais entre o protocolo e as funções. Em troca, as funções
  de ferramenta são testáveis sem subir servidor nenhum — o que se ganha é maior que o que
  se paga, e o teste que exercita as funções **sem** a biblioteca é a prova de que a camada
  não virou enfeite.

**Padrão que NÃO será introduzido**: um `@behaviour` de ferramenta. As quatro têm a mesma
forma, e um comportamento existiria para o quinto caso que ainda não se conhece. Duplicar
duas vezes é barato; abstrair cedo e errado é caro.

## Project Structure

### Documentação (esta feature)

```text
specs/062-servidor-mcp/
├── spec.md              # a especificação, com as dependências reconferidas em 2026-09-21
├── plan.md              # este arquivo
├── research.md          # as seis decisões medidas, e as três incógnitas que ficam
├── data-model.md        # o envelope, e os três estados da ausência
├── contracts/           # uma página por ferramenta, com a forma da resposta
└── tasks.md             # saída do /speckit-tasks — NÃO criado aqui
```

### Código (raiz do repositório)

```text
lib/the_band/mcp/
├── ferramentas.ex          # o registro: a lista fechada, casada uma a uma
├── envelope.ex             # valor + composição + janela + origem + ressalvas + coleta
├── ausencia.ex             # os três estados: conferido-e-nada, não-conferido, recusado
└── ferramentas/
    ├── team_roster.ex
    ├── team_open_work.ex
    ├── team_review_wait.ex
    └── team_stale_work.ex

lib/the_band_web/
├── router.ex               # o escopo /mcp, atrás do MESMO plug de autenticação da 061
└── plugs/api_auth.ex       # reusado sem alteração

test/the_band/mcp/
├── envelope_test.exs               # SC-001: toda medida carrega proveniência
├── ausencia_test.exs               # SC-002: nenhum zero onde o estado é outro
├── ferramentas_test.exs            # as quatro, exercidas SEM a biblioteca MCP
├── fronteira_test.exs              # nenhum módulo de MCP toca Repo ou Ecto.Query
└── paridade_test.exs               # SC-004: tela ↔ API ↔ MCP recusam igual

test/the_band_web/mcp/
├── protocolo_test.exs              # tools/list enumera exatamente as quatro
├── segredo_nao_vaza_test.exs       # SC-005: varre o objeto INTEIRO
└── custo_test.exs                  # a ferramenta custa o mesmo que a rota HTTP
```

**Structure Decision**: `TheBand.MCP` é um contexto novo ao lado dos existentes, e
`TheBandWeb` ganha apenas o escopo de rota. A separação entre `lib/the_band/mcp/` (as
respostas) e `lib/the_band_web/` (o transporte) é o que torna a troca de biblioteca um
trabalho de adaptador.

## Complexity Tracking

> Preenchido apenas se o *Constitution Check* tiver violação a justificar.

**Vazio.** Nenhuma violação: uma dependência nova, nenhuma tabela, nenhuma migração, nenhum
padrão sem problema medido.

## Constitution Check — reavaliação pós-Fase 1

Reconferido depois de escrever `data-model.md`, `contracts/` e `quickstart.md`.

**Continua sem violação.** O que a Fase 1 mudou em relação à avaliação inicial:

1. **o envelope ganhou um campo `nil` deliberado**, e isso é o princípio VIII em ação:
   `rule` é `nil` para medida porque o schema de `measurement` **não tem** `version`.
   Preencher seria afirmar versionamento que a base não declara. Lido em
   `priv/knowledge_base/schemas/measurement.schema.yaml`, 2026-09-21;
2. **`window: nil` é dito, e não omitido** — princípio VIII, *ausência como nula, nunca
   como zero*, aplicado ao campo que não existe em vez de ao valor que falta;
3. **nenhum `@behaviour` foi introduzido.** As quatro ferramentas têm a mesma forma, e o
   comportamento existiria para o quinto caso que ainda não se conhece.

### Os ids da base que este plano cita, conferidos na origem

| Id | Existe? | Versão |
|---|---|---|
| `profile.thresholds` | sim, `priv/knowledge_base/rules/profile_thresholds.yaml` | 1 |
| `team.dashboard.thresholds` | sim | 1 |
| `api.access.thresholds` | sim — mas os **valores** seguem a decidir com o Product Owner |

### O que falta, e fica declarado

| # | O que | Por quê |
|---|---|---|
| **I1** | os valores de `api.access.thresholds` | decisão do Product Owner, herdada em aberto da 061 |
| **I2** | o que o registro de uso por MCP conta para que abuso seja detectável | item 4 da avaliação de segurança que a spec pede, e ela não foi feita |
| **I3** | injeção de instrução pelo conteúdo — título de issue e nome de equipe chegam ao modelo pela resposta | item 2 da mesma avaliação. **Não é resolvível no plano**: precisa do papel Security |

**I2 e I3 são risco de desenho, não de implementação.** Escrever `tasks.md` sem elas
produziria tarefas que parecem cobrir a superfície inteira, e não cobrem. A recomendação é
chamar o papel Security **antes** do `/speckit-tasks`, ou decompor declarando que as duas
ficam fora desta fatia.

## Artefatos gerados

| Arquivo | O que carrega |
|---|---|
| [`research.md`](./research.md) | seis decisões medidas — biblioteca, fronteira, base de conhecimento, autenticação, as quatro ferramentas, e os números da 061 |
| [`data-model.md`](./data-model.md) | o envelope, os três estados da ausência, e o que nunca sai |
| [`contracts/ferramentas.md`](./contracts/ferramentas.md) | uma seção por ferramenta, com a forma da resposta e o que ela **não** responde |
| [`quickstart.md`](./quickstart.md) | dez passos de verificação, cada um dizendo o que tem de mostrar e qual guarda o impede de passar vazio |
