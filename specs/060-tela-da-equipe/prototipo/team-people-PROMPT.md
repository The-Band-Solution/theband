# O prompt do protótipo da aba *Flow per person*

Registro fiel do que produziu `team-people.html`, publicado em
`https://claude.ai/code/artifact/a8c7e08c-e9df-4a28-94ea-0800087f9751` em 2026-09-08.

**Endereço novo, protótipo novo, aprovação nova.** Este não é uma republicação de
`team-dashboard-structure.html` (`.../0be1668f-3afa-4668-bfb2-c77fae11d941`): é uma **terceira
tela** da mesma feature, na mesma linguagem visual, e ela **não altera** o protótipo aprovado
em 2026-09-07 — as duas abas de lá continuam exatamente como estão. Toda mudança nesta tela é
republicação **neste** endereço.

**Status: aguardando aprovação.** Enquanto não houver aprovação, a extensão
`spec-graficos-por-membro.md` não vai a `/speckit-plan`.

## 1. Os pedidos da pessoa mantenedora, textuais e em ordem

1. *"Especifique colocar na tela da equipe para cada membro os gráficos: Working in progress,
   prometido x realizado, throughput e monte carlo."* (2026-09-08 — produziu a spec
   `spec-graficos-por-membro.md`, escrita pelo papel de Product Owner)
2. *"faça um protótipo com as métricas de cada membro da equipe na página da equipe"*
   (2026-09-08 — produziu este protótipo)

Nenhuma decisão foi tomada pela pessoa mantenedora sobre esta tela ainda. As sete perguntas
abertas da spec continuam abertas, e o protótipo acrescenta as suas — todas na seção
*Decisions and open questions* da própria tela, itens 18 a 24.

## 2. O brief de design que o agente seguiu

- **Design system herdado, não reinventado**: os tokens de `assets/css/app.css` e do protótipo
  aprovado — papel `#f7f8f7`/`#0e1413`, tinta, **verdete** `#1f6f68`/`#5cbcb2` como primária,
  `info` azul para o declarado, `amber` para derivado e aviso, `clay` para equívoco e gravidade,
  `s1`/`s2`/`s3` para subequipe. Corpo em serif, títulos em grotesk, números e rótulos em mono
  com `tabular-nums`. Dois temas por tokens, com `[data-theme]` e `prefers-color-scheme`.
- **Marcas** com forma e cor, distinguíveis em escala de cinza: `declared`, `observed`,
  `derived`, `absent`, `left`, `mistake`; e a marca do conceito (`TASK`/`US`/`BUG`/`EPIC`/`—`)
  na família de forma, herdada de `marca-do-conceito.md`.
- **Regras da casa obedecidas**: nenhum total (057 FR-008/FR-009); ausência escrita, nunca zero
  (057 FR-012, FR-021, 060 SC-026); nenhuma tarefa eleita como atual (057 FR-018); recusa como
  estado de primeira classe; toda medida com a composição sobre a qual foi calculada (ADR 0008);
  nada é apagado — a saída tem data e autor; comparação em números alinhados, sem gráfico na
  linha (057 FR-011, mantida por 060 FR-058).
- **Copy em inglês**, dizendo o que a tela faz **e o que não faz**.
- **Dado real medido na base de desenvolvimento em 2026-09-08**: itens abertos de quem está em
  equipe — 760 TASK · 288 US · 71 BUG · 35 EPIC (1 154); SQUAD PINK, 5 pessoas — 180 · 78 · 21 ·
  18 (297), com 114, 77 e 54 abertos em três pessoas; Equipe IA, 7 pessoas — 67 TASK · 15 US ·
  1 BUG (83), com 11, 3 e **0** abertos em três pessoas; o item aberto mais novo amostrado tem
  217 dias e há de 550. **Nenhum fechamento foi medido** — ver a seção *What was not verified*
  na própria tela.
- **Mostrado em repouso**: os blocos de gráfico aparecem abertos; nada depende de clique.

## 3. A estrutura aprovada, seção por seção — a régua do QA

> Enquanto a aprovação não vier, leia "aprovada" como "proposta". Aprovada a tela, é **contra
> esta seção** que o QA confere a implementação, item a item.

### 3.1 A aba

- Terceira aba de `/teams/:id`, valor `people` no mesmo parâmetro da FR-001, **sem rota nova**.
- Rótulo **“Flow per person”** — nomeia o que responde, não "métricas".
- Apresentada apenas a quem alcança a equipe (058 FR-024); recusa com motivo nomeado.

### 3.2 Cabeçalho da seção

1. Título **Flow per person**, com `N members · <janela> · by <granulação>`.
2. **Um único** controle de granulação `week · month · year`, no cabeçalho da seção — e **não**
   no cabeçalho de cada gráfico, como no Dashboard. Reescreve o endereço e reagrupa todas as
   linhas ao mesmo tempo. Cada gráfico continua nomeando a janela no próprio título.

### 3.3 *Read this before the numbers* — dois blocos, acima da tabela, sem colapsar

3. **Bloco clay — “A table of work items, not a table of people.”** Traz, em palavras: item com
   dois responsáveis conta uma vez para cada e nenhuma coluna soma a equipe; as linhas não
   compartilham denominador; o maior número da tela (*open now*) é trabalho que **não** se moveu;
   a ordem é papel declarado e depois nome; **nenhuma coluna de medida ordena** e nenhuma se
   oferece para ordenar; **nenhuma média ou taxa por pessoa** é apresentada em lugar nenhum.
