# Feature Specification: O tamanho do texto é escolha de quem lê

**Feature Branch**: `feat/056-tamanho-do-texto`

**Created**: 2026-09-01

**Status**: Draft

**Input**: User description: "os usuários pediram para aumentar a fonte das letras das páginas"

## Por que agora, e por que não é só aumentar

O pedido veio como "aumentem a fonte". A medição mostra o que as pessoas estão
de fato olhando:

| tamanho | ocorrências na interface |
|---|---:|
| **12px** | **461** |
| 14px | 240 |
| 16px — o tamanho do corpo | 160 |
| 18px ou mais | 28 |

**Dois terços do texto da plataforma são menores que o corpo**, e o tamanho mais
comum é o menor de todos, espalhado por 33 arquivos. Ninguém pediu isso olhando
para os 16px.

E há uma segunda coisa, que é boa e ninguém sabe: a plataforma **já acompanha o
tamanho de fonte configurado no navegador**, porque tudo está em medida relativa.
Quem aumentar a fonte no navegador aumenta a plataforma inteira hoje. **O recurso
existe e é invisível** — e recurso invisível não atende quem pediu.

**Por que não fixar um número maior e pronto**: "aumentar a fonte" não tem
resposta única. Quem lê a tela de uma issue quer texto maior; quem compara 400
linhas de tabela quer densidade. Escolher um número escolhe por todo mundo, e a
próxima reclamação vem do outro lado.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Quem chega já encontra a leitura confortável (Priority: P1)

Quem abre a plataforma depois desta entrega encontra o texto maior do que
encontrava antes, **sem precisar descobrir nada**. O tamanho mais comum da
interface deixa de ser o menor da escala.

**Why this priority**: é o pedido, na letra. Um controle que ninguém acha não
atende quem reclamou — e a maior parte das pessoas nunca abre preferências.

**Independent Test**: abrir qualquer tela numa instalação limpa e medir o menor
texto presente; comparar com o de hoje.

**Acceptance Scenarios**:

1. **Given** uma pessoa que nunca escolheu tamanho, **When** ela abre qualquer
   tela, **Then** o texto está **maior** que o de antes desta entrega, sem
   nenhuma ação dela.
2. **Given** a nova escala padrão, **When** alguém abre uma tela de tabela densa,
   **Then** a tabela continua legível e navegável — o aumento não pode quebrar o
   que já funcionava.
3. **Given** uma pessoa que **já tinha aumentado a fonte no navegador**, **When**
   ela abre a plataforma, **Then** o aumento **não é aplicado em dobro** — o
   ajuste dela continua valendo como proporção, não somado a outro.

---

### User Story 2 - Quem quer outro tamanho escolhe, e a escolha fica (Priority: P1)

Quem achar o padrão grande demais — ou pequeno demais — muda num controle visível,
ao lado do que já existe para o tema. A escolha vale nas próximas visitas, sem
login e sem configuração.

**Why this priority**: mesma prioridade da US1 porque **a US1 sozinha troca uma
reclamação por outra**. Densidade e legibilidade puxam para lados opostos, e
quem lê é quem sabe de qual lado está.

**Independent Test**: escolher um tamanho, recarregar, e encontrar o mesmo
tamanho.

**Acceptance Scenarios**:

1. **Given** a plataforma aberta, **When** a pessoa escolhe um tamanho diferente,
   **Then** a mudança acontece **imediatamente**, sem recarregar.
2. **Given** um tamanho escolhido, **When** a pessoa fecha e volta depois,
   **Then** o tamanho escolhido é o que aparece.
3. **Given** um tamanho escolhido, **When** a página carrega, **Then** ela
   **não pisca** no tamanho anterior antes de aplicar o escolhido.
4. **Given** duas abas abertas, **When** a pessoa muda o tamanho numa,
   **Then** a outra acompanha.
5. **Given** uma pessoa que quer voltar ao padrão, **When** ela escolhe a opção
   de padrão, **Then** volta ao tamanho de quem nunca escolheu.

---

### Edge Cases

- **Aumento em dobro.** Quem já configurou fonte maior no navegador não pode
  receber o aumento duas vezes — a preferência do navegador é a base, e a da
  plataforma é proporção sobre ela.
