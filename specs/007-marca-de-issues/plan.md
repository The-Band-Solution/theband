# Plano de implementação: a marca de trabalho no repositório

**Feature**: `specs/007-marca-de-issues/` · **Branch**: `008-marca-de-issues` (ver R5)
**Spec**: [spec.md](spec.md) · **Pesquisa**: [research.md](research.md)
**Constituição**: v1.4.0, dez princípios

---

## Summary

Uma marca ao lado do nome do repositório dizendo se há trabalho coletado, em três valores: **tem**,
**não tem**, **não se sabe**. E o clique que leva às issues — que já existe.

Medido: 41 dos 135 repositórios têm issues vigentes. **70% das linhas não têm trabalho a
mostrar**, e descobrir isso hoje exige ler 135 números.

## Este plano é pequeno de propósito

A primeira versão da spec tinha 22 requisitos para um símbolo, e a pessoa mantenedora recusou. Um
plano com quatro padrões novos seria o mesmo erro numa fase diferente.

**Nenhum padrão novo é introduzido.** O plano tem três mudanças, e duas delas **reduzem** código:

| mudança | efeito |
|---|---|
| consulta agrupada de contagem | 135 consultas viram **1** |
| markup na célula, sem componente | nada a mais para manter |
| uma coluna de evento | a única coisa que a plataforma não sabe |

## Technical Context

| | |
|---|---|
| Linguagem | Elixir 1.20.2 / OTP 29 |
| Framework | Phoenix 1.8.9 + LiveView |
| Persistência | Ecto + PostgreSQL 17 |
| Escala | 135 repositórios, 4474 issues, três organizações |
| Dependência | design system e `stacked` — branch `007-interface-em-ingles` |

**Nenhuma consulta à origem.** A feature lê o que já foi coletado.

---

## Constitution Check

### I. Domínio organizado pelas ontologias — **conforme**

Nenhum conceito novo. A marca é estado **de exibição**, derivado da contagem — não entra em
nenhuma das doze ontologias, e não deve: "repositório com trabalho" não é uma coisa que a rede
modela, é uma pergunta que alguém faz olhando a tela.

### II. Fonte externa não é domínio — **conforme**

A contagem vem de `collected_issues`, camada de plataforma. Nada é gravado em tabela de ontologia.

### III. Proveniência e idempotência (NÃO NEGOCIÁVEL) — **conforme, e ampliada**

`issues_collected_at` é **proveniência de coleta**: registra que a fase de issues rodou para
aquele repositório. É o que permite dizer "olhei e não achei" em vez de "não sei" — e a
diferença entre as duas frases é exatamente o que este princípio protege.

Idempotente por construção: a coluna é sobrescrita com a data da última coleta, e reescrever com
a mesma data não muda nada.

### IV. Semântica declarada em YAML versionado — **conforme, sem acréscimo**

A feature não introduz conceito, regra nem mapeamento. Nada a declarar na base.

### V. Monólito modular multitenant — **conforme**

A consulta nova entra em `TheBand.WorkItems`, atrás da fronteira, recebendo `%Tenant{}`.
Repositório de outro tenant não aparece, e a consulta a ele responde **não encontrado**.

### VI. Spec Kit e sprint backlog antes do código — **conforme**

Spec, checklist, pesquisa, este plano, data-model, contrato e quickstart antes da primeira linha.
**É a primeira feature desde a 005 a cumprir isto na ordem**, e a diferença em relação à 006 e à
007 está declarada nos planos delas.

### VII. Quality gates e revisão independente — **conforme por construção**

Dez gates. O contrato da API vem antes da primeira função pública, em
[contracts/](contracts/repository-work-mark.md).

### VIII. Desenho que o problema justifica — **conforme, e o registro é curto**

Ver a seção abaixo. **Um** item, e dois padrões explicitamente recusados.

### IX. Ontologias modulares e autônomas — **não se aplica**

A feature não atravessa fronteira entre ontologias: lê `collected_issues` e
`observed_repositories`, ambos da camada de plataforma, e a organização vem por `EO` como já vem.

### X. Responsabilidade única, em módulo e em tela — **conforme, e foi o que decidiu não criar
componente**

A tela `/work` continua respondendo uma coisa: *o que a coleta classificou, no tenant*. A marca
não acrescenta pergunta — ela torna visível uma resposta que a tela já dava por número.

E o princípio decidiu contra o componente: um componente para um chamador não divide
responsabilidade, só acrescenta um salto para ler.

---

## Registro dos padrões introduzidos (princípio VIII)

### P1 — `observed_repositories.issues_collected_at`

**Qual problema concreto resolve?** Distinguir "coletado e vazio" de "nunca coletado". Hoje os
dois são indistinguíveis, e a tela mostraria `0` para ambos — ausência desenhada como quantidade,
que o design system proíbe.

**O problema existe agora?** **Sim, e é a maioria**: 61 dos 135 repositórios têm zero issues, e
não há como dizer quais nunca foram consultados.

**O que fica pior?** Um lugar a mais para esquecer de escrever. Se a fase de issues gravar a data
para uns e não para outros, a marca mente sobre coleta — e mentir sobre coleta é pior que não
saber. Mitigação: a gravação fica no **mesmo ponto** que já grava o checkpoint da fase, e o teste
exige que os dois andem juntos.

