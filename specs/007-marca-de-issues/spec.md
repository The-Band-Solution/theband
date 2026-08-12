# Feature Specification: A marca de trabalho no repositório

**Feature**: `007-marca-de-issues` · **Criada em**: 2026-08-12
**Estado**: rascunho, pronta para `/speckit-plan`

## Pedido

> "Crie um símbolo nos repositórios que possuem issues. Ao clicar nesses repositórios, lista as
> issues."
>
> — pessoa mantenedora, 2026-08-12

---

## O que existe hoje, e o que falta

A navegação pedida **já existe**: em `/work` o nome do repositório é link para
`/work/repositories/:id`, e a coluna `issues` mostra a contagem.

O que não existe é a **distinção visível**. Medido agora, nos 135 repositórios observados:

| estado do repositório | quantos | issues neles |
|---|---:|---:|
| tem issues coletadas | **36** | 3 577 |
| coletado e vazio | **61** | 0 |
| inacessível na última coleta | **38** | 897 |

**73% das linhas não têm trabalho a mostrar**, e quem varre a lista precisa ler a coluna de
número para descobrir isso. Numa organização de 121 repositórios, isso é ler 121 números.

### O achado que muda o pedido

Os 38 inacessíveis **têm 897 issues coletadas** e não estão vazios. Um símbolo binário —
"tem" contra "não tem" — colocaria esses 38 do lado errado dos dois: eles têm trabalho **e** a
plataforma não os está olhando.

E "coletado e vazio" não é o mesmo que "nunca coletado". Um repositório recém-observado tem
contagem **desconhecida**, não zero. O design system é explícito: ausência é nomeada, nunca
desenhada como quantidade.

Por isso a marca carrega **quatro estados**, e não dois.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Achar onde há trabalho, sem ler número (Priority: P1)

Quem administra abre `/work` numa organização de 121 repositórios e precisa saber, **de
relance**, quais têm trabalho coletado.

**Por que é P1**: é o pedido literal, e é o que 73% de linhas sem trabalho tornam necessário.

**Teste independente**: com 36 repositórios com issues e 99 sem, a marca distingue os dois
grupos sem que ninguém leia a coluna de contagem.

**Cenários de aceitação**

1. **Dado** um repositório com 194 issues coletadas, **quando** a lista é exibida, **então** a
   marca aparece cheia, com texto dizendo que há trabalho, e a contagem ao lado.
2. **Dado** um repositório coletado e sem nenhuma issue, **quando** a lista é exibida, **então**
   a marca aparece vazia e o texto diz **"collected, no issues"** — não "0".
3. **Dado** um repositório que nunca teve coleta de issues, **quando** a lista é exibida,
   **então** o texto diz **"not collected yet"**, e a contagem **não** aparece como zero.
4. **Dado** que a pessoa usa leitor de tela, **quando** percorre a lista, **então** cada marca
   é anunciada com o estado por extenso.
5. **Dado** que a pessoa não distingue cores, **quando** vê a lista, **então** os quatro estados
   continuam distinguíveis pela forma e pelo texto.

---

### User Story 2 - Enxergar o repositório que tem trabalho e não está sendo olhado (Priority: P1)

Quem administra precisa notar os 38 repositórios que **têm** issues e estão inacessíveis — o
trabalho existe no banco e a plataforma parou de alcançá-lo.

**Por que é P1**: é o estado que um símbolo binário apagaria, e ele esconde 897 issues. Já
custou caro: 38 repositórios ficaram fora de toda coleta por uma falha de rede momentânea, e a
tela dizia "concluída · 100%".

**Teste independente**: com repositórios inacessíveis que têm issues, a marca os distingue tanto
dos que têm e estão sendo olhados quanto dos vazios.

**Cenários de aceitação**

1. **Dado** um repositório inacessível com 23 issues coletadas, **quando** a lista é exibida,
   **então** a marca o distingue dos que estão sendo observados, e o texto diz que há trabalho
   **e** que a plataforma não o alcançou na última coleta.
2. **Dado** um repositório excluído da observação pelo tenant, **quando** a lista é exibida,
   **então** a marca diz que a exclusão é decisão de alguém — diferente de falha de alcance.
3. **Dado** um repositório inacessível, **quando** a pessoa clica nele, **então** as issues dele
   continuam consultáveis, porque perder alcance não é o dado ter sumido.

---

### User Story 3 - Ir do repositório para as issues dele (Priority: P1)

Quem vê a marca clica no repositório e chega às issues dele.

**Por que é P1**: é a segunda metade do pedido. A tela existe; o que esta feature garante é que
**todo** repositório continue alcançável, inclusive os vazios.

**Teste independente**: clicar em cada um dos quatro estados abre a tela do repositório, e cada
uma diz a coisa certa sobre o que há lá.

