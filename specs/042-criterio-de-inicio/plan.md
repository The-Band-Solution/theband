# Implementation Plan: O critério de início, declarado pela organização

**Branch**: `042-criterio-de-inicio` | **Date**: 2026-08-24 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/042-criterio-de-inicio/spec.md`
**Fecha**: [#370](https://github.com/The-Band-Solution/theband/issues/370)

## Summary

A organização declara qual tipo de evento observado marca o início de um trabalho. A declaração vale por **projeto** ou por **quadro**, com o quadro vencendo o projeto, e o desempate entre quadros sendo `spo_project_boards.linked_at` mais recente.

O conceito entra na rede como `spo.activity_start_criterion`, especialização de `ufo.social_object` — porque qual evento marca o início é **convenção social**, não fato observado, e a UFO define social object exatamente assim.

Nada disso grava `start_date`. A resolução acontece **na leitura**, e é a decisão de desenho que o resto do plano gira em torno.

## Technical Context

**Language/Version**: Elixir 1.20 · OTP 28
**Primary Dependencies**: Phoenix 1.8, LiveView, Ecto, PostgreSQL
**Storage**: PostgreSQL — tabela nova `spo_activity_start_criteria`
**Testing**: ExUnit, `Phoenix.LiveViewTest`
**Target Platform**: monólito modular multitenant
**Project Type**: web application (LiveView, sem frontend separado)
**Performance Goals**: a resolução do critério não pode acrescentar consulta por atividade — ver Decisão 2
**Constraints**: a rede é fonte da verdade do modelo; nenhum conceito entra sem YAML validado
**Scale/Scope**: 4 projetos, 26 quadros, 19.200 atividades executadas, 3.215 issues em quadro, das quais **414 em mais de um**

Nenhum NEEDS CLARIFICATION. As três decisões que faltavam vieram da pessoa mantenedora em 2026-08-24, e estão registradas no `checklists/requirements.md` com a frase de origem.

## Constitution Check

| princípio | como esta feature o atende |
|---|---|
| **I. Domínio pelas ontologias** | o conceito entra em SPO, e a tabela leva o prefixo `spo_`. Não há módulo nomeado por ferramenta |
| **II. Fonte externa não é domínio** | o critério **nomeia** um tipo de evento da origem; não copia o modelo dela. O `activity_type` coletado permanece cru |
| **III. Proveniência (não negociável)** | toda declaração tem autor e data; desfazer marca e nunca apaga |
| **IV. Semântica em YAML versionado** | `spo.activity_start_criterion` e suas relações entram na base antes do código, e os gates reprovam se faltarem |
| **V. Monólito multitenant** | toda consulta filtra por `tenant_id`; o teste de isolamento é obrigatório |
| **VI. Spec Kit antes do código** | spec escrita e validada antes deste plano |
| **VII. Gates e revisão** | 13 gates, PR revisado por quem não implementou |
| **VIII. Desenho que o problema justifica** | ver **Registro das decisões de desenho**, abaixo |
| **IX. Ontologias modulares** | SPO não passa a depender de ontologia nova: `ufo` já é dependência declarada dela |
| **X. Responsabilidade única** | a declaração vive na tela do alvo (projeto ou quadro), e não numa tela de configuração própria |

### Sobre o princípio IX, com cuidado

`spo.activity_start_criterion` especializa `ufo.social_object` e se relaciona com `ufo.event`. **SPO já declara `ufo` como dependência** — conferir em `priv/knowledge_base/ontology/seon/spo/spo.yaml` antes de escrever o módulo. Se não declarar, o conceito **não entra em SPO**: acrescentar dependência para acomodar um conceito é a inversão que o princípio IX proíbe.

---

## Registro das decisões de desenho — princípio VIII

Quatro decisões introduzem estrutura. Cada uma traz as três respostas que a constituição exige.

### Decisão 1 — Tabela única com alvo polimórfico, e não duas tabelas

`spo_activity_start_criteria` com `project_id` **ou** `observed_project_id`, exatamente um preenchido, garantido por constraint.

**Que problema concreto resolve.** A escala de precedência precisa comparar declarações de níveis diferentes numa consulta só. Com duas tabelas, toda leitura vira `UNION` — e a regra de precedência ficaria escrita em dois lugares, que é o defeito que esta base já pagou três vezes (`classification/2`, prévia contra recálculo, coleta contra recálculo).

**Esse problema existe agora?** **Existe.** A `FR-006` já obriga a escala, e a `FR-007` já obriga o desempate. Não é previsão.

**O que fica pior.** A constraint `exactly-one-of` é mais frágil que uma chave estrangeira obrigatória: um `INSERT` fora do contexto pode preencher os dois e só o banco recusa. E a leitura da tabela exige saber qual coluna olhar, o que é pior que duas tabelas com nomes autoexplicativos.

**Alternativa descartada**: duas tabelas. Rejeitada pelo custo da regra duplicada, não por elegância.

### Decisão 2 — A resolução acontece na leitura, e nunca é gravada

`start_date` **não vira coluna**. Uma função de leitura recebe as atividades e devolve o instante de início, aplicando a escala.

**Que problema concreto resolve.** A `FR-005` exige que trocar a declaração mude a medida sem recálculo. Gravar `start_date` obrigaria a recalcular 19.200 atividades a cada troca de declaração — e criaria a janela em que o gravado discorda do declarado, que é a família de defeito mais cara desta base.

**Esse problema existe agora?** **Existe.** A `FR-005` é requisito, e o cenário de aceitação 2 da User Story 1 o testa diretamente.

**O que fica pior.** Custo por leitura, e ele não é trivial: a resolução precisa, para cada atividade, saber em que quadros a issue está e qual o `linked_at` de cada vínculo. **Feito ingenuamente é N+1.** A mitigação é resolver **em lote** — uma consulta que devolve o critério aplicável por issue, e um `join` contra ela. Isso é obrigação do plano, não detalhe: sem o lote, a decisão 2 não se sustenta.

E há um segundo custo: quem lê o código não vê `start_date` no schema e pode concluir que não existe. O `@moduledoc` da atividade tem de apontar para a função de resolução.

**Alternativa descartada**: gravar com invalidação ao declarar. Rejeitada porque a invalidação teria de alcançar todas as atividades de todos os quadros do projeto, e errar nisso produz medida velha sem aviso — sucesso silencioso.

### Decisão 3 — O motivo da ausência é derivado, e não gravado

Três ausências — sem critério, ambíguo, evento não coletado — são calculadas na mesma leitura, não persistidas.

**Que problema concreto resolve.** A `FR-009` exige distingui-las, e a `SC-008` exige que a tela escreva frases. Gravar o motivo repetiria o problema da decisão 2 num campo secundário: declarar um critério tornaria obsoletos os motivos gravados.

**Esse problema existe agora?** **Existe**, pela mesma razão da decisão 2.

**O que fica pior.** A consulta de leitura fica com mais ramos — é um `CASE` de quatro braços em vez de uma coluna. E os motivos passam a existir só em memória, então nenhum índice os alcança: contar "quantas ambíguas" é varredura, não índice. Com 19.200 atividades isso é aceitável; com dez vezes mais, não.

**Registrado como limite conhecido**, não como problema resolvido.

### Decisão 4 — Nenhum cache, nenhuma materialização, nenhum ETS

Não há camada de cache nesta feature.

**Que problema concreto resolve.** Nenhum — e é por isso que não entra. O volume é 19.200 atividades e 4 projetos. Cache aqui seria padrão sem problema, que o princípio VIII chama de antipadrão.

**O que ficaria pior se entrasse.** Invalidação: declarar critério teria de invalidar o cache do projeto e de todos os seus quadros, e errar produz medida velha. É exatamente o custo que a decisão 2 recusou.

**Quando revisar**: se a resolução em lote passar de 200 ms para o maior projeto. Aí o problema existe, e o padrão passa a ter justificativa.

---

## Project Structure

### Documentation (this feature)

```text
specs/042-criterio-de-inicio/
├── spec.md
├── plan.md              ← este arquivo
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── criterio.md
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

