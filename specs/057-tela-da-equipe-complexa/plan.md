# Implementation Plan: A tela da equipe, e a equipe feita de equipes

**Branch**: `057-tela-da-equipe-complexa` | **Date**: 2026-09-02 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/057-tela-da-equipe-complexa/spec.md`

## Summary

A tela da equipe passa a responder quatro perguntas de gestão, e a equipe composta
por equipes mostra suas subequipes **uma a uma, nunca somadas**.

Antes de qualquer indicador novo, a feature corrige o defeito de origem: o
conjunto de membros usado nas medidas vem hoje da evidência que a origem lista, e
não do vínculo declarado. A correção é uma troca de fonte — `EO.team_members_at/3`
no lugar de `list_team_members/3` — mais a passagem da **data** para onde antes só
havia "hoje".

Nenhuma migração. Nenhuma tabela nova. O que muda é de onde o conjunto de membros
vem, e três funções de leitura acrescentadas.

**A abordagem em uma frase**: consultas novas em `EO` e `WorkItems` que já nascem
recortadas pelo período do vínculo, um módulo puro de simulação, e uma LiveView
que escolhe o que mostrar conforme a equipe tenha ou não subequipes.

## Technical Context

**Language/Version**: Elixir 1.17

**Primary Dependencies**: Phoenix 1.8 (LiveView), Ecto, Oban — nenhuma nova

**Storage**: PostgreSQL, tabelas compartilhadas com `tenant_id`. **Sem migração**

**Testing**: ExUnit; `Phoenix.LiveViewTest` para as telas; dois tenants povoados
nos testes de isolamento

**Target Platform**: monólito Phoenix, servido em produção via Dokploy

**Project Type**: aplicação web monolítica modular multitenant

**Performance Goals**: a tela da subequipe em **no máximo 9 consultas** por render;
a tela da equipe composta em **no máximo 4 + 3 por subequipe**. A simulação é
aritmética sobre lista de 8 números × 10 000 rodadas — abaixo de 50 ms

**Constraints**: `mix gates` verde; nenhuma consulta sem tenant; determinismo
estrito na previsão (igualdade, não tolerância)

**Scale/Scope**: 2 telas (uma rota), 3 módulos de domínio tocados, 1 módulo novo,
~9 funções públicas, 12 cenários de verificação

## Constitution Check

*GATE: aprovado antes do Phase 0, reavaliado após o Phase 1.*

| Princípio | Situação | Como |
|---|---|---|
| **I** Domínio pelas ontologias | ✅ | vínculo lido de `eo.team_membership`, o relator; nenhum módulo nomeado por ferramenta |
| **II** Fonte externa não é domínio | ✅ | nenhum conector tocado; a feature só lê o que já foi promovido |
| **III** Proveniência e idempotência | ✅ | nada é gravado; as leituras respeitam `collected_at` e o período coletado |
| **IV** Semântica em YAML | ⚠️ | ver abaixo |
| **V** Monólito modular multitenant | ✅ | `%Tenant{}` explícito em toda função; `TeamSkills` deixa de alcançar a evidência e passa a chamar a API pública de `EO` — **melhora** a aderência |
| **VI** Spec Kit antes do código | ✅ | contrato escrito antes da primeira função; fatia vertical — tela e backend na mesma entrega |
| **VII** Gates e revisão independente | ✅ | `mix gates`; PR com revisão de terceiro |
| **VIII** Desenho que o problema justifica | ✅ | três decisões registradas abaixo, com custo nomeado |
| **IX** Ontologias autônomas | ✅ | nenhuma ontologia alterada |
| **X** Responsabilidade única | ⚠️ | ver abaixo |
| **XI** Estado conferido, sinal nunca silenciado | ✅ | `{:sem_historico, _}` e `{:abaixo_do_piso, _}` são retornos; nada cai em fallback silencioso |

### ⚠️ IV — a medida precisa de necessidade de informação declarada

O princípio exige que **toda medida responda a uma necessidade de informação
declarada em YAML**, com limitações e interpretações incorretas.

A feature apresenta medidas novas — o burn com linha de base e a previsão. **Elas
precisam ser declaradas** em `priv/knowledge_base/` antes de aparecerem na tela,
com as limitações que já estão escritas na spec:

- o burn não responde se um sprint termina — não há escopo comprometido;
- "fechado" é o ato da ferramenta: abandonado e concluído entram iguais;
- a previsão assume que o período à frente se parece com o observado;
- o tempo em tarefa conta da abertura, não da atribuição.

**Não é ressalva, é tarefa.** Entra no `tasks.md` antes das tarefas de tela.

### ⚠️ X — `show.ex` já é grande, e vai crescer

A tela responde **uma** pergunta — "como está esta equipe" —, então a rota única
está certa (R10). Mas o arquivo já tem cinco seções e ganha mais.

**Mitigação, e o que ela não resolve**: os blocos viram componentes de função e
**toda** lógica de medida fica fora da LiveView. Isso mantém uma razão para mudar
por unidade de medida, mas não impede o arquivo de crescer. Se passar de ~1200
linhas, as seções viram componentes em arquivo próprio — decisão a tomar com o
número na mão, não agora.

## Decisões de desenho — as três respostas do princípio VIII

### D1 — `TheBand.Forecast`, módulo novo

**Que problema concreto resolve**: `WorkItems.projecao/1` devolve um ponto e
**recusa** quando o fechamento não supera a abertura — medido em 2026-08-27, 59
das 63 pessoas com trabalho aberto caem nessa recusa. Para uma equipe, a pergunta
"qual a chance de terminar" tem resposta mesmo aí: é uma proporção de rodadas
(FR-035). Ponto não expressa isso; distribuição expressa.

**O problema existe agora?** **Sim.** A série da equipe do protótipo abre 9,5 por
semana e fecha 7,1 — `projecao/1` devolveria `{:nao_converge, _, _}` e a tela
ficaria sem resposta, quando a resposta útil é "2 rodadas em 10 000 terminaram".

**O que piora**: mais um módulo, e mais um lugar onde alguém pode responder à
mesma pergunta. Mitigado por fronteira explícita — `Forecast` é **puro**, não toca
no banco, e `projecao/1` continua sendo a resposta da página da pessoa. Se um dia
convergirem, o merge é barato porque ambos são funções puras sobre a mesma série.

### D2 — `burn/2` com linha de base, em vez de um burn de equipe

**Que problema concreto resolve**: sem a linha de base, a distância entre as
curvas mede só os itens nascidos dentro da janela (R2). Uma equipe com 40 itens
abertos há meses apareceria com distância zero.

**O problema existe agora?** **Sim**, e atinge a página da pessoa hoje. Não é
previsão.

**O que piora**: `burn/2` ganha um parâmetro que a página da pessoa sempre passa
como zero, e a assinatura sugere que a pessoa também tem linha de base — quando na
verdade ela tem a mesma limitação, não corrigida aqui. Mitigado no `@doc` e por
item de backlog explícito.

**A alternativa descartada** — um `team_burn/2` separado — criaria duas definições
de burn que divergiriam na primeira correção. Duplicar duas vezes é barato;
duplicar a definição de uma medida não é.

### D3 — A vigência entra na consulta como junção, não como lista de ids

**Que problema concreto resolve**: `person_id in ^ids` usa **um** conjunto de
membros para todas as semanas da série — que é exatamente o defeito de origem.

**O problema existe agora?** **Sim.** É o defeito descrito em R9, e SC-002 existe
para provar que ele acabou.

**O que piora**: a consulta ganha uma junção e fica mais difícil de ler, e a
condição de vigência aparece em mais de um lugar. Mitigado extraindo o fragmento
de vigência para uma função privada de query reusada pelas duas séries — e é o
mesmo `[started_at, ended_at)` de `count_team_members_at/3`, com o teste de borda
apontando para ela.

### O que **não** foi introduzido, e por quê

| Não feito | Por quê |
|---|---|
| camada de repositório sobre `Repo` | não há segunda fonte; seria abstração sobre a única implementação |
| behaviour para "provedor de previsão" | há uma implementação; a terceira ocorrência dirá o que varia |
| cache da simulação | 50 ms não é problema; cache traz invalidação, que é |
| GenServer para as séries | não há estado a guardar entre requisições |

## Project Structure

### Documentation (this feature)

```text
specs/057-tela-da-equipe-complexa/
├── plan.md                       # este arquivo
├── spec.md
├── research.md                   # R1–R10; R1 e R2 mudaram a spec
├── data-model.md                 # estruturas calculadas — nenhuma migração
├── quickstart.md                 # 12 cenários de verificação
├── contracts/
│   └── medidas-de-equipe.md      # escrito antes da primeira função pública
├── prototipo/
│   ├── team-of-teams.html        # o protótipo aprovado em 2026-09-02
│   └── README.md                 # como lê-lo contra a spec, e onde ele diverge
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

