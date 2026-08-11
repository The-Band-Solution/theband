# Plano de implementação: regras de mapeamento de tipo por organização

**Feature**: `specs/005-regras-de-mapeamento/` · **Spec**: [spec.md](spec.md)
**Pesquisa**: [research.md](research.md) · **Constituição**: v1.4.0, dez princípios

---

## Summary

77% das issues coletadas não são promovidas a conceito nenhum: **3440 de 4455**. Delas, 3403
não têm tipo declarado na origem e 37 têm tipo que nenhuma rota reconhece — `Chore` (17),
`Refactor` (16), `Hotfix` (4).

O achado que decide o desenho: as issues sem tipo **declaram o tipo no título**. 2911 começam
com prefixo entre colchetes, e cerca de 1300 são resgatáveis — `[TASK]` 1024, `[FEATURE]` 111,
`[US]` 60, `[FIX]` 57, `[BUG]` 51.

**Mas nem todo prefixo é tipo.** `[Devops]` (340), `[Back-end]` (256), `[Front-end]` (237),
`[Dados]` (186) e `[QA]` (97) dizem **quem faz** ou **em que área** — cerca de 1600 issues. Uma
tela que sugerisse "crie regra para `[Devops]`" faria o produto ganhar 340 user stories que são
rótulos de equipe.

A feature entrega: regra de mapeamento por organização, com comparação por texto e por
expressão regular; um catálogo de regras pré-escritas que chegam **propostas**; e a tela que
mostra a lacuna agrupada, distingue o que é tipo do que não é, e permite decidir os dois casos
— inclusive **declarar que um padrão não é tipo**.

## Technical Context

| | |
|---|---|
| Linguagem | Elixir 1.20.2 / OTP 29 |
| Framework | Phoenix 1.8.9 + LiveView |
| Persistência | Ecto + PostgreSQL 17 |
| Assíncrono | Oban, fila `transformation` — **que já existe** |
| Regex | `:re` (PCRE) via `Regex.compile/2` |
| Escala | 4455 issues, até 3440 recalculadas de uma vez |

**O que já existe e a feature usa**: `WorkItems.Routing.decide/2` com precedência entre regra
do tenant e global; `issue_promotions` append-only com `rule_id` e `rule_version` em toda
linha; e o catálogo
`priv/knowledge_base/rules/github_issue_pattern_catalog.yaml`, escrito e validando nos dois
gates.

---

## Constitution Check

### I. Domínio organizado pelas ontologias — **conforme, e é o ponto sensível**

O conceito de destino de uma regra **tem de existir na base de conhecimento**: FR-004. A regra
não inventa conceito; ela declara que um texto da origem designa um conceito **já modelado**.

E o risco que este princípio nomeia é exatamente o que a feature poderia introduzir: inferir
conceito por semelhança de nome. A defesa é que a inferência **nunca é automática** — toda
regra é decisão de uma pessoa, com autor e data (FR-005), e o catálogo chega **proposto**, sem
promover nada até alguém ativar (FR-039).

### II. Fonte externa não é domínio — **conforme**

A regra é vocabulário do GitHub: nome de tipo e texto de título. Vive em tabela de plataforma,
escopada por organização observada. Nenhuma tabela de ontologia é tocada.

### III. Proveniência e idempotência (NÃO NEGOCIÁVEL) — **conforme, e ampliada**

Toda promoção por regra registra `rule_id`, `rule_version`, a **fonte da evidência** — tipo
declarado ou título — e a **confiança** (FR-014, SC-004). Isso é mais proveniência do que a
feature 004 tinha: lá bastava a regra; aqui é preciso saber se a decisão veio de um campo
declarado ou de inferência sobre texto livre.

O recálculo é idempotente (FR-027): compara com a decisão vigente e só grava quando diferem.

### IV. Semântica declarada em YAML versionado — **conforme, com a distinção que decide o
desenho**

O **catálogo** é YAML versionado, revisável em commit — conhecimento sobre convenções de
escrita de issue. A **regra da organização** é banco, porque precisa valer **sem restart**: a
base de conhecimento é carregada uma vez no boot para ETS, e uma regra criada pela tela que
vivesse no YAML não valeria até reiniciar. Isso já morreu nesta sessão.

Ver R1 da pesquisa. As duas coisas, com papéis distintos.

### V. Monólito modular multitenant — **conforme**

