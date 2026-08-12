# Plano de implementação: o vínculo que sumiu na origem

**Feature**: `specs/012-vinculo-que-sumiu-na-origem/` · **Branch**: `016-vinculo-que-sumiu-na-origem`
**Spec**: [spec.md](spec.md) · **Pesquisa**: [research.md](research.md)
**Constituição**: v1.4.0, dez princípios · **Origem**: issue [#263](https://github.com/The-Band-Solution/theband/issues/263)

---

## Summary

A coleta passa a **marcar como ausente** o vínculo de decomposição que a origem não declara mais —
uma vez por repositório coletado, no escopo do **repositório do pai**, com o início da execução como
corte.

Medido em 2026-08-12: **1 666** vínculos, **0** marcados, **52** que a última coleta não reviu. A
tela que exibe o vínculo ausente já existe (feature 011); o que falta é o dado chegar nesse estado.

## O que este plano decide antes de tudo

**Não é uma função nova de desenho novo. É a quarta ocorrência de um desenho que já existe três
vezes** — issue, designado, rótulo. O que o plano decide é onde ela difere:

| Decisão | Escolha | O que a alternativa quebraria |
|---|---|---|
| escopo da marca | repositório do **pai** | por tenant, a L19 no nível do vínculo; pela filha, os **57** vínculos entre repositórios |
| corte | `sync.started_at` | por "agora", marcaria o vínculo que a própria execução gravou |
| data gravada | instante em que se notou | gravar o `started_at` daria dois sentidos à mesma coluna em tabelas vizinhas |
| onde entra | ramo `{:ok, …}`, depois de `vincular/2` | antes dele, marcaria tudo e a renovação limparia parte |
| como o número aparece | log e retorno da fase | campo novo no cartão da sincronização é número ao lado de números que respondem outra pergunta |
| o que fica fora | recusas, ciclos, #261, #262 | refatoração oportunista no mesmo diff |

## Technical Context

| | |
|---|---|
| Linguagem | Elixir 1.20.2 / OTP 29 |
| Framework | Phoenix 1.8.9 + LiveView |
| Persistência | Ecto + PostgreSQL 17 — **nenhuma coluna nova, nenhuma migração** |
| Escala | 1 666 vínculos, 4 529 issues, 135 repositórios observados; um `UPDATE` por repositório |
| Fronteiras cruzadas | **WorkItems** (vínculo, issue) e **Ingestion** (a fase da coleta) |
| Arquivos | `work_items/commands.ex`, `work_items.ex`, `ingestion/github_work_items.ex` |
| Tela | nenhuma alterada — a da feature 011 já exibe, e passa a **receber** dado nesse estado |

**Nada aqui é NEEDS CLARIFICATION.** As seis decisões saíram de ler o código e medir o banco, e
estão em [research.md](research.md).

---

## Constitution Check

### I. Domínio organizado pelas ontologias — **conforme**

Nenhum conceito novo. `decomposition_links` já materializa a decomposição de SRO, e a marca de
ausência é atributo de proveniência do vínculo, não conceito.

### II. Fonte externa não é domínio — **conforme**

A origem devolve `subIssues`; o domínio guarda o vínculo. A ausência é **derivada da coleta** — "não
veio nesta execução" —, e não de campo algum do GitHub. O GitHub não diz "removi esta parte": ele
simplesmente para de listá-la, e é a plataforma que precisa notar.

### III. Proveniência e idempotência (NÃO NEGOCIÁVEL) — **é o princípio que a feature restaura**

- **Ausência é marcada, nunca apagada**: a linha permanece, com quando foi observada pela primeira
  vez, quando foi vista pela última, e agora quando deixou de ser vista;
- **idempotente**: duas coletas sem mudança na origem não alteram data nenhuma — `is_nil(...)` no
  `WHERE` impede reescrever a marca de quem já está marcado;
- **reobservar cura**: `record_decomposition_link/2` já zera a marca, e a data de primeira observação
  é preservada por `base.observed_at || now`.

**Hoje o princípio está violado no dado**: 1 666 vínculos e 0 marcas, com 52 afirmações que a origem
não sustenta.

### IV. Semântica declarada em YAML versionado — **não se aplica**

Nenhuma regra de mapeamento nova. A decisão "não veio nesta execução" é da coleta, não da semântica —
e não há axioma a consultar.

### V. Monólito modular multitenant — **conforme**

A função nova recebe `%Tenant{}` e escopa o `UPDATE` por `tenant_id` **e** por repositório. Sem
aridade sem repositório: a assinatura impede a L19, como a irmã de issue já faz.

### VI. Spec Kit e sprint backlog antes do código — **conforme**

Spec e checklist commitados antes deste plano. **Nada implementado.** `/speckit-tasks` e
`/speckit-analyze` vêm antes da primeira linha, e o sprint 011 abre com `sprint-backlog`.

### VII. Quality gates e revisão independente — **conforme, com uma lacuna declarada**

Os dez gates verdes por código de saída antes do PR, e o PR nasce com revisão pedida à equipe
`the-band`. **A revisão independente depende de pessoa**, e enquanto ela não vier a lacuna fica
declarada — nunca marcada como cumprida.

**Sem mock de módulo de domínio**: os testes montam o estado pelo caminho real — gravar issues,
gravar vínculos, coletar de novo sem a parte. A borda HTTP do GitHub é a única que se finge.

### VIII. Desenho que o problema justifica — **conforme**, e o registro das três respostas está abaixo

### IX. Ontologias modulares e autônomas — **conforme**

Nenhuma fronteira de ontologia é cruzada: `decomposition_links` e `collected_issues` são do mesmo
módulo, e a subconsulta que acha os pais do repositório fica **dentro** de WorkItems. O
`observed_repository_id` já viaja em `collected_issues`; nenhuma tabela de CMPO é lida daqui.

### X. Responsabilidade única, em módulo e em tela — **conforme**

A função faz uma coisa: marcar os vínculos de um repositório que esta execução não reviu. Nenhuma
tela ganha responsabilidade nova — e a decisão D5 existe justamente para não dar ao cartão da
sincronização uma segunda pergunta para responder.

---

## Registro das decisões de desenho (princípio VIII)

**Um padrão novo, e ele é a repetição de um que já tem três ocorrências.**

### P1 — `mark_decomposition_links_no_longer_observed/3`

| Pergunta | Resposta |
|---|---|
| **Que problema concreto resolve** | 1 666 vínculos, 0 marcados, e **52** que a origem não declara mais sendo apresentados como atuais |
| **Existe agora ou é previsão** | **existe agora**, medido no banco em 2026-08-12 |
| **O que fica pior** | mais uma escrita por repositório na coleta (135 `UPDATE`s por execução); e uma quarta função de marcação, o que torna "marcar ausência" um conceito repetido em quatro lugares |

**A quarta ocorrência é o limiar da extração, e ela não é feita aqui.** As três irmãs já existem;
esta é a quarta. Abstrair as quatro numa função genérica exigiria parametrizar tabela, coluna de
escopo e coluna de corte — e as três irmãs **não** têm o mesmo formato de corte: issue corta por
data, designado e rótulo cortam por lista. A generalização juntaria duas coisas diferentes.
**Declarado como dívida vizinha**, não como trabalho desta feature.

### P2 — A subconsulta dos pais do repositório

| Pergunta | Resposta |
|---|---|
| **Que problema concreto resolve** | `decomposition_links` não tem `observed_repository_id`; o repositório está na issue-pai |
| **Existe agora ou é previsão** | existe agora: sem ela, não há como escopar |
| **O que fica pior** | a consulta passa a depender do formato de `collected_issues`. Fica **dentro** do módulo WorkItems, onde as duas tabelas já convivem — nenhuma fronteira nova |

**Alternativa descartada**: denormalizar `observed_repository_id` no vínculo. Seria coluna nova,
migração, e um segundo lugar onde o repositório do pai pode ficar errado.

### P3 — Nada de campo novo em `syncs`

**Não é padrão introduzido; é padrão recusado**, e está registrado porque a spec pedia. O FR-013 foi
reescrito na fase de plano: o número vai para o log e para o retorno da fase, e a tela de
sincronizações não ganha contagem. Razão em [D5](research.md#d5--como-o-número-aparece-e-por-que-não-vira-campo-na-tela-de-sincronizações).

---

## Project Structure

### Documentação (esta feature)

```text
specs/012-vinculo-que-sumiu-na-origem/
├── spec.md
├── plan.md              # este arquivo
├── research.md          # as sete decisões, com a evidência de cada uma
├── data-model.md
├── quickstart.md
├── contracts/
│   └── work_items.md    # o contrato da função, antes da implementação
└── checklists/
    └── requirements.md
```

### Código (raiz do repositório)

```text
lib/the_band/
├── work_items.ex                      # fronteira pública: mais um defdelegate
├── work_items/
│   └── commands.ex                    # a função nova, ao lado da irmã de issue
└── ingestion/
    └── github_work_items.ex           # a chamada, no ramo {:ok, …} de coletar_issues/2

test/the_band/
├── work_items_test.exs                # marcar, não marcar, ressuscitar, idempotência, tenant
└── ingestion/
    └── github_work_items_test.exs     # a coleta que deixa de ver a parte; a que falha e não marca
```

**Structure Decision**: monólito modular, sem arquivo novo. A função nasce ao lado da irmã que já
existe em `work_items/commands.ex`, e a fronteira pública ganha um `defdelegate` — é como as outras
três marcações são expostas.

---

## Phase 0 — Pesquisa

Concluída: [research.md](research.md), sete decisões (D1 a D7), todas com evidência medida ou lida no
código. Nenhum NEEDS CLARIFICATION restante.

**A pesquisa mudou a spec uma vez**, e está registrado: o FR-002 pedia gravar o `started_at` na
marca; as três implementações irmãs mostram que a convenção é o instante em que se notou. Corrigido
antes de existir código.

## Phase 1 — Desenho e contratos

| Artefato | O que traz |
|---|---|
| [contracts/work_items.md](contracts/work_items.md) | assinatura, sucesso, erro, e **o que a API não expõe** |
| [data-model.md](data-model.md) | os três estados do vínculo e as transições entre eles |
| [quickstart.md](quickstart.md) | como provar no dado real, e as consultas de conferência |

## Phase 2 — Tarefas

`/speckit-tasks` gera `tasks.md`. Ordem prevista: contrato → teste que falha → função → chamada na
coleta → teste de integração da coleta → conferência no dado real.

---

## Complexity Tracking

| Violação | Por que é necessária | Alternativa mais simples recusada porque |
|---|---|---|
| quarta função de marcação de ausência | o problema existe agora, medido em 52 vínculos | a generalização das quatro exigiria parametrizar corte, e os cortes **não** são iguais: um é por data, dois são por lista |

**Nenhuma outra.** Sem migração, sem coluna, sem tabela, sem módulo, sem `behaviour`, sem tela nova.
