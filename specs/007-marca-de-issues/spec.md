# Feature Specification: A marca de trabalho no repositório

**Feature**: `007-marca-de-issues` · **Criada em**: 2026-08-12
**Estado**: rascunho, pronta para `/speckit-plan`

## Pedido

> "Crie um símbolo nos repositórios que possuem issues. Ao clicar nesses repositórios, lista as
> issues."
>
> — pessoa mantenedora, 2026-08-12

**O escopo é o pedido.** Uma marca que diz se o repositório tem trabalho coletado, e o clique
que leva às issues. A primeira versão desta spec inventou quatro estados para a marca; a pessoa
mantenedora recusou, e com razão — a tabela **já** tem uma coluna `state` dizendo `observed`,
`unreachable`, `excluded` e `archived`. A marca não precisa repetir o que está ao lado.

---

## O que existe hoje, e o que falta

A navegação pedida **já existe**: em `/work` o nome do repositório é link para
`/work/repositories/:id`, e a coluna `issues` mostra a contagem.

O que falta é a **distinção visível**. Medido nos 135 repositórios observados:

| | quantos |
|---|---:|
| com issues coletadas | **36** |
| sem issues coletadas | **99** |

**73% das linhas não têm trabalho a mostrar**, e descobrir isso hoje exige ler 135 números.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Achar onde há trabalho, sem ler número (Priority: P1)

Quem administra abre `/work` numa organização de 121 repositórios e precisa saber, de relance,
quais têm trabalho coletado.

**Teste independente**: com 36 repositórios com issues e 99 sem, a marca distingue os dois grupos
sem que ninguém leia a coluna de contagem.

**Cenários de aceitação**

1. **Dado** um repositório com 194 issues coletadas, **quando** a lista é exibida, **então** a
   marca aparece cheia, com texto dizendo que há trabalho.
2. **Dado** um repositório sem nenhuma issue, **quando** a lista é exibida, **então** a marca
   aparece vazia, com texto dizendo que não há.
3. **Dado** que a pessoa usa leitor de tela, **quando** percorre a lista, **então** cada marca é
   anunciada por extenso.
4. **Dado** que a pessoa não distingue cores, **quando** vê a lista, **então** os dois estados
   continuam distinguíveis pela forma e pelo texto.
5. **Dado** o telefone, **quando** a lista vira cartões, **então** a marca continua legível.

---

### User Story 2 - Ir do repositório para as issues dele (Priority: P1)

Quem vê a marca clica no repositório e chega às issues dele.

**Teste independente**: clicar em qualquer repositório abre a tela dele, com issues ou com a
explicação de por que não há.

**Cenários de aceitação**

1. **Dado** um repositório com issues, **quando** a pessoa clica no nome, **então** a tela dele
   lista as issues.
2. **Dado** um repositório **sem** issues, **quando** a pessoa clica no nome, **então** a tela
   abre e explica por que está vazio — é o que alguém procura ao clicar num vazio.
3. **Dado** o telefone, **quando** a pessoa toca no nome, **então** o alvo de toque é suficiente.

---

### Edge Cases

1. **Repositório cujas issues foram todas marcadas como não mais observadas** — houve trabalho e
   ele não está vigente. A marca resume qual dos dois?
2. **Repositório nunca submetido a coleta de issues** — a contagem é desconhecida, e desconhecido
   não é zero.
3. **Organização inteira sem trabalho coletado** — 61 dos 135 são vazios; uma organização pode
   ser inteiramente vazia.
4. **Contagem que muda enquanto a tela está aberta**, porque uma coleta está em andamento.
5. **135 repositórios na coluna estreita do telefone.**

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A lista de repositórios em `/work` DEVE exibir, para cada repositório, uma marca
  que distingue **tem trabalho coletado** de **não tem**.
- **FR-002**: A marca DEVE distinguir os dois estados por **forma e texto**, e NÃO apenas por
  cor — os dois permanecem distinguíveis em monocromático.
