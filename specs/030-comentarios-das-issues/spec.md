# Feature 030 — Os comentários das issues, e a participação nas discussões

**Criada**: 2026-08-17 · **Origem**: issues #318 (a lacuna, 2026-08-14) e #400 (o pedido,
2026-08-16), com a decisão ontológica tomada pela pessoa mantenedora em 2026-08-17 ·
**Estende**: a coleta de issues (004/022) e o material do perfil (026/027)

## O propósito

A plataforma coleta a issue — título, corpo, estado, designados — mas não a conversa. E a
conversa é onde mora o trabalho que designação nenhuma captura: quem destrava, quem
responde, quem revisa. Dois fatos medidos sustentam a feature: **24 de 88 pessoas** do
tenant real aparecem sem nenhuma issue designada (parte delas pode trabalhar exatamente
na conversa), e **"parada há 90 dias" hoje é a mesma frase** para a issue abandonada em
silêncio e para a que tem discussão ativa — diagnósticos opostos, ações opostas.

## A decisão ontológica (fechada em 2026-08-17)

A #318 documentou: **a rede não tinha conceito para comentário**. `spo.information_item`
foi examinado e recusado — item de informação é artefato do processo, produzido para
entrega ou consumo por atividade; comentário é comunicação *sobre* o artefato. Das três
saídas documentadas, a pessoa mantenedora escolheu **estender o continuum**: nasce a
**CMO (Communication Ontology)**, fundada em UFO, com quatro conceitos e a cadeia que
os liga:

| conceito | UFO | o quê |
|---|---|---|
| `cmo.commenting_act` | action | o ato de comentar — evento, com autor e instante |
| `cmo.comment` | social_object | a manifestação escrita que o ato publica |
| `cmo.discussion` | collective | o conjunto dos comentários de um artefato |
| `cmo.discussion_participation` | **relator** | agente × discussão, fundado nos atos — nunca booleano |

A cadeia é deliberada: **participação é relação entre agente e evento** — artefato não
tem participante. O que a origem entrega (o comentário, com autor) é **observado**; o
ato e a participação são **derivados** dele — hachura e rótulo na tela, como sempre.

Artefatos já escritos e validados pela base: `ontology/continuum/cmo/` (ontologia,
módulo, 4 competency questions) e `mappings/github/cmo/issue_comment.yaml`
(equivalência **total**, com as limitações de edição/apagamento, reações e review
threads declaradas).

## User stories

**US1 (P1)** — Como quem lê uma issue, quero ver a discussão dela — quem disse o quê,
quando — para entender o estado real do trabalho sem abrir o GitHub.

**US2 (P1)** — Como quem coordena, quero que "parada há 90 dias" distinga **parada em
silêncio** de **parada com discussão ativa** — porque a primeira pede decisão de morte
ou retomada, e a segunda pede destravar o bloqueio ou atualizar o registro.

**US3 (P2)** — Como quem lê a página de uma pessoa, quero ver de quais discussões ela
participou — inclusive em issues que nunca lhe foram designadas — para que colaboração
conte como evidência sem fingir que é tarefa executada.

## Functional requirements

- **FR-001**: A coleta MUST trazer os comentários das issues dos repositórios
  observados, incremental (só issues com `comment_count > 0` e atualizadas desde a
  última coleta), preservando `raw_payload` e os campos de proveniência.
- **FR-002**: O registro coletado MUST seguir o mapeamento
  `github.issue_comment.to.cmo.comment`: corpo como texto plano, autor pela regra dos
  designados (login registrado; vínculo com pessoa só quando coletada — nunca
  inventado), edição marcada por `edited_at`, sumiço marcado por
  `no_longer_observed_at` — **nunca apagado**.
- **FR-003**: O detalhe da issue MUST mostrar a discussão: autor (linkado quando
  pessoa coletada), quando, corpo. Issue sem comentário MUST dizer "no discussion
  collected for this issue" quando a coleta ainda não passou, e "no comments" quando
  passou e não há — **os dois estados são distintos e nomeados**.
- **FR-004**: O anti-padrão de issue parada MUST distinguir e rotular: parada **sem
  discussão nunca** / parada com discussão **antiga** (último ato antes do limiar de
  parada) / parada com discussão **recente** — com o instante do último ato dito.
- **FR-005**: A participação (pessoa × discussão) MUST ser **derivada na leitura** dos
  comentários coletados — nunca contador armazenado — e MUST carregar hachura e rótulo
  de derivado onde aparecer.
- **FR-006**: A página da pessoa MUST listar as discussões de que ela participou no
  período: issue (linkada), quantos comentários, primeiro e último ato — em seção
  própria, dizendo que participação não é tarefa executada.
- **FR-007**: Comentário de autor sem pessoa coletada MUST aparecer com o login em
  texto, sem link — a mesma regra declarada da feature 014.
- **FR-008**: A coleta MUST respeitar o rate limit medido (a consulta declara `rateLimit`
  como as demais) e MUST registrar na fase de sync o que cobriu: issues visitadas,
  comentários coletados, marcados como não mais observados.

## Success criteria

- **SC-001**: Na base real (medição de 2026-08-14: 1.967 comentários, 1.182 issues com
  pelo menos um, máximo 16 numa issue), a coleta termina e os totais na tela batem com
  a origem — conferidos por amostra contra a API, não pela suíte.
- **SC-002**: A issue #4191 (ou outra parada real) mostra o rótulo certo entre os três
  de FR-004, verificado ao vivo.
- **SC-003**: Pelo menos uma das 24 pessoas no_assignment aparece com participação em
  discussão — ou a ausência disso vira achado registrado (nem por outro canal ela
  colabora nos repositórios coletados).
- **SC-004**: Nenhuma consulta por linha: o detalhe da issue e a seção da pessoa somam
  número fixo de consultas, provado pelo contador único.

## Fora do escopo (registrado, não silenciado)

- Comentários de pull request review (outro fio, âncora em código) — limitação escrita
  no mapeamento; vira feature própria se sustentar decisão.
- Reações (👍) — ato comunicativo mais fraco, fora até sustentar decisão.
- Menções (@pessoa) como relação derivada — possível futuro, não afirmado.
- Uso da participação no **material do perfil** (modelo de linguagem) — decisão
  separada da pessoa mantenedora, porque muda o que o perfil afirma; esta feature
  entrega a participação na tela, não no prompt.