### Padrões **recusados**, e por quê

| Recusado | Por quê |
|---|---|
| componente `<.work_mark>` | um chamador só; tabela e cartão são o mesmo HTML — R1 |
| reusar `<.evidence>` | ela responde "de onde veio o conceito"; a marca responde "há trabalho" |
| coluna com a contagem | situação materializada — ADR 0004 D7; envelheceria em silêncio |
| ordenar ou filtrar a lista | não foi pedido; fora do escopo pela spec |
| a marca dizer o estado de observação | a coluna `state` já diz — FR-004 |

---

## Project Structure

```text
specs/007-marca-de-issues/
├── spec.md          14 FR, 11 SC, 2 user stories, 5 casos de borda
├── research.md      R1 a R5
├── plan.md          este documento
├── data-model.md    uma coluna
├── contracts/
│   └── repository-work-mark.md
├── quickstart.md    V1 a V9
└── checklists/requirements.md
```

```text
lib/the_band/work_items/queries.ex     + count_collected_by_repository/2
lib/the_band/work_items.ex             + o defdelegate
lib/the_band/ingestion/github_work_items.ex   grava issues_collected_at
lib/the_band/ontology/seon/cmpo/
├── commands.ex                        + mark_issues_collected/3
├── queries.ex                         list_observed expõe issues_collected_at
└── schemas/observed_repository.ex      + o campo
lib/the_band_web/live/work_item_live/index.ex  a marca na célula
priv/repo/migrations/*_add_issues_collected_at.exs
```

---

## Fases, e por que esta ordem

### F1 — A consulta agrupada

`count_collected_by_repository/2` devolve o mapa, e o LiveView troca as 135 chamadas por uma.

**Primeiro porque paga sozinha**: a tela fica mais rápida antes de a marca existir, e se a feature
parar aqui o ganho permanece.

### F2 — A coluna de evento

Migração, campo no schema, `mark_issues_collected/3` em CMPO, e a chamada na fase de issues — no
mesmo ponto que grava o checkpoint.

**Depende de nada**, e vem antes da tela porque a marca sem ela não sabe distinguir vazio de
desconhecido — e mostraria `0` para os dois, que é o defeito que a feature existe para não ter.

### F3 — A marca na tela

Markup na célula, três estados, com forma, texto e rótulo acessível.

**Por último**, e é a ordem certa: a marca é a única parte que não pode ser verificada sem o resto.

---

## O que a análise mudou neste plano

`/speckit-analyze` rodou antes da primeira linha de código e achou **um defeito crítico no próprio
desenho**, mais cinco menores. As correções estão nos artefatos, e duas mudam decisão:

| # | O que estava errado | O que passou a valer |
|---|---|---|
| A1 | a marca decidia pela data antes da contagem, e diria `not collected yet` sobre os **41** repositórios que têm issues — porque depois da migração todos têm data nula | a ordem é **contagem primeiro**; a data só decide quando a contagem é zero — FR-005a, T005, V9 |
| A5 | o MVP declarado era F1+F3, que produz tela afirmando coleta que não houve | o MVP é **F1+F2+F3**; só F1 é cortável sozinha |
| A2 | FR-010 tinha verificação no quickstart e nenhum SC | SC-007 |
| A3 | nenhuma tarefa dizia o que a coleta faz com `{:error, :not_found}` | T004: registra em log e segue, nunca interrompe |
| A4 | caso de borda 4 sem tarefa, sem SC e sem estar fora do escopo | declarado fora do escopo — a tela não é ao vivo |
| A6 | o quarto texto estava no contrato e faltava no data-model | tabela dos quatro textos no data-model |

**A1 é o achado que justifica a fase.** Ele não aparece em teste de unidade — cada peça funciona
—, aparece só quando se pergunta o que a tela diz no dia da migração. É o mesmo defeito da L28:
ausência de erro lida como resultado.

---

## Riscos

| Risco | Mitigação |
|---|---|
| gravar a data para uns repositórios e não outros | gravar no mesmo ponto do checkpoint; teste exige os dois juntos |
| **a marca decidir pela data antes da contagem** | ordem fixada em FR-005a; V9 mede os 41 no dado real |
| coluna e marca discordarem | uma consulta, um mapa, dois leitores — FR-010 |
| marca só por cor | forma e texto obrigatórios; teste remove a cor e exige a distinção |
| marca ilegível no cartão do telefone | o `stacked` reusa o mesmo HTML; teste em 360 px |
| a troca da contagem para "vigentes" mudar número em silêncio | no dado real nenhuma issue é não vigente; a mudança de significado está declarada em R3 |

---

## Complexity Tracking

| Item | Custo | Aceito porque |
|---|---|---|
| uma coluna nova | um ponto a mais para escrever | 61 repositórios hoje são ambíguos |
| markup na célula em vez de componente | a marca não é reusável sem refatorar | um chamador; o segundo justifica o componente |

---

## Reavaliação da constituição, pós-desenho

Dez princípios: nove conformes, um não aplicável (IX). Um padrão introduzido, cinco recusados.

O princípio X foi o que mais decidiu, e decidiu **contra** criar coisa: sem componente novo, sem
coluna de contagem, sem estado a mais na marca. A feature acrescenta 1 coluna, 1 consulta e ~15
linhas de markup — e remove 134 consultas por render.