- **FR-003**: Cada marca DEVE ter rótulo acessível a leitor de tela dizendo o estado por
  extenso.
- **FR-004**: A marca NÃO DEVE repetir o que a coluna `state` já diz sobre observação —
  `unreachable`, `excluded` e `archived` continuam onde estão.
- **FR-005**: Repositório com contagem **desconhecida** — nunca submetido a coleta de issues —
  NÃO DEVE aparecer como tendo zero: a marca e o texto dizem que não se sabe.
- **FR-006**: A marca DEVE funcionar na tabela e no cartão do telefone.
- **FR-007**: Todo repositório da lista DEVE continuar navegável, **inclusive os sem trabalho** —
  a tela deles explica por que estão vazios.
- **FR-008**: Clicar no repositório DEVE abrir a tela dele sem consultar a origem.
- **FR-009**: O alvo de toque do link DEVE atender ao mínimo de acessibilidade no telefone.
- **FR-010**: A contagem que a marca resume DEVE vir da **mesma** fonte que a coluna de
  contagem: um número, dois consumidores.
- **FR-011**: Desenhar a lista NÃO DEVE aumentar o número de consultas que a tela faz hoje.
- **FR-012**: Nenhuma tela DEVE exibir repositório de outro tenant, e a consulta a repositório de
  outro tenant DEVE responder **não encontrado**, nunca "sem permissão".
- **FR-013**: O escopo é a tela `/work`. A tela de sincronização **NÃO** recebe a marca: lá o
  repositório aparece como fase de execução, e a pergunta é outra.

### Key Entities

- **Contagem de issues por repositório**: já existe na tela. Passa a ter dois consumidores — a
  coluna e a marca.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Numa organização de 121 repositórios, é possível identificar os que têm trabalho
  coletado **sem ler nenhum número**.
- **SC-002**: Os dois estados permanecem distinguíveis com a cor removida.
- **SC-003**: Cada marca é anunciada por leitor de tela com o estado por extenso.
- **SC-004**: Nenhum repositório com contagem desconhecida aparece como zero.
- **SC-005**: Todos os 135 repositórios continuam navegáveis.
- **SC-006**: Desenhar a lista faz o mesmo número de consultas que hoje, ou menos.
- **SC-007**: A marca é legível e o link é tocável em largura de 360 px.
- **SC-008**: Um tenant não alcança repositório de outro, e a mensagem não confirma existência.
- **SC-009**: A tela de sincronização permanece sem a marca.

---

## Assumptions

- **A marca resume issues vigentes.** Repositório cujas issues foram todas marcadas como não
  mais observadas aparece **sem trabalho vigente**, e o texto diz isso em vez de "vazio" — houve
  trabalho, e ele não está presente.
- **A marca não é conceito da ontologia.** É estado derivado de exibição, calculado na leitura e
  nunca gravado — como a classificação épico/atômica.
- **O estado de observação continua na coluna que já o mostra.** A marca responde uma pergunta
  só: *há trabalho aqui?*
- **A tela do repositório não muda.** Ela já lista as issues e já distingue os três vazios; a
  feature garante que continue alcançável.

## Dependencies

- Feature 006 — a tela do repositório com as issues dele. Sem ela não há para onde o clique ir.
- O design system em `docs/design-system.md` — a marca é uma aplicação da gramática da evidência,
  e as regras de forma, texto e rótulo acessível vêm de lá.

## Out of Scope

| Fora | Por quê |
|---|---|
| a marca dizer o estado de observação | a coluna `state` já diz (FR-004) |
| marca na tela de sincronização | lá o repositório é fase de execução (FR-013) |
| ordenar ou filtrar a lista | não foi pedido; a marca resolve o problema de varredura |
| marca por conceito — "tem épicos", "tem defeitos" | a tela do repositório já mostra por conceito |
| escolher quais repositórios observar | é a issue #108, no product backlog |
