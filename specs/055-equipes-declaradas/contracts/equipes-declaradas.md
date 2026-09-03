# Contrato — declarar equipes, vínculos e composição

**Feature**: [055](../spec.md) · **Requisitos**: FR-001 a FR-012

Descreve o comportamento observável. Nomes de função e de tabela são detalhe de
implementação; o que está aqui, não.

## As cinco operações

| operação | o que passa a ser verdade |
|---|---|
| **declarar equipe** | existe uma equipe que a coleta não viu, com quem a declarou |
| **vincular pessoa** | a pessoa faz parte da equipe, com papel, a partir de uma data |
| **registrar saída** | a pessoa **fez** parte, e não faz mais. O período anterior continua valendo |
| **registrar equívoco** | a pessoa **nunca** fez parte. O vínculo não vale para período algum |
| **compor / descompor** | uma equipe faz parte de outra, desde quando, por quem |

## Os invariantes

| # | invariante | por que existe |
|---|---|---|
| C1 | Toda operação grava **quem declarou** e **quando** | sem autor, a declaração é anônima e ninguém pode ser perguntado depois |
| C2 | **Nenhuma linha é removida.** Desfazer é sempre acrescentar um fato | o SC-003: uma linha apagada muda todos os números de todos os períodos |
| C3 | Registrar saída **não altera** nenhum número anterior à data de saída | é a diferença entre sair e ser apagado |
| C4 | Registrar equívoco tira o vínculo de **todos** os períodos, e mantém o registro | engano e saída são fatos diferentes sobre a organização |
| C5 | Uma pessoa tem **no máximo um** vínculo vigente por equipe | dois vigentes tornam a contagem ambígua |
| C6 | A composição **não fecha ciclo**, por caminho de qualquer comprimento | ciclo faz qualquer agregação pela hierarquia não terminar |
| C7 | Toda consulta recebe o tenant | `AGENTS.md`: consulta sem tenant não é bug de correção, é de segurança |
| C8 | Só quem administra declara | as demais pessoas leem |

**Vigente** significa, a partir desta feature: **sem fim registrado E sem
invalidação**. As duas condições, sempre juntas.

## O que o contrato NÃO promete

- **Não corrige a origem.** Se o GitHub continua listando alguém que a organização
  diz ter saído, a plataforma **mostra as duas afirmações** (FR-012). Não escolhe,
  não silencia, e não avisa o GitHub;
- **Não valida a data informada.** Uma saída com data no passado distante é
  aceita — quem declara sabe mais que a plataforma. Data no **futuro** é outra
  coisa, e o comportamento precisa ser decidido no plano de tarefas;
- **Não soma competências pela hierarquia.** É a issue #397, e depende desta
  feature. Fora de escopo, declarado;
- **Não impede equipe declarada homônima de observada.** A organização pode ter
  um time interno com o mesmo nome; a tela distingue pela origem, não pelo nome.

## As recusas, e o que cada uma diz

Toda recusa é relator — `{:error, motivo}` — e nomeia o que aconteceu:

| tentativa | recusa |
|---|---|
| vincular quem já tem vínculo vigente ali | diz que já existe, e desde quando |
| compor fechando ciclo | diz **qual caminho** fecharia o ciclo, não só que fecha |
| declarar equipe com nome já usado no mesmo escopo | diz qual equipe já usa |
| qualquer operação sem ser quem administra | recusa sem revelar o que existe |

A segunda linha é a que importa: *"fecharia ciclo"* manda a pessoa procurar; *"A
faz parte de B, que faz parte de C"* resolve.
