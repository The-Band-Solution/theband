# Feature 038 — Três menus para alcançar o rastro

**Criada**: 2026-08-19 · **Issue**: [#436](https://github.com/The-Band-Solution/theband/issues/436)
**Origem**: pergunta da pessoa mantenedora — *"aonde estão as telas de commits, pr e ci?"*
**Depende de**: as telas, que já existem (features 033, 035 e 037)

## O propósito

Esta feature não constrói tela nenhuma. Constrói **caminho** até telas que já funcionam e
que ninguém encontra.

A pergunta que a originou é a evidência: quem mantém o projeto, e escreveu as próprias
telas, não sabia dizer onde elas estavam. Se essa pessoa não acha, ninguém acha.

## O que o dado real diz do tamanho do problema

Medido no banco em 2026-08-19:

| coleta | volume | alcançável por menu? |
|---|---:|---|
| issues | 5.089 | **sim** |
| solicitações de mudança | 5.035 | não |
| commits | 16.416 | não |
| versões de arquivo | 87.719 em 17.127 caminhos | não |
| execuções de verificação | 1.051 | não |

Quatro das cinco coletas são inalcançáveis. **Dado coletado que ninguém encontra é dado
que não existe para quem usa** — e o custo já está pago: a coleta rodou, o banco encheu, e
a plataforma se comporta como se não tivesse nada.

## User scenarios

### US1 — Encontrar o que mudou (P1)

Como pessoa que administra o tenant, quero **chegar às solicitações de mudança pelo menu**,
para responder "o que está aberto há mais tempo?" sem conhecer a URL.

**Critérios de aceitação**

- AC1: a barra principal tem um item `Changes` que navega para `/work/changes`
- AC2: o item aparece para qualquer pessoa autenticada com tenant, não só admin
- AC3: o item fica **depois** de `Work` e **antes** de `Projects`

### US2 — Encontrar quem mexeu num arquivo (P1)

Como pessoa que administra o tenant, quero **chegar à navegação de arquivos pelo menu**,
para perguntar "quem mexeu neste arquivo?" sem partir de um commit.

**Critérios de aceitação**

- AC1: a barra tem um item `Files` que navega para `/work/files`
- AC2: fica imediatamente depois de `Changes`

### US3 — Encontrar o que a máquina disse (P1)

Como pessoa que administra o tenant, quero **chegar à verificação contínua pelo menu**.

**Critérios de aceitação**

- AC1: a barra tem um item `Checks` que navega para `/work/verifications`
- AC2: o rótulo é `Checks`, **nunca** `CI`
- AC3: fica imediatamente depois de `Files`

### US4 — Não quebrar no telefone (P1)

Como pessoa que usa a plataforma no telefone, quero que a barra continue utilizável com os
três itens novos.

**Critérios de aceitação**

- AC1: em 390px o documento não excede a largura da janela
- AC2: a barra rola horizontalmente, como já rolava

## As duas decisões de nome, e por que ficam na spec

### `Checks`, e não `CI`

Medido em 2026-08-19 nas 1.051 execuções coletadas:

| o que é | execuções |
|---|---:|
| integração **e** implantação | 515 |
| **nem uma nem outra** | 399 |
| só implantação | 107 |
| só integração | 30 |

Um menu chamado `CI` afirmaria que as 1.051 são integração contínua. **399 são
espelhamento para o GitLab, virada de sprint e automação de quadro** — rotular a tela de CI
seria a mesma família de erro que o mapeamento cometeu e o dado desmentiu (lição L61).

`Pipelines` foi descartado por outro motivo: é vocabulário de ferramenta, e a rede fala em
processo. O menu carregaria uma palavra que nenhuma ontologia usa.

### Três menus, e não uma aba com quatro sub-abas

A alternativa considerada era um menu `Trail` com abas para solicitações, commits, arquivos
e verificação — 11 itens na barra em vez de 13.

Descartada pelo **princípio X da constituição**: tela faz uma coisa só. As quatro são
leituras de conceitos diferentes — `cmpo.change_request` é objeto social,
`cmpo.commit_artifact_copy` é ato, `cmpo.artifact_copy` é cópia de artefato,
`ciro.continuous_integration_process` é processo. Empilhá-las sob um rótulo faria a
plataforma sugerir que são a mesma coisa vista de ângulos diferentes.

E a aba esconde o custo de busca: quem procura "arquivo" precisaria saber antes que arquivo
mora dentro de "rastro". Treze itens numa barra que já rola custam menos que uma pessoa não
encontrar.

## A ordem, e por que ela não é arbitrária

A barra já ordenava do agente para o trabalho — quem, com quem, sobre o quê. Os três novos
continuam a mesma frase, e é por isso que entram no meio e não no fim:

```
People → Teams → Work → Changes → Files → Checks → Projects → Boards → Process
 quem    com quem  o quê   o que    o que    o que
                         respondeu  tocou   a máquina disse
```

Pôr os três no fim, depois de `Process`, os separaria do trabalho que eles descrevem — e a
ordem deixaria de contar nada.

## Fora do escopo

- **Nova tela.** Nenhuma. Todas as três existem.
- **Menu para commits.** `/people/:id/commits` é por pessoa e não tem lista global; um item
  de barra apontaria para lugar nenhum. Os commits são alcançados por `Changes` e por
  `Files`, que é onde a pergunta por commit nasce.
- **Reorganizar os itens de operação** (`Syncs`, `Tools`, `AI`, `Profiles`). Já foram
  reorganizados na feature 034.

## Limitação declarada

`Checks` leva a uma tela que hoje mostra **4 dos 160 repositórios observados** — a coleta do
CI não terminou. A tela já distingue "não coletado" de "sem verificação contínua"; o menu
não acrescenta nem esconde nada disso.
