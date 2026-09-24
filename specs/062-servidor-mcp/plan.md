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
nada** — nem token, nem escopo, nem resposta (FR-003, FR-005, FR-006). O registro de leitura
usa a tabela `api_access_reads`, que a 061 já tem (FR-024).

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
├── router.ex               # o escopo /mcp, com a MESMA pipeline de /api/v1 (:api_autenticada)
└── plugs/
    ├── api_auth.ex         # reusado sem alteração
    ├── api_rate_limit.ex   # reusado sem alteração — o limite é um só por token (FR-026)
    └── api_read_log.ex     # ALTERADO: aceita ferramenta, alvo e marca de concessão
                            #   vindos de conn.private (FR-024, FR-025, T021, T022)

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

### A avaliação de segurança foi feita, e corrigiu este plano em dois pontos

> **A1 e A2 foram resolvidos na 061 em 2026-09-23** (#936, #938). O que segue é o registro de
> 2026-09-22. O estado atual está em *Reconciliação com o código*, abaixo.

Está em [`seguranca.md`](./seguranca.md), escrita em 2026-09-22. **Ela não é revisão
independente** — quem a escreveu escreveu o desenho —, e o documento diz isso no topo. Quatro
tentativas de obter a avaliação por agente independente falharam.

**Dois achados contradizem o que este plano dizia, e o plano cede:**

| # | Achado | Severidade | O que o plano dizia |
|---|---|---|---|
| **A1** | **leitura bem-sucedida não é registrada em lugar nenhum** — nem por `AccessEvents`, nem pelo plug, nem pelo token (`last_used_at` é sobrescrito). A FR-024 aponta o registro de acesso como o caminho para perceber agregação, e ele não existe | **alta** | tratava I2 como *"falta decidir o que contar"*. Não é: **falta o mecanismo** |
| **A2** | **não há limite de taxa na 061** — medido em `plugs/` e `api_tokens.ex`. A Q4 decide *"o limite de taxa é o da 061"*, e herdar um limite inexistente é herdar zero | **alta** | herdava um controle que não existe |

Mais dois de severidade média, sem contradição: **A3** injeção de instrução pelo conteúdo — a
mitigação é marcar a fronteira **no schema**, nunca filtrar frase nem pedir ao modelo que
ignore; e **A4** agregação ao longo do tempo, cuja única mitigação é o A1.

### O que falta, e fica declarado

| # | O que | Estado |
|---|---|---|
| **I1** | os valores de `api.access.thresholds` | **aplicados** desde o #936: 120 por minuto. Continuam como proposta, e a decisão final segue com o Product Owner |
| **I2** | o registro de uso | **respondida, e pior que se supunha**: virou o achado A1 |
| **I3** | injeção de instrução pelo conteúdo | **respondida**: achado A3, com mitigação que reduz e não elimina — e o limite está dito |
| **I4** | **revisão independente do desenho** | **aberta**. Quatro tentativas falharam; a lacuna do princípio VII não deve ser marcada como cumprida |

**O `tasks.md` tem de carregar A1 e A2 como tarefa, ou declarar por escrito que a fatia entra
sem eles** — e então a FR-024 fica apoiada em nada, dito em voz alta. Decompor sem escolher
uma das duas produziria tarefas que parecem cobrir a superfície inteira e não cobrem.

## Reconciliação com o código — 2026-09-24

O plano foi escrito em 2026-09-22. **No dia seguinte, o #936 e o #938 resolveram na 061 os
dois achados altos** que este plano cedia à avaliação de segurança. Implementado como estava,
o plano teria produzido um segundo registro e um segundo limite para o mesmo token.

**O que mudou no desenho:**

| Antes | Agora |
|---|---|
| criar o registro de leitura do MCP | **herdar** o da 061, e ensiná-lo a enxergar a ferramenta e o alvo (T021) |
| criar o limite, ou declarar que não há | **provar** que `/mcp` gasta o mesmo limite de `/api/v1` (T024) |
| `/mcp` atrás do `ApiAuth` | `/mcp` atrás da pipeline `:api_autenticada` inteira |
| `api_read_log.ex` fora do escopo | **dentro**: é código da 061 em produção, e muda pouco |

**Dois achados novos**, que a reconciliação encontrou lendo o código que o desenho reusa, e
que a autoavaliação de 2026-09-22 não podia ver, porque o código não existia:

- **A6**: o registro grava o molde da rota e `params["id"]`. No MCP, toda chamada é
  `POST /mcp` e os argumentos vão no corpo, então toda linha diria só `/mcp`;
- **A7**: o registro grava todo `2xx`, e a recusa do MCP sai em `200` (FR-013). A recusa seria
  gravada como leitura concedida.

Os dois estão em `seguranca.md` e viraram as tarefas T021 e T022.

**O `Constitution Check` continua sem violação.** O princípio VIII sai mais forte: reusar o
registro e o limite é menos estrutura do que o plano previa. E o princípio VII ganhou uma
tarefa, a T009, que bloqueia o T001.

## Artefatos gerados

| Arquivo | O que carrega |
|---|---|
| [`research.md`](./research.md) | seis decisões medidas — biblioteca, fronteira, base de conhecimento, autenticação, as quatro ferramentas, e os números da 061 |
| [`data-model.md`](./data-model.md) | o envelope, os três estados da ausência, e o que nunca sai |
| [`contracts/ferramentas.md`](./contracts/ferramentas.md) | uma seção por ferramenta, com a forma da resposta e o que ela **não** responde |
| [`quickstart.md`](./quickstart.md) | dez passos de verificação, cada um dizendo o que tem de mostrar e qual guarda o impede de passar vazio |
| [`seguranca.md`](./seguranca.md) | cinco achados, dois deles contradizendo este plano — e o aviso, no topo, de que é autoavaliação e não revisão |