- **Tabela densa no maior tamanho.** As telas de tabela são as que mais sofrem.
  No maior tamanho, elas ainda precisam ser usáveis.
- **Telefone.** O painel público já sumiu inteiro em 390px uma vez. O maior
  tamanho na menor largura é o cruzamento mais arriscado.
- **Armazenamento indisponível.** Navegador em modo privado, ou com o
  armazenamento bloqueado: a escolha não persiste. A plataforma precisa
  continuar funcionando, no padrão.
- **Um valor desconhecido guardado.** Alguém edita o armazenamento à mão, ou uma
  versão antiga gravou outro valor.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O tamanho padrão do texto MUST ser **maior** que o vigente antes
  desta entrega, para quem nunca escolheu.
- **FR-002**: Quem lê MUST poder escolher entre **três** tamanhos, incluindo o
  padrão, num controle visível em toda tela.
- **FR-003**: A mudança MUST ser aplicada **imediatamente**, sem recarregar.
- **FR-004**: A escolha MUST sobreviver a fechar e reabrir, **sem exigir conta**.
- **FR-005**: A página MUST aparecer já no tamanho escolhido — **sem piscar** no
  anterior.
- **FR-006**: A escolha MUST valer para as demais abas abertas.
- **FR-007**: A escala MUST ser **proporcional à preferência do navegador**, e
  MUST NOT substituí-la. Quem já aumentou a fonte lá recebe o aumento uma vez só.
- **FR-008**: Valor guardado que a plataforma não reconhece MUST ser tratado como
  ausência — cai no padrão, sem erro na tela.
- **FR-009**: Com o armazenamento indisponível, a plataforma MUST funcionar
  normalmente no padrão, e o controle MUST NOT prometer persistência que não vai
  acontecer.
- **FR-010**: Nenhum texto da interface MUST passar a usar medida fixa. É o que
  quebraria o FR-007, e é a mudança mais fácil de fazer sem perceber.

### Key Entities

Nenhuma. A escolha é preferência de quem lê, guardada no navegador dela — não é
dado da organização, não tem autor, e não pertence a tenant nenhum. Registrar
isso aqui é a decisão, e não a ausência dela.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: O menor texto da interface, no padrão novo, é de **pelo menos
  13,5px** — contra os 12px de hoje.
- **SC-002**: A escolha sobrevive a recarregar em **100%** das tentativas, e a
  página **não pisca**: o tamanho na primeira pintura é o escolhido.
- **SC-003**: Quem já tinha fonte aumentada no navegador vê a plataforma
  **proporcionalmente** maior, e não o produto dos dois aumentos.
- **SC-004**: Nas três escalas, e em largura de **390px**, as telas de tabela
  continuam navegáveis — nenhuma coluna sai da tela sem rolagem própria, e nada
  fica sobreposto.
- **SC-005**: Em navegador com armazenamento bloqueado, **100%** das telas
  carregam no padrão, sem mensagem de erro.
- **SC-006**: **Zero** medidas fixas de texto acrescentadas — conferível por
  varredura.

## Assumptions

- **Três tamanhos bastam.** Padrão, maior e o menor de hoje — para quem prefere
  densidade. Mais opções é um seletor que ninguém entende; menos, e quem discorda
  do padrão fica sem saída.
- **O padrão novo é um passo, não um salto.** O objetivo é atender o pedido sem
  derrubar a densidade de quem trabalha em tabela o dia inteiro.
- **A escolha vive no navegador, não na conta.** Ela é da pessoa naquele
  dispositivo — a mesma pessoa pode querer tamanhos diferentes no monitor e no
  telefone. Guardar na conta forçaria um só.
- **Fora de escopo — e é a parte maior do problema**: as **461 ocorrências** do
  menor tamanho, espalhadas por 33 arquivos. É o defeito de fundo, é varredura
  com julgamento em cada ponto, e feita junto com a escala **ninguém saberia qual
  das duas resolveu**. Entra como feature própria, com a regra escrita antes: o
  menor tamanho serve para metadado, e nunca para conteúdo que alguém precisa
  ler.
- **Fora de escopo**: mudar famílias tipográficas, espaçamento entre linhas, e
  qualquer ajuste de contraste ou cor.
