# Feature Specification: o painel da pessoa, e o que ele recusa afirmar

**Feature**: `023-painel-da-pessoa` · **Criada em**: 2026-08-15
**Estado**: rascunho, pronta para `/speckit-plan`
**Origem**: decisão da pessoa mantenedora — *"quero um dashboard individual por pessoas"*.

## O pedido

> "Quero um dashboard individual por pessoa, com as tarefas que está executando atualmente,
> throughput, e outras métricas. Pensei em colocar uma aba em cada pessoa."

---

## O que a medida achou, e por que ela muda a feature

**Medido em 2026-08-15**, no banco de desenvolvimento com dado real das três organizações.

### Primeiro: o dado por pessoa existe

```
88 pessoas · 60 com designação vigente · 4286 designações, todas com person_id resolvido
```

Não há lacuna de identidade: toda designação vigente aponta para uma pessoa conhecida. O painel
tem de quem falar.

### Segundo: a cobertura da timeline é de 5 repositórios em 53

```
53 repositórios têm issues coletadas
 5 repositórios têm alguma atividade de timeline
```

E o efeito por pessoa é brutal:

| Pessoa | Designadas abertas | Delas, em repositório com timeline |
|---|---:|---:|
| vinicius-je | 152 | **0** |
| ManoelRL | 103 | **0** |
| marcelasfl | 103 | 3 |
| joaopbarcellos | 73 | **0** |

**Isto é o achado que define a feature.** Uma tela que mostrasse "0 atividades" para `vinicius-je`
estaria dizendo que ele não trabalhou. O que o dado diz é que **a plataforma não olhou** os
repositórios dele.

As duas frases produzem o mesmo zero e afirmam coisas opostas. É a **L57**, e o custo aqui é maior
que nos casos anteriores: não é um gate que passa errado, é uma pessoa julgada por um número que
mede a coleta, não o trabalho dela.

### Terceiro: a distribuição é concentrada

```
paulossjunior responde por 75,9% das 1927 atividades
15 pessoas têm alguma atividade; 60 têm designação
```

Um ranking por volume diria mais sobre **quais repositórios foram coletados** do que sobre quem
trabalha. Ordenar pessoas por atividade, hoje, produz uma lista falsa.

---

## O que esta feature não é

**Não é avaliação de desempenho.** O `process_antipatterns.yaml` já escreveu a regra, e ela vale
aqui inteira: *"Um antipadrão diz que o registro do processo está incompleto, não que alguém
trabalhou mal."*

A diferença entre um painel que ajuda e um que vigia não está nas métricas — está em **quem vê** e
em **o que a tela afirma quando não sabe**. Esta spec decide a segunda; a primeira é FR-012.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Saber o que está comigo agora (Priority: P1)

Quem abre a própria página vê o que está designado e aberto: quantas issues, em que repositórios,
desde quando.

**Por que é P1**: é a única camada que o dado sustenta por inteiro hoje — 4286 designações
vigentes, todas resolvidas. E é a pergunta que a pessoa faz primeiro.

**Independent Test**: abrir a página de alguém com designações e conferir que a contagem bate com
a listagem, e que cada issue leva ao detalhe dela.

**Cenários de aceitação**

1. **Dado** uma pessoa com issues designadas e abertas, **quando** alguém abre a aba, **então**
   elas aparecem com número, título e repositório.
2. **Dado** que a mesma issue tem duas pessoas designadas, **quando** as duas abas são abertas,
   **então** ela aparece nas duas — designação não é exclusiva, e dividir por dois inventaria
   uma fração que ninguém combinou.
3. **Dado** uma pessoa sem designação alguma, **quando** a aba abre, **então** ela diz "nada
   designado", e **não** um painel de zeros.
4. **Dado** uma designação encerrada, **quando** a aba abre, **então** ela **não** conta — o
   registro fica, e a pergunta é "o que está comigo agora".

---

### User Story 2 - Saber o que a plataforma não olhou (Priority: P1)

