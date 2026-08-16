# Feature 029 — As competências da equipe, e a evolução delas

**Criada**: 2026-08-16 · **Origem**: pedido da pessoa mantenedora, com proposta aprovada
(artefato "Competências da Equipe") · **Estende**: 026/027 (perfis) e a tela de equipe

## O propósito

Os perfis individuais já dizem o que cada pessoa demonstrou. Falta a leitura que nenhum
currículo dá: **em que esta equipe é forte, onde a evidência é rala, e como isso mudou
entre gerações de perfil** — tudo calculado dos perfis que já existem, sem uma chamada
nova a modelo.

## User story

**US1 (P1)** — Como quem coordena, ao abrir uma equipe quero ver a cobertura de
competências (barras), quem demonstra o quê (matriz com contagens de tarefas-evidência),
um resumo calculado e a evolução por geração — para decidir alocação e risco com
evidência, não com impressão.

## As cinco decisões (da proposta aprovada)

1. Competência da equipe = **agregação calculada** dos perfis vigentes — nunca um segundo
   texto de modelo (empilharia derivação sobre derivação);
2. Membro = evidência declarada na origem + equipe declarada; o critério aparece na tela
   (papel organizacional segue #99/#100);
3. Evolução = recontar a cobertura com os perfis **vigentes em cada mês que teve
   geração** — a pergunta que a tabela somente-acréscimo existe para responder;
4. Membro sem perfil é **nomeado, nunca zero** — a cobertura é piso, não teto;
5. Tudo é **derivado de derivado** — hachura e frase no topo; a contagem é exata, o que
   ela conta é derivado.

## Functional requirements

- **FR-001**: A aba MUST agregar apenas perfis **vigentes** de membros pela evidência
  declarada (+ equipes declaradas); o critério de membro MUST aparecer na tela.
- **FR-002**: Toda contagem MUST ser calculada das estruturas dos perfis (`destaques`:
  domínio + tarefas). Nenhuma chamada a modelo nesta aba. O número da célula é
  **tarefas concluídas que evidenciam a competência** — entrega, nunca promessa.
- **FR-003**: A evolução MUST comparar gerações: cobertura recontada com os perfis
  vigentes no fim de cada mês que teve geração de algum membro. Mês sem geração não
  aparece — nunca interpolado.
- **FR-004**: Membro sem perfil MUST ser contado e nomeado, nunca somado como zero.
  A frase MUST dizer que a cobertura é piso.
- **FR-005**: A aba inteira MUST ser marcada derivada — hachura e rótulo em texto.
- **FR-006**: Competência que sai da série entre gerações MUST aparecer como *evidência
  não renovada* — MUST NOT dizer "regrediu" ou "abandonou".
- **FR-006a**: A matriz pessoas×competências MUST listar quem demonstra o quê com a
  contagem, cada pessoa linkando ao perfil — e MUST NOT ordenar pessoas por total nem
  produzir ranking. Pessoas em ordem alfabética; competências por cobertura.
- **FR-007**: O resumo MUST ser montado das contagens (forte em, ponto único de falha,
  evidência nova no período) — frases calculadas, nunca texto de modelo.

## Success criteria

- **SC-001**: a aba faz número fixo de consultas (≤ 4), independente do nº de membros —
  provado pelo contador único de consultas.
- **SC-002**: para cada competência, o nº exibido = pessoas distintas com ela no perfil
  vigente — verificado por teste contra o banco.
- **SC-003**: com um membro sem perfil, a tela o nomeia e nenhuma contagem o trata como
  zero.
- **SC-004**: a evolução de uma competência que aparece pela primeira vez no mês M mostra
  0 antes de M apenas nos meses com geração, e "nova" na tendência.

## Fora de escopo, e dito

Texto de modelo sobre a equipe (espera #363); comparação entre equipes; membership por
papel (#99/#100); filtro por período além dos meses com geração.
