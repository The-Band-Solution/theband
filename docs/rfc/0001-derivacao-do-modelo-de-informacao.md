# RFC 0001 — Derivação do modelo de informação a partir da rede de ontologias

**Status**: Aberto a comentários
**Criado**: 2026-08-09
**Relacionado**: [ADR 0004](../adr/0004-modelo-de-informacao-one-table-per-kind.md)

## Resumo

A [ADR 0004](../adr/0004-modelo-de-informacao-one-table-per-kind.md) decidiu
*como* transformar a ontologia em modelo de informação: `one table per kind`, de
Guidoni, Almeida & Guizzardi (2020). Este RFC reúne o que aquela decisão **não**
resolve, e que precisa ser discutido antes de gerar migrações.

Dez questões. Cinco bloqueiam a derivação; as demais afetam desempenho, escopo de
ingestão ou modularidade. Cada uma traz contexto, alternativas medidas quando foi
possível medir, e o que ela trava.

Uma questão sai desta lista de duas formas: virando ADR, quando a decisão é
arquitetural e cara de reverter, ou virando trabalho na base de conhecimento,
quando é matéria de modelagem.

**Convenção**: `Q<n>` estável — números não são reciclados. Questão resolvida
permanece na lista, marcada, com o destino registrado.

| # | Questão | Bloqueia | Prioridade |
|---|---|---|---|
| [Q1](#q1) | Como tratar perdurantes, que o método não cobre | derivação do modelo | **alta** |
| [Q2](#q2) | Fronteira de aplicação: rede, ontologia ou módulo | 26 vs 94 tabelas | **alta** |
| [Q3](#q3) | Kind importado: cópia ou referência | esquema e autonomia | **alta** |
| [Q4](#q4) | Estereótipo OntoUML de 142 conceitos | o método não roda | **alta** |
| [Q5](#q5) | Generalization sets não declarados | discriminador vs tabela | **adiada** |
| [Q6](#q6) | 41 roles sem relator que os medeie | perda de contexto | média |
| [Q7](#q7) | `spo.artifact` é `category`? | tamanho da god table | média |
| [Q8](#q8) | Particionamento como alternativa à fronteira | desempenho | baixa |
| [Q9](#q9) | Origem do papel organizacional | fatia 1 da ingestão | média |
| [Q10](#q10) | Perfil de consulta: polimórfico vs específico | escolha da fronteira | média |
| [Q11](#q11) | Extrair a derivação como biblioteca independente | nada por ora | baixa |

---

## Q1 — Como tratar perdurantes, que o método não cobre {#q1}

**Contexto.** Guidoni et al. tratam de *object sortals* e relators — endurantes.
Processos e atividades executadas são perdurantes, e são justamente os maiores
absorvedores do nosso modelo: `spo.performed_project_activity` com 46 subtipos,
`spo.performed_project_process` com 29.

Sortalidade e rigidez são definidas para endurantes. Aplicá-las a eventos é
analogia, não aplicação do método.

**Alternativas.**

- Tratar por analogia, assumindo que ocorrências de atividade compartilham
  princípio de identidade. Simples, mas sem respaldo no método.
- Definir estratégia própria para perdurantes, com critério explícito.
- Verificar se há trabalho posterior do grupo do NEMO cobrindo eventos — existe
  um artigo de 2021 dos mesmos autores sobre *forward engineering* que pode ter
  avançado nisso.

**Como resolver.** Consultar João Paulo A. Almeida, coautor do paper e
coorientador da tese. É a via mais curta e mais confiável.

**Bloqueia.** A derivação do modelo de informação para SPO, CMPO, ROoST, QAPO,
SRO, CIRO e CDRO — ou seja, quase tudo.

---

## Q2 — Fronteira de aplicação da transformação {#q2}

**Contexto.** O paper trata de **um** modelo conceitual. A tese trabalha com uma
**rede** de ontologias, e fala em *information models* no plural, com um OBDR por
ontologia. Aplicar o método à rede inteira ou a cada ontologia dá resultados
muito diferentes.

| Fronteira | Tabelas | Maior agrupamento |
|---|---:|---:|
| Rede inteira | 26 | 45 subtipos numa tabela |
| Por ontologia, importando o kind externo | 94 | 8 |
| Por módulo | 144 | 6 |

**Observação relevante.** O número 94, derivado formalmente, coincide com as 94
entidades obtidas por curadoria manual, por caminho independente.

**Depende de.** Q7 — se `spo.artifact` for `category`, ele é achatado no passo 1 e
a god table encolhe sem precisar de fronteira. A fronteira passaria a ser escolha
de modularidade, não remédio para sintoma.

**Bloqueia.** O número de tabelas, o desenho dos módulos Elixir, e a estratégia
de índices.

---

## Q3 — Kind importado: cópia ou referência {#q3}

**Contexto.** Aplicando a transformação por ontologia, um conceito de ontologia
mais geral precisa aparecer na ontologia específica. A tese resolve por
**replicação**:

> the same ontological concept (e.g., Code appears in SysSwO and CIRO) can appear
> in different OBDRs (…) we added two attributes, Internal_id and Version

**Alternativas.**

- **Cópia.** Fiel à tese. Cada módulo autônomo, pronto para virar serviço.
  Custo: 21 conceitos replicados em CIRO, 14 em SRO, e sincronização que no
  monólito seria código nosso — pagar consistência eventual dentro do mesmo banco
  é o pior dos dois mundos.
- **Referência.** FK para a tabela da ontologia dona. Sem sincronização, mas os
  módulos passam a se tocar no nível do banco, e extrair um para serviço depois
  exige desfazer as FKs.

**Inclinação atual.** Referência, por coerência com a [ADR 0001](../adr/0001-monolito-modular-elixir.md):
enquanto for um banco só, transação local resolve o que o `internal_id`
resolveria. As colunas `internal_id` e `record_version` continuam existindo,
prontas para o dia em que um módulo virar serviço.

**Não decidido.** A inclinação não foi confirmada.

---

## Q4 — Estereótipo OntoUML de 142 conceitos {#q4}

**Contexto.** A transformação decide tudo por duas meta-propriedades:
sortalidade e rigidez. A base declara `ufo_category`, que mistura estereótipos
OntoUML (`role`, `phase`, `relator`, `collective` — 65 conceitos) com categorias
de topo da UFO (`object`, `action`, `social_object` — 142 conceitos), e estas
**não decidem** se o conceito é kind, subkind ou category.

**Proposta.** Campo novo e explícito, `ontouml_stereotype`, declarado e revisado
— não derivado, porque a decisão é conceitual.

**Ordem sugerida.** Começar pelos **24 candidatos a kind** (conceitos sem parent):
são eles que decidem onde as tabelas pousam, e cada erro ali propaga para dezenas
de descendentes.

**Testes operacionais.**

1. *Identidade*: para comparar dois deles e dizer se são o mesmo indivíduo, uso
   sempre o mesmo critério? Se muda conforme o caso → não-sortal.
2. *Rigidez*: pode deixar de ser isso e continuar existindo? → antirrígido.
3. *Role vs phase*: o que o faz ser isso é uma relação com outra coisa, ou uma
   propriedade dele mesmo?

**Bloqueia.** Tudo. Sem isso o método não roda.

---

## Q5 — Generalization sets não declarados {#q5}

**Status: adiada por decisão consciente.** O modelo ainda não tem maturidade para
declarar generalization sets com confiança, e o método para chegar lá será
discutido separadamente. Esta seção registra o estado e propõe um comportamento
provisório, não uma solução.

**Contexto.** Nenhum conceito da base declara generalization set. O passo 2 do
método precisa saber se um conjunto é **disjunto** ou **sobreposto** para escolher
entre discriminador enumerado e tabela discriminadora de qua-entities, e se é
**completo** ou **incompleto** para decidir se o discriminador admite nulo.

**Por que importa.** O caso sobreposto não é hipotético: uma pessoa acumulando
papéis simultâneos é uma das perguntas que a plataforma existe para responder.

**Estado atual.** Existem 38 conjuntos de subtipos irmãos na base:

| Natureza dos irmãos | Conjuntos | Leitura |
|---|---:|---|
| Só `phase` | 5 | **disjuntos por natureza** — ninguém está em duas fases do mesmo eixo |
| Só `role` | 8 | **candidatos a sobreposto** — papéis acumulam |
| Mistos ou rígidos | 25 | exigem análise caso a caso |

Os oito conjuntos de papéis são os que mais provavelmente precisam de tabela em
vez de coluna:

`spo.project_stakeholder` · `sro.scrum_role` · `sro.scrum_team_member` ·
`sro.product_owner` · `sys_swo.software_resource` · `sys_swo.hardware_resource` ·
`spo.resource` · `cmpo.branch`

**Comportamento provisório proposto.** Enquanto a questão não amadurece, e para
não bloquear todo o resto:

- conjuntos só de `phase` → tratados como **disjuntos e completos**, com
  discriminador enumerado não nulo;
- conjuntos só de `role` → **não derivar discriminador**; o papel espera a
  reificação do relator prevista em [Q6](#q6), que resolve sobreposição por
  construção;
- conjuntos mistos ou rígidos → derivação **bloqueada**, listada como pendência
  explícita em vez de receber default silencioso.

A terceira regra é a que importa: um default silencioso aqui produziria esquema
plausível e errado, e o erro só apareceria quando alguém precisasse registrar
dois valores ao mesmo tempo.

**A discutir depois.** O método para levantar disjunção e completude — se por
revisão conceito a conceito, se por evidência nos dados já coletados, ou se por
inferência a partir das restrições já declaradas em `rules/`.

## Q6 — 41 roles sem relator que os medeie {#q6}

**Contexto.** A base tem 44 roles e 5 relators. Apenas 3 roles são mediados por
relator declarado. Em UFO todo role é relacionalmente dependente — um role sem
relator é uma relação que não foi reificada.

**Consequência.** Um discriminador booleano registra a classificação e perde o
contexto: `codes.is_under_integration = true` não diz em qual processo de CI,
desde quando, nem admite dois processos simultâneos.

**Exemplos do que falta reificar.**

| Role sem relator | Relator ausente |
|---|---|
| `ciro.code_under_integration` | participação do código no processo de CI |
| `cdro.delivered_code` | entrega daquele código naquela atividade |
| `ciro.building_software_resource` | uso do recurso naquele ambiente de build |
| `roost.code_to_be_tested` | vínculo do código com o caso de teste |
| `cmpo.source_branch` / `target_branch` | papel da branch naquele check-in |

**Precedente na própria base.** `eo.team_membership` já é esse padrão — pessoa,
equipe, papel e período, em vez de `is_team_member` na pessoa.

---

## Q7 — `spo.artifact` é `category`? {#q7}

**Contexto.** `spo.artifact` tem 52 descendentes em 9 ontologias, e seus filhos
diretos incluem `software_item`, `information_item` e `software_product`.

Pelo teste da identidade: um item de software e um item de informação têm o mesmo
critério de identidade? Um é peça de software, o outro é informação para uso
humano. Aparentemente não — o que faria de `spo.artifact` uma `category`,
não-sortal, **achatada** no passo 1 e sem tabela própria.

**Consequência se confirmado.** A maior god table desaparece por construção, e
Q2 muda de natureza: a fronteira por ontologia deixa de ser necessária para
corrigir sintoma.

**Mesmo teste pendente** para `spo.performed_project_activity`, com o
complicador de Q1: é perdurante.

**Como resolver.** Revisão conceitual, preferencialmente com quem conhece a SPO.

---

## Q8 — Particionamento como alternativa à fronteira {#q8}

**Contexto.** PostgreSQL permite `PARTITION BY LIST` no discriminador: uma tabela
lógica, N partições físicas. Consulta polimórfica continua sendo uma tabela;
consulta específica faz *partition pruning*.

Aproximaria o melhor dos dois mundos de Q2, ao custo de DDL de partição mais
trabalhoso de evoluir — e com 46 valores de discriminador, 46 partições.

**Só faz sentido avaliar depois de Q1, Q2 e Q7.**

---

## Q9 — Origem do papel organizacional {#q9}

**Contexto.** `eo.team_membership` exige papel. O GitHub não fornece:
`MAINTAINER` e `MEMBER` são níveis de acesso de plataforma. O vínculo observado
fica como evidência pendente, e `memberships_pending_role` é métrica de lacuna.

**Pergunta.** O papel vem de cadastro manual no The Band, ou existe outra fonte
que já registra função por pessoa — Jira, Azure DevOps, sistema de RH, planilha
de alocação?

**Bloqueia.** Decidir se o cadastro de papéis entra na fatia 1 da ingestão ou
fica para depois. Levantada três vezes, ainda sem resposta.

---

## Q10 — Perfil de consulta: polimórfico vs específico {#q10}

**Contexto.** A escolha da fronteira em Q2 depende de qual perfil de consulta
domina. Consulta polimórfica favorece menos tabelas; consulta específica favorece
mais tabelas e menores.

**Como resolver.** É decidível com o que já existe: classificar as 64 perguntas
de competência declaradas na base em polimórficas e específicas, e medir a
proporção.

**Hipótese.** A maioria é específica por ontologia — *quais cerimônias*, *quais
user stories*, *quais builds falharam*. As poucas polimórficas são as de
rastreabilidade transversal, que já exigiriam junção de qualquer forma.

Se confirmado, a fronteira por ontologia otimiza o caso comum.

---

## Q11 — Extrair a derivação como biblioteca independente {#q11}

**Contexto.** `scripts/derive_information_model.py` não tem nada de específico do
The Band: implementa `one table per kind` mais duas extensões — rede de
ontologias por referência e geração de views — que servem a qualquer projeto
partindo de OntoUML.

Os autores mantêm implementação de referência em
[nemo-ufes/ontouml2db](https://github.com/nemo-ufes/ontouml2db), sobre modelos
isolados. Havendo interesse do grupo, contribuir para lá é preferível a manter
implementação paralela — o coorientador da tese é coautor do paper.

**Pré-requisitos**, detalhados em [scripts/README.md](../../scripts/README.md):
fechar Q4 (142 conceitos sem estereótipo), separar método de convenção deste
projeto, aceitar o JSON do padrão OntoUML como entrada, emitir DDL como saída, e
testar contra os dez modelos públicos usados no paper.

**Não bloqueia nada.** Registrada para não se perder — o sinal de que chegou a
hora é a derivação rodar sobre as doze ontologias sem intervenção manual.