**Cenários de aceitação**

1. **Dado** um repositório com issues, **quando** a pessoa clica no nome, **então** a tela dele
   lista as issues, com a contagem por conceito somando o total.
2. **Dado** um repositório **sem** issues, **quando** a pessoa clica no nome, **então** a tela
   abre e explica **por que** está vazio — coletado e vazio, excluído, ou inacessível.
3. **Dado** que a pessoa usa o telefone, **quando** toca no nome, **então** o alvo de toque é
   suficiente e a navegação funciona igual.

---

### User Story 4 - Ver só onde há trabalho (Priority: P2)

Quem administra quer reduzir a lista aos repositórios que têm issues, sem perder a ordem
alfabética que já conhece.

**Por que é P2**: resolve o mesmo problema da US1 por outro caminho, e a US1 já o resolve para
quem varre. Vale entregar depois, e não antes.

**Teste independente**: com o filtro ativo, a lista mostra 36 de 135, e a ordem entre eles é a
mesma de antes.

**Cenários de aceitação**

1. **Dado** 135 repositórios, **quando** a pessoa filtra por "com trabalho", **então** a lista
   mostra 36 e o cabeçalho diz quantos foram omitidos.
2. **Dado** o filtro ativo, **quando** a pessoa recarrega a tela, **então** a ordem alfabética é
   preservada dentro do subconjunto.
3. **Dado** o filtro ativo e nenhum repositório com issues, **quando** a lista é exibida,
   **então** ela diz que a organização não tem trabalho coletado — distinto de "nada casou o
   filtro".

---

### Edge Cases

1. **Repositório com issues, todas marcadas como não mais observadas** — o trabalho existe
   historicamente e não está vigente. A marca diz qual dos dois?
2. **Repositório excluído da observação que tem issues** — decisão de alguém, e o trabalho
   permanece.
3. **Repositório arquivado na origem com issues** — a origem parou, a plataforma não.
4. **Organização inteira sem nenhum repositório com issues** — 61 dos 135 são vazios; uma
   organização pode ser 100% vazia.
5. **Repositório observado hoje, coleta de issues ainda não executada** — contagem desconhecida,
   e não zero.
6. **Duas organizações com repositórios de mesmo nome** — a marca não pode fazer o leitor
   confundir qual é qual.
7. **135 repositórios na coluna estreita do telefone** — a marca precisa funcionar no cartão.
8. **Contagem que muda enquanto a tela está aberta** — uma coleta em andamento altera o número.

---

## Requirements *(mandatory)*

### Functional Requirements

#### A marca

- **FR-001**: A lista de repositórios em `/work` DEVE exibir, para cada repositório, uma marca
  que distingue **quatro** estados: tem trabalho coletado, coletado e vazio, nunca coletado, e
  não observado (excluído ou inacessível).
- **FR-002**: A marca DEVE distinguir os estados por **forma e texto**, e NÃO apenas por cor —
  os quatro estados permanecem distinguíveis em monocromático.
- **FR-003**: Cada marca DEVE ter rótulo acessível a leitor de tela dizendo o estado por
  extenso.
- **FR-004**: A marca de "coletado e vazio" DEVE dizer que a coleta ocorreu e o resultado é
  vazio, e NÃO DEVE exibir o número zero como se fosse quantidade medida.
- **FR-005**: A marca de "nunca coletado" DEVE ser distinta de "coletado e vazio", e a contagem
  DEVE aparecer como desconhecida — nunca como zero.
- **FR-006**: A marca de repositório **não observado** DEVE distinguir exclusão por decisão do
  tenant de perda de alcance na coleta.
- **FR-007**: Repositório não observado que **tem** issues coletadas DEVE ter isso visível: a
  marca não pode fazê-lo parecer vazio.
- **FR-008**: A marca DEVE funcionar na tabela e no cartão do telefone, mantendo forma, texto e
  rótulo acessível.

#### A navegação

- **FR-009**: Todo repositório da lista DEVE continuar navegável, **inclusive os vazios** —
  a tela dele explica por que está vazio, e essa explicação é o que alguém procura.
- **FR-010**: Clicar no repositório DEVE abrir a tela dele com as issues, sem consultar a
  origem.
- **FR-011**: O alvo de toque do link DEVE atender ao mínimo de acessibilidade no telefone.
- **FR-012**: A tela do repositório DEVE continuar distinguindo os três vazios que já
  distingue — coletado e vazio, excluído, inacessível.

#### A contagem por trás da marca

- **FR-013**: A contagem que a marca resume DEVE vir da **mesma** fonte que a coluna de
  contagem: um número, dois consumidores.
- **FR-014**: Desenhar a lista NÃO DEVE aumentar o número de consultas em relação ao que a tela
  faz hoje.