```text
priv/knowledge_base/ontology/seon/spo/modules/
└── activity_start_criterion.yaml        conceito e relações — entra ANTES do código

priv/repo/migrations/
└── ..._create_activity_start_criteria.exs

lib/the_band/ontology/seon/spo/
├── schemas/activity_start_criterion.ex
├── start_criterion.ex                   declarar, desfazer, listar, RESOLVER em lote
└── projects.ex                          (toca: expõe o critério vigente do projeto)

lib/the_band_web/live/projects_live/
└── index.ex                             (toca: declarar no projeto e no quadro)

test/the_band/ontology/seon/spo/
└── criterio_de_inicio_test.exs

test/the_band_web/live/
└── criterio_na_tela_test.exs            FR-013 a FR-017, e a SC-008
```

**Structure Decision**: a feature vive em SPO porque o conceito é da SPO. A tela é a de projetos, que já hospeda a associação de quadros — princípio X: a declaração pertence ao alvo, e uma tela própria de "configuração de critérios" obrigaria a lembrar que ela existe.

---

## Complexity Tracking

| o que | por quê | o que se paga |
|---|---|---|
| alvo polimórfico | evita a regra de precedência escrita duas vezes | constraint `exactly-one-of`, mais frágil que FK obrigatória |
| resolução em lote | sem ela a decisão 2 é N+1 | a consulta de resolução é a parte mais complexa da feature, e precisa de teste de custo |
| motivo derivado | a `SC-008` exige frase, e frase precisa do motivo vivo | contar ausências é varredura, não índice |

**Nada mais.** Sem cache, sem behaviour, sem fábrica, sem camada de serviço. O que existe é o que a `FR-005` e a `FR-007` obrigaram.

---

## O que este plano NÃO faz

- **Não define o critério de fim.** `flow.wip.count` continua indisponível, e a limitação é declarada — não é esquecimento.
- **Não implementa `flow.throughput`.** Esta feature entrega o instante de início; a medida é feature própria, e vai precisar do fim.
- **Não sugere critério.** A tela mostra o volume de cada tipo de evento e para por aí — a `FR-007` da feature 022 proíbe a plataforma escolher, e recomendar é escolher com passos extras.
- **Não migra nada.** Nenhum projeto ganha critério por padrão. Todos começam sem, e a tela conta quantos.

## Dependência bloqueante

A `FR-007` opera sobre `spo_project_boards.linked_at`, criada na feature 041 — **[PR #458](https://github.com/The-Band-Solution/theband/pull/458), ainda não mergeado**. A implementação desta feature não começa antes daquele merge.