Regra escopada por organização observada, e organização pertence a tenant. Regra de outro
tenant devolve **não encontrada**, nunca "sem permissão" (FR-035).

Só quem tem papel de administração cria, altera ou desativa (FR-020).

### VI. Spec Kit e sprint backlog antes do código — **conforme**

Spec, checklist, pesquisa, este plano, data-model, contratos, quickstart e tarefas — todos
antes da primeira linha. **Nada desta feature está implementado**, e é a diferença em relação
à 006.

### VII. Quality gates e revisão independente — **conforme por construção**

Nove gates por `mix gates`. O contrato de API vem antes da primeira função pública, e está em
[contracts/](contracts/).

### VIII. Desenho que o problema justifica — **conforme**; ver a seção abaixo

### IX. Ontologias modulares e autônomas — **conforme, e sem travessia nova**

A regra aponta para um conceito por **identificador**, e o identificador é texto. Nenhuma
tabela de ontologia é referenciada por chave estrangeira: a validação de que o conceito existe
é feita contra a base de conhecimento em memória, não por FK entre tabelas de ontologias
diferentes.

### X. Responsabilidade única, em módulo e em tela — **conforme, e a tensão foi resolvida
explicitamente**

A tela de regras é **componente** da tela de sincronização, alcançado pela organização, com
cabeçalho próprio (R7). A tensão é real: sincronização responde *"a coleta está
funcionando"*; regras respondem *"o que a plataforma entende"*.

A resolução não é ignorar o princípio — é o componente ter **uma responsabilidade só** e a
hospedagem ficar visivelmente separada do relatório de execução (FR-051). Misturar as regras
ao cartão da execução repetiria o erro do resumo de trabalho que apareceu dentro do cartão de
cada sync: o número parecia da execução e era do tenant.

---

## Registro dos padrões introduzidos (princípio VIII)

### P1 — Catálogo em YAML composto em leitura com regra em banco

**Problema**: uma regra criada pela tela precisa valer imediatamente; um catálogo revisável
precisa passar por commit. Uma fonte só não atende às duas.

**Existe agora?** **Sim, os dois lados.** A base de conhecimento é ETS carregada no boot — e
uma regra de tenant criada depois do boot não valeu, e a tela mostrou três divergências que um
restart resolveria. E o catálogo já existe em YAML, validando nos gates.

**O que fica pior**: duas fontes para a mesma pergunta, e a composição em leitura passa a ser
código que precisa estar certo. A defesa é a chave: `(where, how, text)` normalizado, e **não**
o índice da lista — reordenar o catálogo não pode desligar decisões já tomadas.

### P2 — Confiança na promoção (`high` / `medium`)

**Problema**: promoção por tipo declarado e por inferência de título não podem parecer iguais.
Uma medida de escopo calculada sobre inferência de texto vale menos, e quem lê precisa saber.

**Existe agora?** **Sim, e em massa**: 1300 issues seriam promovidas por título contra 1015 por
tipo declarado. Sem a distinção, a maioria do backlog do produto passaria a vir de inferência
sobre texto livre sem que nada dissesse isso.

**O que fica pior**: mais uma coluna, e a tentação de tratá-la como número — "confiança 0,7".
O vocabulário é o de níveis que a base de conhecimento já usa, e não um número inventado.

### P3 — Decisão explícita de "não é tipo"

**Problema**: `[Devops]` com 340 issues fica para sempre na lista de pendências, e a lista
deixa de ser lida. Pior: a insistência empurra alguém a mapear área como tipo.

**Existe agora?** **Sim, medido**: cerca de 1600 issues têm prefixo que não é tipo, e são a
maioria dos prefixos por contagem.

**O que fica pior**: uma tabela e uma tela a mais, e o risco de alguém marcar como "não é tipo"
o que é — por isso a decisão tem autor, data e é **reversível** (FR-032).

### P4 — Recálculo sempre assíncrono, sem limite condicional

**Problema**: gravar regra afeta até 3440 issues, e o número vai crescer. Um limite
condicional — síncrono até N, assíncrono acima — cria dois caminhos, e o raro é o que quebra:
seria testado com 10 issues e usado com 3440.

**Existe agora?** **Sim**: 3440 issues não promovidas hoje.

**O que fica pior**: gravar regra não devolve o resultado na mesma requisição. A tela mostra o
progresso — que ela precisa mostrar de todo modo.