Quem lê qualquer número da aba vê, junto, **quanto do trabalho daquela pessoa a plataforma
observou**.

**Por que é P1, e por que empata com a US1**: sem ela, todo número da tela é ambíguo. Medido em
2026-08-15, `vinicius-je` tem 152 designadas e **nenhuma** em repositório com timeline coletada —
uma tela que mostrasse "0 atividades" ali estaria acusando alguém com um número que mede a coleta.

**Independent Test**: abrir a aba de alguém cujas issues estão em repositórios sem timeline e
conferir que a tela diz que não olhou, em vez de mostrar zero.

**Cenários de aceitação**

1. **Dado** uma pessoa cujas issues estão em repositórios sem timeline coletada, **quando** a aba
   abre, **então** ela diz **"não observado"** — e nunca `0`.
2. **Dado** cobertura parcial, **quando** a aba abre, **então** ela mostra a proporção observada,
   e os números derivados são declarados como parciais.
3. **Dado** cobertura completa e nenhuma atividade, **quando** a aba abre, **então** aí sim ela
   mostra zero — e essa é a única situação em que o zero é honesto.
4. **Dado** qualquer número na tela, **quando** ele é exibido, **então** a cobertura está visível
   na mesma tela, e não atrás de um clique.

---

### User Story 3 - Ver a sequência do que a pessoa tocou (Priority: P2)

Quem abre a aba vê as atividades daquela pessoa em ordem, e quando foi a última.

**Por que é P2**: depende da timeline, que hoje cobre 5 de 53 repositórios. Entrega valor onde há
cobertura, e a US2 garante que a ausência dela não vire acusação.

**Independent Test**: uma pessoa com atividades coletadas mostra a sequência; a última data
aparece.

**Cenários de aceitação**

1. **Dado** atividades coletadas, **quando** a aba abre, **então** elas aparecem em ordem
   decrescente — aqui a pergunta é "o que aconteceu por último", ao contrário da página da issue.
2. **Dado** que a última atividade foi há meses, **quando** a aba abre, **então** a data aparece —
   "há 4 meses" e "nunca" pedem ações diferentes.
3. **Dado** um evento de automação, **quando** ele aparece, **então** ele **não** é contado como
   atividade da pessoa: `github-project-automation` fez 204 das 578 movimentações.

---

### User Story 4 - Ver os antipadrões nas issues da pessoa (Priority: P3)

A aba mostra os antipadrões já detectados nas issues designadas àquela pessoa.

**Por que é P3**: a detecção já existe (feature 022) e só precisa ser agregada. É P3 porque é a
que mais se aproxima de julgamento, e por isso vem depois de a US2 estar firme.

**Cenários de aceitação**

1. **Dado** issues com antipadrão, **quando** a aba abre, **então** eles aparecem **com a frase
   que os enquadra** — não é avaliação de pessoa.
2. **Dado** issues sem movimentação coletada, **quando** a aba abre, **então** a seção diz "não
   avaliado", e nunca "nenhum encontrado".

---

### Edge Cases

- **Pessoa sem designação e sem atividade.** Pode ser alguém que saiu, ou que a plataforma
  conhece por outra via. A aba diz isso, e não mostra painel vazio de zeros.
- **A mesma issue designada a três pessoas.** Aparece inteira nas três.
- **Pessoa cujas issues estão todas em repositório excluído da observação.** Excluir é decisão do
  tenant, e a aba distingue isso de "não coletado ainda".
- **Atividade cujo executor é login não resolvido.** 298 atividades têm login sem `person_id`; elas
  não entram no painel de ninguém, e a aba da organização pode dizer quantas ficaram de fora.
- **Pessoa com 152 designadas.** A lista precisa de paginação, e o número precisa ser legível sem
  rolar.

---

## Requirements *(mandatory)*

### O que está com a pessoa

- **FR-001**: A aba MUST listar as issues designadas e abertas da pessoa, com número, título e
  repositório.
