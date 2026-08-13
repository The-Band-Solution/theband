# Feature Specification: a migalha de pão

**Feature**: `016-migalha-de-pao` · **Criada em**: 2026-08-13
**Estado**: rascunho, pronta para `/speckit-plan`
**Origem**: [#285](https://github.com/The-Band-Solution/theband/issues/285), pedido da pessoa mantenedora

## O pedido

> "Adicione no design system a 'migalha de pão' nas páginas."

---

## O que a medida achou

**Onze telas** usam o componente de cabeçalho. E a navegação para trás hoje é isto:

| Tela | O que existe |
|---|---|
| detalhe da pessoa | um botão *"back to people"* |
| detalhe da equipe | um botão *"voltar"* — **em português, no meio de uma interface em inglês** |
| detalhe da issue | dois botões que **não** voltam: *"Repository issues"* e *"View at source"* |
| lista do repositório | nada |
| as sete listas | nada, e não precisam |

**Três formas diferentes para a mesma necessidade, e uma delas em outro idioma.** É o sintoma que o
design system existe para curar: cada tela decidiu sozinha.

### E a hierarquia não é uma só

As rotas dizem quatro formas diferentes de chegar:

```text
/people/:id            ← /people
/teams/:id             ← /teams
/work/issues/:id       ← /work  … ou ← /work/repositories/:id ?
/work/repositories/:id ← /work
/syncs  /tools         ← nada. São raiz.
```

**O detalhe da issue é o caso que decide a feature.** Ele pertence a um repositório *e* à lista de
trabalho, e quem chegou nele veio de um dos dois. Uma migalha fixa diria um caminho que pode não ser
o que a pessoa percorreu.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Saber onde estou, e subir um nível (Priority: P1)

Quem abre qualquer tela de detalhe vê o caminho até ela e volta clicando em qualquer nível.

**Por que é P1**: é o pedido, e hoje três telas resolvem isso de três jeitos.

**Cenários de aceitação**

1. **Dado** o detalhe de uma pessoa, **quando** a tela é exibida, **então** a migalha mostra
   `People › <nome>`, e `People` leva à lista.
2. **Dado** o detalhe de uma equipe, **quando** a tela é exibida, **então** o botão *"voltar"* em
   português **não existe mais** — a migalha ocupou o lugar dele.
3. **Dado** o último nível da migalha, **quando** ele é exibido, **então** ele **não** é ligação:
   é onde a pessoa está.
4. **Dado** que navego por teclado, **quando** chego à migalha, **então** cada nível recebe foco
   visível e abre com `Enter`.
5. **Dado** um leitor de tela, **quando** ele lê a migalha, **então** ele a anuncia como navegação,
   e diz qual nível é o atual.

---

### User Story 2 - O caminho reflete de onde vim (Priority: P1)

O detalhe da issue mostra o repositório no caminho quando cheguei por ele, e a lista de trabalho
quando cheguei por ela.

**Por que é P1**: é o único caso ambíguo, e resolver errado faz a migalha **mentir** sobre o
percurso.

**Cenários de aceitação**

1. **Dado** que abri a issue pela lista do repositório, **quando** a tela é exibida, **então** o
   caminho é `Work › <repositório> › #123`.
2. **Dado** que abri a issue pela lista de trabalho, **quando** a tela é exibida, **então** o
   caminho é `Work › #123`.
3. **Dado** que cheguei por um endereço colado, sem percurso, **quando** a tela é exibida,
   **então** o caminho é o **estrutural** — pelo repositório, que é o dono da issue — e nunca um
   inventado.
4. **Dado** qualquer um dos três casos, **quando** clico num nível, **então** chego a uma tela que
   existe.

---

### User Story 3 - O que não tem página não vira nível (Priority: P1)

Nível que não leva a lugar nenhum **não** aparece como ligação.

**Por que é P1**: é a mesma regra da feature 014, e o caso concreto já existe — **organização não
tem página**, e ela aparece no caminho de quase tudo.

**Cenários de aceitação**

1. **Dado** que a organização estaria no caminho, **quando** a migalha é exibida, **então** ela
   **não** aparece como ligação — e a spec decide se aparece como texto ou não aparece.
2. **Dado** as telas raiz — `/syncs`, `/tools`, `/work`, `/people`, `/teams` —, **quando** são
   exibidas, **então** elas **não** têm migalha: não há nível acima.

---

### Edge Cases

- **Telefone**: caminho de três níveis não cabe em 360 px. **Cortar o começo é o oposto do que
  ajuda** — quem está perdido precisa do topo, não do fim.
- **Título comprido**: `#1811 [FEATURE] Modelo template de pipeline para repositórios…` — o último
  nível precisa caber sem empurrar os outros para fora.
- **Recurso apagado entre o render e o clique**: o nível responde `não encontrado`, e não erro.
- **A pessoa de outro tenant**: o nível nunca aparece, porque a tela nunca abre.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Toda tela de **detalhe** MUST exibir a migalha; tela raiz MUST NOT exibir.
- **FR-002**: O último nível MUST ser o lugar atual, e MUST NOT ser ligação.
- **FR-003**: Nível sem página de destino MUST NOT virar ligação.
- **FR-004**: O caminho da issue MUST refletir **de onde a pessoa veio**, com o caminho estrutural
  como padrão quando não há percurso.
- **FR-005**: A migalha MUST ser alcançável e acionável por teclado, com foco visível.
- **FR-006**: A migalha MUST ser anunciada como navegação por leitor de tela, com o nível atual
  marcado.
- **FR-007**: O botão *"voltar"* do detalhe da equipe MUST ser removido — a migalha o substitui.
- **FR-008**: Em 360 px, a migalha MUST preservar o **primeiro** nível, e encurtar o último.
- **FR-009**: A migalha MUST ser **um componente**, e cada tela MUST apenas declarar o caminho.
- **FR-010**: Nenhuma consulta nova MUST ser acrescentada — o nome de cada nível já está carregado.

### Key Entities

- **Nível**: um rótulo, e um destino que pode não existir.
- **Caminho**: a sequência de níveis até a tela atual. Estrutural por padrão, percorrido quando a
  navegação informa.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: As **cinco** telas de detalhe exibem migalha; as seis telas raiz não exibem.
- **SC-002**: As **três** formas atuais de voltar viram **uma** — e a palavra *"voltar"* desaparece
  da interface em inglês.
- **SC-003**: Nenhum nível aponta para rota inexistente.
- **SC-004**: Em 360 px, o primeiro nível continua visível em todas as cinco telas.
- **SC-005**: O número de consultas por render **não muda** em nenhuma tela.
- **SC-006**: A migalha é o mesmo componente nas cinco — nenhuma tela desenha o separador por conta.

---

## Assumptions

- **Organização não ganha página nesta feature** — é decisão de produto, e continua fora.
- O nome de cada nível já está nos dados que a tela carrega: pessoa, equipe, repositório e issue são
  o que a tela exibe no título.
- A migalha é **navegação**, não histórico: ela mostra a hierarquia, e não os últimos lugares
  visitados.