```text
lib/the_band/
├── ontology/seon/
│   ├── eo.ex                          # + team_members_at/3, team_member_ids_at/3
│   └── eo/queries.ex                  # as duas consultas, com a vigência em [início, fim)
├── work_items.ex                      # + as três delegações de equipe
├── work_items/
│   ├── queries.ex                     # team_state_changes_by_period/4, team_open_at/3,
│   │                                  #   team_open_tasks_by_person/3 — DISTINCT na issue
│   └── person_work.ex                 # burn/1 delega para burn/2 com linha de base
├── forecast.ex                        # NOVO — monte_carlo/2, puro e determinístico
└── profiles/team_skills.ex            # membros/3 recebe a data; evolution/2 recorta por mês

lib/the_band_web/live/teams_live/
└── show.ex                            # composição sem soma, seções, gráficos, pessoas

priv/knowledge_base/
└── measures/                          # as medidas novas, com limitações declaradas (princípio IV)

test/the_band/
├── ontology/seon/eo/queries_test.exs  # vigência na data, e a borda do dia da troca
├── work_items/team_series_test.exs    # DISTINCT, vigência por data do evento, linha de base
├── forecast_test.exs                  # determinismo por igualdade, piso, não conclusão
└── profiles/team_skills_test.exs      # o passado não se reescreve — SC-002

test/the_band_web/live/teams_live/
└── show_test.exs                      # ausência de total, ausência nomeada, ver ≠ administrar
```