- **FR-002**: A contagem exibida MUST bater com a listagem sob qualquer filtro.
- **FR-003**: Designação encerrada MUST NOT contar como trabalho atual.
- **FR-004**: Issue com várias pessoas designadas MUST aparecer inteira para cada uma, e MUST NOT
  ser dividida.

### O que a plataforma não olhou

- **FR-005**: A aba MUST exibir a cobertura da observação — quantas das issues da pessoa estão em
  repositório cuja timeline foi coletada.
- **FR-006**: Onde não há cobertura, a aba MUST dizer **"não observado"**, e MUST NOT exibir `0`.
- **FR-007**: Número derivado de cobertura parcial MUST ser declarado parcial, com a proporção.
- **FR-008**: A cobertura MUST estar visível na mesma tela dos números que ela qualifica.

### A sequência

- **FR-009**: A aba MUST mostrar as atividades da pessoa em ordem decrescente, com a data da
  última.
- **FR-010**: Atividade de automação MUST NOT ser contada como atividade da pessoa.

### Os antipadrões

- **FR-011**: A aba MUST mostrar os antipadrões das issues da pessoa, **com a frase que os
  enquadra como registro incompleto e não como avaliação de pessoa**.

### Quem vê

- **FR-012**: A visibilidade da aba MUST seguir a decisão registrada pela pessoa mantenedora
  em 2026-08-26 — **a própria pessoa, o líder da equipe dela, e o responsável da organização**.

  A regra que vigorava até então era a terceira opção da pergunta original — toda pessoa
  autenticada do tenant vê qualquer outra —, e ela vigorava **por omissão**: o roteador
  exigia `require_user` e nada além. Não estava declarada em lugar nenhum, o que é o
  oposto do princípio de que a semântica vive declarada.

- **FR-012a**: Líder de equipe e responsável de organização MUST vir de papel **declarado**,
  nunca inferido. A plataforma NÃO decide por nome de papel: `Tech Lead` parece liderança e
  `Coordenador` também, e classificar por padrão de nome publicaria a suposição como
  autorização — que é a forma mais cara desse erro, porque o excesso concedido ninguém
  reclama. Medido em 2026-08-26, existem **dois vínculos de papel vigentes, ambos
  `Developer Role`**, e nenhum de liderança.

- **FR-012b**: Enquanto nenhum papel de liderança estiver declarado, a aba MUST ficar
  visível apenas para a própria pessoa, e a tela MUST dizer que ninguém foi declarado
  líder — ausência nomeada, nunca porta aberta silenciosa. Fechar sem dizer faria a
  organização concluir que a plataforma perdeu o dado.

- **FR-012c**: A regra depende de saber **qual pessoa observada é cada pessoa usuária**, e
  esse elo NÃO existe. Medido em 2026-08-26: `eo_people` tem 88 pessoas e **nenhuma com
  e-mail** — o GitHub não entrega —, e a tabela `users` não tem coluna alguma que aponte
  para uma pessoa observada. Nem "cada pessoa vê a si" nem "o líder vê o time" são
  computáveis antes disso.

  O elo MUST ser **declarado**, e MUST NOT ser inferido por login nem por semelhança de
  nome. Identidade adivinhada para conceder visibilidade é o pior lugar em que este
  projeto pode errar: o excesso concedido ninguém reclama, e quem recebeu o painel de
  outra pessoa não abre chamado avisando.

  Enquanto o elo não existir, a aba MUST ficar fechada para todos, com a frase que diz por
  quê — e a frase MUST distinguir "ninguém foi declarado líder" de "não sabemos quem você
  é entre as pessoas observadas", que são bloqueios diferentes e têm remédios diferentes.

### O que a plataforma recusa mostrar

- **FR-013**: A aba MUST NOT exibir throughput, WIP verdadeiro ou cycle time enquanto não houver
  declaração de qual movimentação marca o início do trabalho — é a FR-007 da feature 022, e
  mostrá-los sem ela produziria números plausíveis e errados.
- **FR-014**: A plataforma MUST NOT ordenar pessoas por volume de atividade enquanto a cobertura
  for irregular — o ranking mediria a coleta, e não o trabalho.

