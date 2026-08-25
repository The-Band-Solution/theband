# Research: O critério de início

**Feature**: 042 · **Data**: 2026-08-24

Tudo aqui foi **medido no banco de desenvolvimento**, não estimado. Onde digo que algo não serve, é porque testei.

---

## R1 — SPO pode receber o conceito sem ganhar dependência

**Decisão**: `spo.activity_start_criterion` entra em SPO, especializando `ufo.social_object`.

**Verificado**: `priv/knowledge_base/ontology/seon/spo/ontology.yaml` declara `dependencies: [ufo, eo]`. A dependência já existe.

**Por que importava conferir**: o princípio IX proíbe acrescentar dependência para acomodar um conceito. Se SPO não declarasse `ufo`, o conceito teria de ir para outro lugar — não bastaria acrescentar a linha.

---

## R2 — `ufo.social_object` é a categoria certa, e a rede já diz por quê

**Decisão**: o critério é `social_object`, não `disposition` nem `relator`.

**Fundamento**, direto da base:

> `ufo.social_object` — "Objeto cuja existência depende de **convenção social**. Documentos, requisitos e user stories são objetos sociais."

Qual evento marca o início depende de convenção: organizações diferentes respondem diferente e nenhuma está errada, porque a resposta não está no dado.

**Alternativas consideradas**:

| categoria | por que não |
|---|---|
| `ufo.disposition` | disposição se **manifesta** em evento; o critério não se manifesta, ele **reconhece** |
| `ufo.relator` | relator media dois relata; aqui não há dois indivíduos ligados por um vínculo — há uma declaração sobre um tipo |
| atributo de `spo.project` | apaga o conceito. E não permitiria a declaração no quadro, que a `FR-003` exige |

**O que a rede já tinha e fechou o desenho**: `ufo.event` **traz à tona** `ufo.situation` (`ufo.brings_about`, causação). O evento observado traz à tona a situação *"o trabalho começou"*. O critério nomeia **qual** tipo de evento a organização aceita como aquele que a traz.

---

## R3 — `collected_at` não serve para desempatar, e foi medido

**Decisão**: descartado.

**Medição, 2026-08-24**, sobre as 414 issues em mais de um quadro:

```
diferença entre a primeira e a última coleta da MESMA issue:
  média 0,0s · mínimo 0,0s · máximo 0,0s
```

**Empate em 100% dos casos.** As duas linhas de `project_items` são gravadas na mesma varredura, com o mesmo carimbo. Ordenar por `collected_at DESC` devolveria a linha que o plano de execução escolher — resultado **não-determinístico** para a mesma consulta sobre o mesmo dado.

**E o significado é errado, mesmo se houvesse diferença.** `collected_at` é *quando nós olhamos*. Observar um quadro antigo pela primeira vez amanhã daria a ele o carimbo mais recente, e ele venceria o quadro onde o trabalho está há um ano.

**Um detalhe que quase enganou**: ordenar por `collected_at` escolhe o quadro vivo em **404 de 414** (97,6%). Não é mérito — como todas empatam em zero, esses 404 são a ordem física das linhas coincidindo com a ordem de observação. Acerto por acidente, que funciona até alguém reorganizar a tabela.

---

## R4 — `AddedToProjectV2Event` não serve, e também foi medido

**Decisão**: descartado.

A pergunta era se o evento de entrada no quadro poderia datar o vínculo issue↔quadro.

**Medição**: o payload coletado tem exatamente

```
["__typename", "actor", "createdAt"]
```

**Não identifica o quadro.** Sabemos que a issue entrou em *algum* quadro e quando — não em qual. Inútil para desempatar entre dois.

**O que seria preciso**: acrescentar `projectV2 { id }` à consulta da timeline e recoletar. Fora de escopo, e a lição L68 avisa que recoletar não é automático — o corte incremental excluiria as antigas.

---

## R5 — `linked_at` é a única data que significa a coisa certa

**Decisão**: o desempate é `spo_project_boards.linked_at` mais recente.

| | `collected_at` | `linked_at` |
|---|---|---|
| quem gera | a varredura | **uma pessoa** |
| tem autor | não | **sim** |
| empata nos 414 | **sim, 100%** | não — são gestos separados |
| muda ao recoletar | ganha valor novo em quadro novo | **nunca muda** |
| significa | quando olhamos | **qual quadro a organização diz ser o corrente** |

A migração observada no dado — `Produtos Internos` → `[DEPRECATED] Produtos Internos` — foi decisão de alguém. `linked_at` registra a decisão.

**Divergência assumida do padrão da casa**: `issue_mapping_rules` usa `position` para precedência, com ordem explícita. Aqui a ordem é implícita na data. O motivo: associar o quadro novo por último **já é** o gesto de dizer qual é o corrente, e pedir uma ordenação separada seria pedir à pessoa que declarasse duas vezes a mesma coisa. Registrado para que a divergência seja deliberada, não acidental.

**Buraco conhecido**: associação em lote produz `linked_at` iguais, e o empate volta. Vira `criterio_ambiguo` — a `FR-008`.

---

## R6 — Os eventos candidatos, com volume

Medido em `spo_performed_project_activities`, 2026-08-24:

| tipo de evento | ocorrências | o que significaria escolher |
|---|---:|---|
| `ProjectV2ItemStatusChangedEvent` | **5.965** | começou ao sair do Backlog — descreve execução, e depende de o quadro ser usado |
| `AddedToProjectV2Event` | 3.028 | começou ao entrar no quadro — isso é planejar |
| `AssignedEvent` | 2.172 | começou ao ser designado — designar acontece semanas antes |
| `IssueTypeAddedEvent` | 2.036 | não descreve início |
| `ClosedEvent` | 1.060 | é fim, não início |

A `FR-012` manda a tela mostrar esses volumes na escolha. **A plataforma não recomenda** — mostrar volume é informar; recomendar é escolher com passos extras, e a `FR-007` da feature 022 proíbe.

---

## R7 — O tamanho do problema de leitura

**Medido**: 19.200 atividades executadas, 3.215 issues em quadro, **414 (13%) em mais de um**, 26 quadros, 4 projetos.

**Consequência para a decisão 2 do plano**: resolver o critério por atividade, uma consulta cada, seria 19.200 consultas. **A resolução tem de ser em lote** — uma consulta que devolve o critério aplicável por issue, e um `join` contra ela.

Isso não é otimização prematura: é o que torna a decisão "resolver na leitura" viável. Sem o lote, a decisão se inverte e `start_date` teria de ser gravado.

**Teste obrigatório**: custo de consulta que não cresça com o número de atividades. A base já tem esse tipo de teste — `verification` tem um contando consultas.

---

## R8 — Onde a declaração vive na tela

**Decisão**: na tela de projetos, `/projects`, junto do alvo.

**Fundamento**: princípio X — a declaração pertence ao alvo. A tela já hospeda a associação de quadros (feature 041), então declarar o critério do quadro fica ao lado de associar o quadro.

**Alternativa descartada**: tela própria de "critérios". Obrigaria a lembrar que ela existe, e separaria a declaração do objeto sobre o qual ela fala — o mesmo argumento que pôs as regras de mapeamento dentro da tela de sincronização, e não numa página separada.