4. **Bloco amber — “‘Working in progress’ here is not `flow.wip.count`.”** A fórmula declarada
   exige começo e fim da tarefa executada e **o critério de fim não existe** (issue #506); o que
   se computa é `external_created_at` presente e `external_closed_at` nulo no instante amostrado;
   o relógio começa quando o **item** foi aberto, não quando a pessoa o assumiu; **não há limite
   de WIP** em lugar nenhum. E as más leituras que a medida declara, **copiadas**: WIP baixo não
   é fluxo saudável, WIP alto não é produtividade, comparar sem normalizar vira outra medida.

### 3.4 A contagem da previsão (FR-100)

5. Linha `Delivery forecast produced for N of M people in this window`, **acima da tabela**,
   presente inclusive quando N = 0 e quando N = M, com a frase de que o piso é do método.

### 3.5 A tabela — seis colunas, uma linha por membro, nenhum gráfico

6. `person · role · collection` — nome, login, papel declarado ou *role not declared*, desde
   quando (ou *start date unknown*), marca `left <data>` com autor quando houver saída, e a
   **cobertura da coleta** como `N repos observed · denominator unknown`.
7. `open now · and the change across the window` — valor no último instante amostrado e a
   variação entre a primeira e a última amostra, em palavras (*no change across the 8 samples*,
   *9 at the first sample · +2 across the window*). Sub-linha `— n the routing rule did not
   classify` quando houver item não classificado.
8. `opened in the window` — ausência escrita: `none opened`.
9. `closed in the window` — ausência escrita: `none closed`.
10. `weeks with a close` — `n of 8`, com o denominador reduzido para quem entrou dentro da janela
    (`2 of 3`) ou saiu (`3 of 5`).
11. `delivery forecast · 12 weeks · weekly` — **coluna de estado, não de valor**, com fundo
    hachurado leve, em três estados: (a) `p50 n wk · no p85` + a proporção que nunca zerou;
    (b) `no forecast · below the floor` + **os quatro números** `history a of 6 met · closed b of
    10 short`, com as palavras *met* e *short* carregando a diferença; (c) `nothing to forecast`
    para quem não tem item aberto — o piso **não** é a razão ali.
12. Ação por linha: `charts ▾` / `close ▴`.
13. Abaixo da tabela, a linha da ordem: papel declarado, depois nome; **nenhuma coluna ordena**.
14. Ao lado da tabela, a não-comparabilidade (FR-112) e o que a tabela diz e não diz da equipe.

### 3.6 O bloco de **uma** pessoa aberta — em duas por duas, no lugar

15. Abre **sob a própria linha**, com faixa verdete à esquerda; cabeçalho com o nome, a janela e
    o caminho para `/people/:id`.
16. As duas definições, **dentro do bloco**: *promised = opened in the period; delivered = closed
    in the period*, sem escopo comprometido, fechado é ato da ferramenta, a contagem ignora o
    tamanho do item; e a substituição do WIP.
17. A **mistura de conceitos** do número (`TASK n · US n · BUG n · EPIC n`) — a composição, e
    **nunca** a lista de tarefas, que é do Dashboard (FR-088).
18. Quatro gráficos numerados **1 → 4**, e os números são a ordem de leitura: *1* o que está lá,
    *2* o que entrou e saiu, *3* a que ritmo, *4* o que o ritmo implica. Os três primeiros
    observados; o quarto **derivado**, com o cartão tracejado.
19. **Gráfico vazio é desenhado, nunca deixado em branco**: eixos, escala e a frase na própria
    área de plotagem, sobre fundo tracejado.
20. A recusa da previsão traz os quatro números, a frase *gap in the observed record, never a
    statement about the person*, a proibição de emprestar a história da equipe (FR-101) e o
    enquadramento da pergunta sobre **o trabalho** (FR-103).

### 3.7 O bloco de **duas** pessoas — quatro linhas de duas colunas, abaixo da tabela

21. Abrir a segunda pessoa **tira as duas das linhas** e monta uma linha por medida, duas
    colunas. As duas linhas da tabela ficam marcadas.
22. Cada gráfico mantém a **sua** escala, rotulada, e a linha diz que os eixos diferem: *as
    formas comparam, as alturas não*.
23. Na linha 3, a frase de que **nenhuma média e nenhuma mediana por pessoa** é desenhada, e que
    aquelas barras são as barras *delivered* da linha 2 lidas como ritmo.
24. Teto: **duas** pessoas. A razão está escrita na própria tela.

### 3.8 *The three absences, and they are not the same absence*

25. Três cartões, cada um com o **tratamento renderizado**: (1) nada observado para a pessoa —
    tracejado, a linha permanece na tabela, e a distinção explícita para o caso vizinho de quem
    tem itens mas nenhum aberto agora; (2) abaixo do piso — os quatro números, e os **dois**
    modos de bloqueio (*closed short* e *history short*) mostrados lado a lado; (3) o item que a
    regra não classificou — `—` tracejado, junto da contagem de que faz parte, nunca em rodapé.

### 3.9 *Decisions and open questions*

26. Quatro cartões: o que vem decidido de 7 e 8 de setembro (1–6); o que **o desenho** decidiu,
    com a razão, reversível pela pessoa mantenedora (7–17); o que está **aberto** (18–24), cada
    um com opções e recomendação; e **o que não foi verificado** — escrito na tela, não só no
    relatório.

## 4. Como usar este arquivo

- O **Design** parte daqui para qualquer mudança nesta aba e republica **no mesmo endereço**.
- O **Product Owner** cita o endereço, este prompt e `team-people-README.md` no item do backlog
  e na spec, leva as perguntas 18 a 24 à pessoa mantenedora, e só aceita a entrega conferida
  contra a seção 3.
- O **QA** confere a tela entregue contra a seção 3, item a item: existe, na ordem, com o texto,
  com a marca, com a ação e com a recusa. Divergência é defeito.