**E a fila é `transformation`, que já existe.** Declarar fila nova sem configurar faz o job
ficar `available` para sempre; aconteceu nesta sessão com uma fila `:sync` inexistente, e o
sintoma foi uma coleta que "completou" sem coletar nada.

### Padrões que **não** serão introduzidos

| Recusado | Por quê |
|---|---|
| `tool_concept_mappings` | é o caso particular `how: equals` desta feature; duas tabelas divergiriam (FR-036) |
| regra de título em YAML global | inferência sobre texto livre não pode ser padrão da plataforma |
| `Regex.compile!/2` | levantaria exceção onde o erro é previsto; princípio VIII pede retorno |
| confiança numérica | número inventado vira meta e deixa de medir |
| copiar o catálogo na conexão | 18 linhas por organização com autor "sistema", contra FR-041 |

---

## Fases, e por que esta ordem

### F1 — A regra: tabela, comando e validação

Tabela `issue_mapping_rules` escopada por organização; comando que valida antes de gravar; as
três recusas de expressão (não compila, casa vazio, lenta demais).

**Bloqueia todo o resto.** E a validação vem **junto** com o comando, não depois: a mesma
função valida na prévia, porque prévia e efeito que usam caminhos diferentes é o que o SC-007
proíbe.

### F2 — A decisão: segunda etapa em `Routing.decide/2`

Etapa 1 — tipo declarado, com precedência organização → tenant → global. Etapa 2 — título,
**só se** a etapa 1 não decidiu.

A ordem é a garantia: FR-008 exige que tipo declarado vença regra de título, e a única forma de
garantir isso é **não chegar** à etapa 2. Avaliar as duas e escolher depois deixaria a
precedência dependente da ordem de comparação.

A confiança sai daqui: etapa 1 grava `high`, etapa 2 grava `medium`.

### F3 — A prévia e o recálculo

Prévia sobre as issues já coletadas, sem consultar a origem. Recálculo na fila
`transformation`, append-only, idempotente.

**Depende de F2**: a prévia precisa da mesma função de decisão que o recálculo usa. Duas
implementações fariam a prévia mentir.

### F4 — O catálogo composto por organização

Leitura do catálogo em ETS; composição com as regras da organização pela chave
`(where, how, text)`; contagem de quantas issues cada proposta casaria.

**Depende de F1** para saber o que já foi decidido, e de F3 para contar.

### F5 — A tela

Componente na tela de sincronização, alcançado pela organização: lacunas agrupadas, propostas
do catálogo com contagem, regras vigentes na ordem de aplicação, e a ação de declarar que um
padrão não é tipo.

**Por último**, e é a ordem certa: a tela é a única parte que não pode ser verificada sem o
resto.

---

## Riscos

| Risco | Mitigação |
|---|---|
| expressão patológica prender a tela | avaliação em `Task` com limite de tempo, sobre amostra de títulos reais |
| prévia divergir do efeito | uma função de decisão só, usada pelas duas |
| regra de título vencer tipo declarado | etapa 2 não é alcançada quando a etapa 1 decide |
| catálogo reordenado desligar decisões | chave é `(where, how, text)`, nunca o índice |
| atualização do catálogo sobrescrever edição | composição em leitura; nada é copiado (FR-043) |
| área mapeada como tipo | catálogo marca os 8 padrões que **não** são tipo, e a tela os separa |

---

## Complexity Tracking

| Item | Custo | Aceito porque |
|---|---|---|
| duas fontes de regra | composição em leitura | valer sem restart é requisito, e o YAML precisa de revisão |
| confiança por nível | mais uma coluna e mais um vocabulário | 1300 issues por inferência sem aviso seria pior |
| recálculo assíncrono | resultado não vem na mesma requisição | um caminho só, e o progresso já era necessário |
| tabela de "não é tipo" | mais uma tabela e mais uma tela | 1600 issues em pendência eterna faz a lista parar de ser lida |

---

## Reavaliação da constituição, pós-desenho

Dez princípios conformes. O I é o que exigiu mais cuidado, e a defesa não é declaratória: a
inferência sobre texto livre **nunca** é automática, o catálogo chega proposto, e a promoção
por título carrega confiança menor e fonte da evidência em toda linha.

O X foi resolvido com componente de responsabilidade única hospedado por outra tela, e a
alternativa recusada — página própria em `/mapeamento` — está registrada com o que se perderia.
