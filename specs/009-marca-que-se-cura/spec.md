# Feature Specification: a marca de inacessível se cura

**Feature**: `009-marca-que-se-cura` · **Criada em**: 2026-08-12
**Estado**: rascunho, pronta para `/speckit-plan`
**Origem**: [#213](https://github.com/The-Band-Solution/theband/issues/213) e
[#214](https://github.com/The-Band-Solution/theband/issues/214), product backlog, **Bug, P0**

## Pedido

A pessoa mantenedora achou o número de issues da `leds-conectafapes` baixo e pediu conferência. A
conferência respondeu que a coleta está quase completa — **4283 na origem, 4280 no banco** — e
achou dois defeitos que ninguém procurava.

**É defeito, não capacidade nova**, e é a **L29 revisitada**: falha transitória tirando dado de
circulação em silêncio.

---

## O que está acontecendo, medido em 2026-08-12

| | |
|---|---:|
| repositórios marcados como inacessíveis | **39** |
| issues dentro deles | **899** |
| coletas concluídas **depois** da última marca | 2 |
| marcas que se limparam nessas coletas | **0** |

Os motivos gravados:

| motivo | quantos | natureza |
|---|---:|---|
| não foi possível resolver o endereço da instância | 38 | **DNS de um instante** |
| "Something went wrong while executing your query… Please include `6D2F:110188:…`" | 1 | **falha interna do GitHub**, com identificador de incidente |

**Nenhum dos dois é permanente**, e os dois produziram marca permanente na prática.

### Defeito 1 — a marca é auto-perpetuante

A coleta descobre todos os repositórios da organização, e **depois filtra os inacessíveis**. A
coleta de issues só roda para o que sobra — e é dentro dela que a marca seria limpa.

**O repositório marcado nunca chega ao ponto que o limparia.** A correção da L29 impediu marcas
novas por falha transitória e declarou que *"a cura é a própria coleta"* — mas a cura pressupõe que
a coleta **tente**, e ela não tenta.

### Defeito 2 — falha interna da origem lida como permanente

A origem responde falha interna com **sucesso de transporte e erro no corpo**. A plataforma trata
todo erro desse tipo como permanente — e nem todos são: "não encontrado" e "sem escopo" são
permanentes; falha interna com identificador de incidente é transitória, e a própria mensagem pede
para reportá-la.

### O custo já começou

`leds-conectafapes-prestacao-de-contas`: **11 issues na origem, 9 no banco**. E as duas maiores
apostas estão congeladas — `plataformas-project` com 647 issues, `produtos-internos-project` com
232. Nada novo nelas será visto.

**O agregado está certo e o mecanismo está quebrado.** É isso que esconde o defeito: a perda é de
tudo que for criado a partir de agora.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A coleta volta a alcançar o que falhou (Priority: P1)

Uma falha de rede de um instante tira 38 repositórios da coleta. Na coleta seguinte, a plataforma
**tenta de novo** — e o que responder volta a ser coletado, sem ninguém intervir.

**Por que é P1**: sem isto, 899 issues estão fora de toda coleta futura, e o número cresce sozinho.

**Teste independente**: com um repositório marcado e a origem respondendo, uma coleta limpa a marca
e traz as issues dele.

**Cenários de aceitação**

1. **Dado** um repositório marcado como inacessível e uma origem que responde, **quando** a coleta
   roda, **então** a marca sai e as issues dele são coletadas.
2. **Dado** um repositório marcado cuja origem **continua** falhando, **quando** a coleta roda,
   **então** a marca permanece — e **a data de quando começou não muda**.
3. **Dado** um repositório **excluído pelo tenant**, **quando** a coleta roda, **então** ele
   **não** é tentado: exclusão é decisão de alguém, e a plataforma não a desfaz.
4. **Dado** que a origem falha para 39 repositórios, **quando** a coleta roda, **então** ela
   **conclui** — uma falha por repositório não interrompe a execução.

---

### User Story 2 - Falha do momento não vira decisão permanente (Priority: P1)

Uma falha interna da origem não deve ter o mesmo efeito que um repositório apagado.

**Por que é P1**: é o que criou a 39ª marca, no mesmo dia em que a correção anterior foi
incorporada.

**Teste independente**: a resposta real da origem — a que está gravada no banco — **não** marca o
repositório como inacessível.

**Cenários de aceitação**

1. **Dado** que a origem responde com falha interna e identificador de incidente, **quando** a
   coleta processa o erro, **então** o repositório **não** é marcado, e o log diz que a falha é do
   momento.
2. **Dado** que a origem responde "não encontrado" para o repositório, **quando** a coleta processa
   o erro, **então** ele **é** marcado — porque isso se repetirá.
3. **Dado** que a origem responde com **dois** erros, um permanente e um do momento, **quando** a
   coleta processa, **então** vale o permanente.

---

### User Story 3 - Ver desde quando não se alcança, e por quê (Priority: P2)

Quem administra vê `unreachable` na lista e não sabe se é de agora ou de dez dias, nem se a
plataforma ainda tenta.

**Por que é P2**: sem isto, quem lê conclui que a plataforma desistiu — e foi o que aconteceu de
verdade até esta feature.

**Teste independente**: a linha do repositório inacessível diz **desde quando** e **o que a origem
respondeu**.

**Cenários de aceitação**

1. **Dado** um repositório inacessível, **quando** a lista é exibida, **então** ela diz desde
   quando e o motivo.
2. **Dado** que a pessoa não distingue cores, **quando** vê a lista, **então** o estado continua
   legível por texto.
3. **Dado** um repositório de outro tenant, **quando** alguém tenta alcançá-lo, **então** a
   resposta é **não encontrado**.

---

### Edge Cases

1. **Repositório apagado na origem.** Vai falhar sempre, e vai ser tentado sempre. É ruído
   aceitável? A alternativa — desistir — é o defeito que esta feature corrige.
2. **A origem falha para todos os repositórios.** A coleta tenta 121 vezes e falha 121 vezes; ela
   precisa concluir, e o relatório precisa dizer o que não foi alcançado.
3. **Repositório que oscila**: alcança numa coleta, falha na seguinte, alcança na terceira. A data
   de início da marca precisa significar algo em cada ciclo.
4. **Limpar a marca apaga a informação de que houve problema.**
4a. **Motivo mais longo que a coluna aceita.** O texto vem da origem, e o maior gravado hoje tem
   181 caracteres num limite de 255 — 27 de folga, num campo que a feature passa a escrever a cada
   coleta que falhar.
5. **Repositório excluído E inacessível.** As duas marcas coexistem hoje; a exclusão vence.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A coleta DEVE **tentar** o repositório marcado como inacessível, em vez de excluí-lo
  da execução.
- **FR-002**: Quando a tentativa alcança a origem, a marca DEVE sair — e as issues do repositório
  DEVEM ser coletadas na mesma execução.
- **FR-003**: Quando a tentativa falha de novo, a marca DEVE permanecer, e a data de **quando
  começou** NÃO DEVE ser sobrescrita. O motivo DEVE refletir a **última** falha.
- **FR-004**: Repositório **excluído pelo tenant** NÃO DEVE ser tentado. Exclusão é decisão de
  alguém, e a plataforma não a desfaz.
- **FR-005**: Uma falha em um repositório NÃO DEVE interromper a coleta dos outros.
- **FR-006**: Falha **interna da origem** — a que vem com identificador de incidente — NÃO DEVE
  marcar o repositório como inacessível.
- **FR-007**: Falha que se repetirá — "não encontrado", "sem escopo" — DEVE marcar.
- **FR-008**: Quando a origem responde com **vários** erros, DEVE valer o mais permanente entre
  eles.
- **FR-009**: A classificação DEVE ter **um lugar só**: o mesmo julgamento que decide marcar decide
  a nova tentativa.
- **FR-010**: A lista de repositórios DEVE dizer, para o inacessível, **desde quando** e **o que a
  origem respondeu** — em texto, não só por cor.
- **FR-011**: A lista NÃO DEVE fazer o inacessível parecer abandonado: quem lê precisa entender que
  a plataforma tenta de novo a cada coleta.
- **FR-012**: Limpar a marca NÃO DEVE apagar issue, checkpoint ou payload — nada coletado é
  removido.
- **FR-013**: Nenhuma tela DEVE exibir repositório de outro tenant, e a consulta a repositório de
  outro tenant DEVE responder **não encontrado**.
- **FR-014**: O relatório da coleta DEVE dizer **quantos repositórios não foram alcançados** na
  execução — um número que hoje não existe.
- **FR-014a**: Esse número DEVE ser correto **mesmo se a execução for interrompida**. Registrá-lo
  só no fim faria uma coleta interrompida ficar com zero — e zero ali **afirma** que tudo foi
  alcançado.
- **FR-015**: O motivo da falha DEVE ser gravado **qualquer que seja o tamanho do texto que a
  origem devolva**, sem perder a informação essencial e **sem interromper a coleta**. O texto vem
  de terceiro e não tem tamanho garantido.

### Key Entities

- **Repositório observado**: já tem a marca de inacessível, com data e motivo. O que muda é
  **quem** a limpa e **quando** a data é sobrescrita.
- **Erro da origem**: passa a ter **natureza** — do momento ou permanente —, e a natureza é julgada
  num lugar só.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Depois de **uma** coleta, **nenhum repositório que a origem alcança** permanece
  marcado — hoje são 39 depois de duas coletas, e nenhuma limpou nada.

  A formulação anterior dizia "zero dos 39", e era **inverificável**: se algum dos 39 estiver
  inacessível porque a credencial não o alcança, ele volta a ser marcado — corretamente —, e o
  critério reprovaria por estar certo.
- **SC-002**: As **899** issues dos repositórios hoje marcados voltam a ser alcançadas, e
  `leds-conectafapes-prestacao-de-contas` passa a ter as 11 da origem.
- **SC-003**: A resposta real de falha interna gravada no banco **não** marca o repositório —
  verificado com o payload que produziu a 39ª marca.
- **SC-004**: "Não encontrado" continua marcando.
- **SC-005**: Uma coleta em que **todos** os repositórios falham **conclui**, e o relatório diz
  quantos não foram alcançados.
- **SC-006**: Repositório excluído pelo tenant não é tentado — nenhuma requisição é feita por ele.
- **SC-007**: A data de início da marca **não muda** entre duas falhas consecutivas.
- **SC-008**: A lista diz desde quando e por quê, e o estado é legível com a cor removida.
- **SC-009a**: Uma coleta **interrompida** no meio da fase de repositórios registra o número de não
  alcançados **até ali**, e não zero.
- **SC-009b**: Um motivo com **500 caracteres** é gravado sem interromper a coleta, e a lista o
  exibe sem dominar a linha.
- **SC-009**: Nenhuma issue, checkpoint ou payload é removido ao limpar a marca — a contagem antes
  e depois é a mesma, mais o que a origem passou a ter.
- **SC-010**: Um tenant não alcança repositório de outro, e a mensagem não confirma existência.

---

## Assumptions

- **Tentar todos, sempre.** Não há critério de tempo para decidir quando tentar de novo: constante
  de tempo é o que envelhece, e esta sessão já a recusou duas vezes. O custo é uma consulta por
  repositório marcado, por coleta — e 33 dos 39 têm zero issues na origem, então a consulta é de
  uma página.
- **A data de início preserva o começo do problema; o motivo carrega a última falha.** As duas
  informações são diferentes, e nenhuma das duas precisa de coluna nova: "desde quando" já existe e
  passa a **não** ser sobrescrita.
- **Nada de estado novo.** "Não alcancei uma vez" e "não alcanço há dias" se distinguem pela data,
  que passa a significar o começo. Um estado a mais obrigaria toda leitura a conhecê-lo.
- **Limpar a marca apaga o fato de que houve problema, e isso é aceito.** A plataforma registra
  **estado de observação**, não histórico de incidente. Registrar o histórico exigiria evento
  append-only — o padrão existe (ADR 0004 D7) e é outra feature, com necessidade de informação
  própria. Fica declarado aqui em vez de silenciado.
- **A exclusão vence a inacessibilidade.** Repositório excluído e marcado não é tentado: a decisão
  humana tem precedência sobre a inferência da plataforma.

## Dependencies

- A origem precisa distinguir, na resposta de erro, o que é falha interna do que é ausência de
  recurso — é o que sustenta FR-006 e FR-007. Hoje ela distingue: o erro traz tipo, e a falha
  interna traz identificador de incidente.

## Out of Scope

| Fora | Por quê |
|---|---|
| histórico de incidentes por repositório | exige evento append-only e necessidade de informação própria — declarado nas premissas |
| desistir de repositório que falha há muito tempo | é o defeito que esta feature corrige; se virar ruído, o critério será a **natureza do erro**, nunca o tempo |
| notificar quem administra quando um repositório fica inacessível | não foi pedido, e entra quando houver a segunda pessoa administrando |
| tentar de novo **dentro** da mesma coleta | a coleta seguinte é a próxima tentativa; repetir na mesma execução multiplica requisição contra uma origem que acabou de falhar |
| alterar o índice ou a política de exclusão pelo tenant | exclusão é decisão humana e continua como está |