---

## Success Criteria *(mandatory)*

- **SC-001**: Numa pessoa com 152 issues designadas e abertas, a aba mostra 152, e a listagem tem
  152 linhas.
- **SC-002**: Numa pessoa cujas issues estão em repositórios sem timeline, a aba **não** exibe o
  número zero em lugar nenhum das seções de atividade.
- **SC-003**: A cobertura aparece na mesma tela dos números que ela qualifica, sem clique.
- **SC-004**: Uma issue designada a três pessoas aparece nas três abas, e a soma das três abas é
  maior que o número de issues — porque designação não é fração.
- **SC-005**: Uma pessoa sem designação alguma vê uma frase, e não um painel de zeros.
- **SC-006**: A aba não exibe throughput nem cycle time, e diz qual decisão falta para que eles
  existam.
- **SC-007**: A atividade de `github-project-automation` não aparece na aba de pessoa nenhuma.

---

## Assumptions

- **A aba vive na página da pessoa**, e não em rota nova: é a mesma entidade, e o princípio X pede
  que a tela responda uma pergunta — aqui, "o que se sabe desta pessoa".
- **O nome da aba é "Trabalho"**, e não "Métricas": a primeira convida a olhar o que a pessoa faz;
  a segunda convida a comparar pessoas. É decisão de desenho, e está aberta a revisão.
- **A cobertura é medida por repositório**, e não por issue: a timeline vem junto da issue, então
  um repositório percorrido depois da feature 022 tem timeline de todas as issues dele.
- **Antipadrão agregado é leitura**, e nada é gravado — a detecção da 022 é consumidora, e esta
  também.

## Fora do escopo

**Adiado por decisão da pessoa mantenedora em 2026-08-15** — *"vamos deixar as métricas para
depois"*. O que segue fica registrado para não ser reproposto sem a medida junto.

- **Cycle time, por qualquer definição testada.** Duas foram medidas contra o dado real, e **as
  duas colapsam no lead time**:

  | Início proposto | Issues com começo e fim | O que a medida achou |
  |---|---:|---|
  | entrar em estado de andamento | 18 | 11 entraram no mesmo dia da criação; espera mediana **0,2 dia** |
  | ser designada a alguém | 23 | quase todas idênticas ao lead — #21 `51/51`, #52 `34/34`, #72 `7/7` |

  O bloqueio **não é a declaração da regra**: é que tanto a movimentação quanto a designação
  acontecem no nascimento da issue. Declarar qualquer uma produziria um número com aparência de
  precisão e igual ao que já existe — e alguém decidiria sobre uma diferença inexistente.

  E `issue_assignees` guarda apenas `inserted_at`, que é **quando a plataforma viu**, não quando a
  designação aconteceu. Usá-lo como data de início seria proveniência trocada por conveniência.

  **O que destrava**: mover o cartão quando o trabalho começa. É disciplina de quadro, e é
  exatamente o que o `ap01` e o `ap03` já medem — os antipadrões são o caminho para a métrica, e
  não um recurso paralelo.

- **Diagrama de fluxo cumulativo.** Removido do escopo por decisão da mesma conversa. É artefato de
  **sistema**, e não de pessoa: mostra como o trabalho flui por um quadro, e um CFD individual
  mistura o fluxo da pessoa com o do time sem separar nenhum dos dois. Se voltar, volta em tela de
  quadro.

- **Throughput como ranking, burndown, burnup e Monte Carlo.** Com 5 meses de timeline e cobertura
  de 5 repositórios em 53, o intervalo de confiança seria largo demais para decidir qualquer
  coisa.
- **Comparar pessoas.** Nem ranking, nem média do time, nem percentil. Enquanto a cobertura for
  irregular, comparar mede a coleta.
- **Declarar qual movimentação marca o início.** É feature própria, e é ela que desbloqueia o
  parágrafo acima.
- **Painel de organização.** Esta feature é sobre uma pessoa; agregar o time é outra pergunta.