- **FR-015**: A contagem DEVE distinguir issue vigente de issue marcada como não mais
  observada, e a marca DEVE dizer qual está resumindo.

#### O filtro (US4)

- **FR-016**: A lista DEVE oferecer um filtro que reduz aos repositórios com trabalho coletado.
- **FR-017**: O filtro DEVE preservar a ordem alfabética dentro do subconjunto.
- **FR-018**: Com o filtro ativo, o cabeçalho DEVE dizer **quantos repositórios foram
  omitidos** — esconder sem dizer quanto foi escondido é o que faz alguém concluir que a lista
  é tudo.
- **FR-019**: A ordem padrão da lista NÃO DEVE mudar: quem sabe que o repositório está na letra
  M continua encontrando-o ali.
- **FR-020**: O filtro sem resultado DEVE distinguir "esta organização não tem trabalho
  coletado" de "nada casou o filtro".

#### Transversais

- **FR-021**: Nenhuma tela DEVE exibir repositório de outro tenant, e a consulta a repositório
  de outro tenant DEVE responder **não encontrado**, nunca "sem permissão".
- **FR-022**: O escopo desta feature é a tela `/work` e a tela do repositório. A tela de
  sincronização **NÃO** recebe a marca: lá o repositório aparece como fase de execução, e a
  pergunta é outra.

### Key Entities

- **Estado de trabalho do repositório**: derivado, nunca gravado. Combina a contagem de issues
  com o estado de observação, e é o que a marca exibe.
- **Repositório observado**: já existe. Traz o estado de observação — excluído, inacessível,
  arquivado — e a identidade na origem.
- **Contagem de issues por repositório**: já existe na tela; passa a ter dois consumidores.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Numa organização de 121 repositórios, é possível identificar os que têm trabalho
  coletado **sem ler nenhum número**.
- **SC-002**: Os quatro estados permanecem distinguíveis com a cor removida.
- **SC-003**: Cada marca é anunciada por leitor de tela com o estado por extenso.
- **SC-004**: Nenhum repositório vazio exibe `0` como quantidade; todos exibem a razão da
  ausência.
- **SC-005**: "Coletado e vazio" e "nunca coletado" produzem textos diferentes.
- **SC-006**: Os 38 repositórios inacessíveis com 897 issues aparecem como tendo trabalho **e**
  fora de observação — nunca como vazios.
- **SC-007**: Todos os 135 repositórios continuam navegáveis.
- **SC-008**: Desenhar a lista faz o mesmo número de consultas que hoje, ou menos.
- **SC-009**: A marca é legível e o link é tocável em largura de 360 px.
- **SC-010**: Com o filtro ativo, a lista mostra 36 de 135 e diz que 99 foram omitidos.
- **SC-011**: A ordem padrão da lista é idêntica à de antes da feature.
- **SC-012**: Um tenant não alcança repositório de outro, e a mensagem não confirma existência.
- **SC-013**: A tela de sincronização permanece sem a marca.

---

## Assumptions

- **A contagem resumida é a de issues vigentes.** Issue marcada como não mais observada não
  conta como trabalho presente — mas o repositório que só tem dessas não é "vazio": é "sem
  trabalho vigente", e o texto diz isso.
- **"Nunca coletado" é inferido da ausência de coleta de issues naquele repositório**, e não de
  um campo novo. Se a inferência não for possível com o que existe, o plano decide entre
  registrar o fato ou tratar a ausência como desconhecida — nunca como zero.
- **A marca não é um conceito da ontologia.** É estado derivado de exibição, como a
  classificação épico/atômica: calculado na leitura, nunca gravado.
- **O filtro é preferência de sessão, não de pessoa.** Não há tela de preferências, e criar uma
  para isto seria desenho que o problema não pede.
- **A tela do repositório não muda além do necessário.** Ela já lista as issues e já distingue
  os três vazios; a feature garante que continue alcançável, não a reescreve.

## Dependencies

- Feature 006 — a tela do repositório com as issues dele. Sem ela não há para onde o clique ir.
- Feature 007 — o design system: a marca **é** uma aplicação da gramática da evidência, e as
  regras de forma, texto e rótulo acessível vêm de lá.

## Out of Scope

| Fora | Por quê |
|---|---|
| marca na tela de sincronização | lá o repositório é fase de execução; outra pergunta (FR-022) |
| ordenar por contagem | mudaria a ordem que as pessoas já conhecem; o filtro resolve (FR-019) |
| marca por conceito — "tem épicos", "tem defeitos" | a tela do repositório já mostra por conceito |
| escolher quais repositórios observar | é a issue #108, no product backlog |
| preferência persistida de filtro | exigiria tela de preferências; sessão basta |
| indicador de "issues novas desde a última visita" | exigiria registrar visita por pessoa |