**Structure Decision**: monólito modular existente, sem diretório novo. A medida
mora no domínio; a LiveView só apresenta. `TheBand.Forecast` fica na raiz de
`lib/the_band/` e não dentro de `work_items/` porque não é sobre itens de
trabalho — recebe uma série de números e devolve uma distribuição, e nada nele
conhece issue.

## Ordem de implementação

A ordem não é sugestão: cada fase é verificável sozinha, e a primeira é a que
sustenta todas as outras.

| Fase | O que entra | Prova |
|---|---|---|
| **1** | `EO.team_members_at/3` + correção de `TeamSkills` | Cenários 1 e 2 — o passado não se reescreve |
| **2** | medidas declaradas em YAML (princípio IV) | `mix knowledge.validate` |
| **3** | séries de equipe com vigência por data do evento | Cenários 4 e 12 |
| **4** | tela da equipe composta, sem soma | Cenário 3 |
| **5** | `burn/2` com linha de base + a faixa na tela | Cenário 5 |
| **6** | tarefas por pessoa e habilidades | Cenários 9, 10, 11 |
| **7** | `Forecast.monte_carlo/2` e a apresentação | Cenários 6, 7, 8 |

**A fase 1 vai sozinha num PR.** Ela muda números já exibidos, e misturá-la com
tela nova tornaria impossível saber se uma diferença veio da correção ou da
feature.

## Riscos

| Risco | Efeito | Mitigação |
|---|---|---|
| a correção da fase 1 muda números que alguém já anotou | desconfiança na plataforma | o PR declara o que muda e por quê, com antes e depois medidos em dado real |
| teto de consultas da tela estourar | tela lenta e gate de consulta vermelho | teto declarado em Technical Context, com teste que conta consultas |
| a previsão ser lida como promessa | compromisso assumido sobre ruído | FR-033 e o texto na tela; o piso de R7 evita o pior caso |
| `show.ex` crescer demais | duas razões para mudar no mesmo arquivo | limite declarado (~1200 linhas) e critério de divisão já escrito |

## Dívida assumida, e registrada

**A página da pessoa tem a mesma limitação de linha de base** que a fase 5 corrige
para a equipe (R2). **Não é corrigida aqui**: mudar a página da pessoa exige
critério de revisão próprio e tem teto de consultas próprio, medido em
`person_detail_test.exs`.

Vai para `docs/backlog/` ao final da feature — declarada, não escondida.

## Complexity Tracking

> Preenchido apenas se o Constitution Check tiver violações a justificar.

Nenhuma violação. Os dois ⚠️ acima são **tarefas** (declarar as medidas em YAML) e
**limite declarado** (tamanho de `show.ex`), não desvios de princípio.
