# Feature Specification: destravar a sincronização presa

**Feature**: `008-destravar-sync-presa` · **Criada em**: 2026-08-12
**Estado**: rascunho, pronta para `/speckit-plan`
**Origem**: [#175](https://github.com/The-Band-Solution/theband/issues/175), product backlog,
levantada ao fechar o sprint 005

## Pedido

> "Encerrar o sync quando o job é descartado, e oferecer uma ação na tela de sincronização para
> encerrar uma execução presa — com o motivo registrado, nunca apagando o registro."
>
> — issue #175

**É defeito, não capacidade nova.** A plataforma já tem a defesa contra duas coletas simultâneas;
o que falta é encerrar a execução quando o processo que a executava deixou de existir.

---

## O que trava, e por quê

O índice `syncs_one_running_per_tool_index` é único parcial: **uma** sincronização `running` por
ferramenta. Ele existe de propósito — duas coletas simultâneas da mesma origem produziriam duas
respostas para "o que esta execução trouxe".

Ninguém encerra o registro quando o processo morre. E aí a defesa vira **bloqueio permanente**: a
ferramenta não aceita coleta nova, e não há caminho pela interface para destravar.

### Medido no banco em 2026-08-12

| | |
|---|---:|
| execuções concluídas | 28 |
| execuções com falha | 2 |
| execuções **interrompidas à mão, por SQL** | **2** |
| trabalhos descartados | **5** |
| trabalho **executando desde 2026-08-09**, em nó que não existe mais | **1** |

**Os dois `interrupted` foram destravados por SQL**, e o procedimento está registrado em
`docs/sprints/RETOMAR.md`. Precisar de SQL duas vezes é o argumento: o caminho manual já é
prática, e prática não documentada na interface é dívida que só quem escreveu sabe pagar.

### São dois caminhos, com causas diferentes

| Caminho | O que aconteceu | Quantos |
|---|---|---:|
| **descartado** | o trabalho esgotou as tentativas — DNS que não resolveu, módulo que não existe | 5 |
| **órfão** | o trabalho ficou executando num nó da BEAM que morreu; nada o resgata | 1, há três dias |

O segundo é o que aconteceu de verdade **duas vezes** — e é o que o SQL resolveu.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Coletar de novo depois de uma falha (Priority: P1)

Quem administra tenta sincronizar, a coleta falha, e **quer tentar outra vez**. Hoje a segunda
tentativa é recusada com "já existe uma sincronização em andamento" — sobre uma execução que
morreu há três dias.

**Por que é P1**: sem isto a ferramenta fica inutilizável, e a única saída é SQL. É o problema
inteiro da feature.

**Teste independente**: com um registro preso em `running` e nenhum trabalho ativo, iniciar uma
coleta nova **funciona**, e a execução presa aparece encerrada com o motivo.

**Cenários de aceitação**

1. **Dado** um registro `running` cujo trabalho foi descartado, **quando** alguém abre a tela de
   sincronizações, **então** o registro aparece encerrado, com o motivo que veio do trabalho.
2. **Dado** o mesmo registro encerrado, **quando** alguém inicia uma coleta, **então** ela começa
   — e o índice não recusa mais.
3. **Dado** um registro `running` cujo trabalho **ainda está executando**, **quando** a tela é
   carregada, **então** ele **continua** `running`: encerrar uma coleta viva é pior que o problema.
4. **Dado** um registro encerrado por este caminho, **quando** alguém o abre, **então** os
   checkpoints, as contagens e os payloads que ele produziu continuam lá.

---

### User Story 2 - Entender por que a execução morreu (Priority: P1)

Quem vê uma execução encerrada precisa saber **qual** falha — porque a ação seguinte depende
disso. DNS que não resolveu se cura tentando de novo; credencial revogada, não.

**Por que é P1**: um motivo genérico apagaria a distinção entre falha transitória e permanente — a
mesma distinção que custou **899 issues** fora de circulação no sprint 005 (L29).

**Teste independente**: dois registros presos por causas diferentes exibem **frases diferentes**,
e nenhuma das duas é "erro".

**Cenários de aceitação**

1. **Dado** um trabalho descartado por falha de rede, **quando** o registro é encerrado, **então**
   o motivo carrega a falha que o trabalho registrou.
2. **Dado** um trabalho que desapareceu sem deixar registro, **quando** o registro é encerrado,
   **então** o motivo diz que **o processo que a executava não existe mais** — e não inventa
   falha que ninguém observou.
3. **Dado** que a pessoa usa leitor de tela, **quando** percorre a lista, **então** o estado e o
   motivo são anunciados.

---

### User Story 3 - Encerrar à mão o que a plataforma não consegue provar (Priority: P2)

Sobra um caso que nenhuma verificação automática resolve: o trabalho **consta** como executando, e
quem administra sabe que o processo morreu — porque reiniciou a aplicação, porque o contêiner caiu.
Aí é decisão humana.

**Por que é P2**: as duas primeiras user stories cobrem o que a plataforma consegue provar. Esta
cobre o resto, e é a que precisa de mais cuidado: encerrar uma coleta viva derruba trabalho em
andamento.

**Teste independente**: a ação aparece **só** quando a plataforma não consegue provar que o
trabalho está vivo, e o registro guarda **quem** decidiu.

**Cenários de aceitação**

1. **Dado** um registro `running` que a plataforma não consegue provar vivo, **quando** quem
   administra encerra, **então** o registro fica encerrado com o motivo e **com o autor**.
2. **Dado** um registro cujo trabalho deu sinal recente, **quando** a tela é exibida, **então** a
   ação de encerrar **não** é oferecida.
3. **Dado** que a ação é oferecida, **quando** quem administra a vê, **então** o texto diz o que
   vai acontecer — encerrar o registro, não cancelar a coleta que já rodou.
4. **Dado** um registro de outro tenant, **quando** alguém tenta encerrá-lo, **então** a resposta é
   **não encontrado**.

---

### Edge Cases

1. **Trabalho descartado enquanto ninguém olha a tela.** O bloqueio precisa sair sem depender de
   alguém abrir a interface.
2. **Trabalho órfão que volta a executar.** A coleta rodou metade; retomar precisa continuar de
   onde parou, e não recomeçar do zero — os cursores por entidade já existem.
3. **Dois caminhos encerrando o mesmo registro ao mesmo tempo** — a verificação automática e a ação
   humana, no mesmo instante.
4. **Registro `running` cujo trabalho nunca existiu** — enfileirado em fila não configurada, ou
   com módulo que não existe. Dois dos cinco descartes são exatamente isto.
5. **Execução legítima e longa.** Uma coleta de 4 474 issues leva minutos; declarar presa uma
   coleta viva é o defeito oposto, e é pior.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Uma execução `running` cujo trabalho **não existe mais** DEVE ser encerrada, e a
  ferramenta DEVE voltar a aceitar coleta nova.
- **FR-002**: O encerramento DEVE registrar o **motivo**, e o motivo DEVE distinguir as causas:
  trabalho descartado carrega a falha que o trabalho registrou; trabalho que desapareceu diz que o
  processo não existe mais.
- **FR-003**: O motivo NÃO DEVE inventar falha que ninguém observou. Ausência de registro do
  trabalho é dito como ausência — nunca como erro genérico.
- **FR-004**: Encerrar NÃO DEVE apagar nada: checkpoints, contagens, payloads e o próprio registro
  continuam. Muda o estado e o motivo.
- **FR-005**: Uma execução cujo trabalho **está vivo** NÃO DEVE ser encerrada por verificação
  automática.
- **FR-006**: O bloqueio DEVE sair **sem depender de alguém abrir a tela** — a plataforma percebe
  quando o trabalho termina mal.
- **FR-007**: A decisão de encerrar DEVE ter **um caminho só**, usado por todos os gatilhos: dois
  caminhos para a mesma decisão discordariam, e o projeto já pagou por isso três vezes.
- **FR-008**: A tela de sincronizações DEVE oferecer a ação de encerrar **apenas** quando a
  plataforma não consegue provar que o trabalho está vivo.
- **FR-009**: O encerramento **por decisão humana** DEVE registrar **quem** decidiu. O
  encerramento pela plataforma DEVE deixar o autor **ausente** — e ausente significa "não foi
  pessoa", nunca um autor inventado.
- **FR-010**: Trabalho órfão de nó morto DEVE **voltar a executar**, retomando pelos cursores já
  gravados, em vez de ser descartado — o trabalho já feito não se repete.
- **FR-011**: O tempo até considerar um trabalho órfão DEVE ser maior que a execução legítima mais
  longa observada, e o valor escolhido DEVE estar declarado.
- **FR-012**: A lista de execuções DEVE dizer o estado e o motivo em **texto**, e o estado NÃO DEVE
  ser carregado só por cor.
- **FR-013**: Nenhuma tela DEVE exibir execução de outro tenant, e a ação sobre execução de outro
  tenant DEVE responder **não encontrado**, nunca "sem permissão".
- **FR-014**: Encerrar uma execução já encerrada NÃO DEVE mudar o motivo nem o autor originais.
- **FR-015**: O escopo é a tela de sincronizações. Nenhuma outra tela recebe a ação.

### Key Entities

- **Execução de coleta** (`sync`): ganha **autor do encerramento**, ausente quando quem encerrou
  foi a plataforma. Os quatro estados existentes bastam — `interrupted` já significa "não terminou
  e não vai terminar", e o **porquê** vive no motivo.
- **Trabalho** (job da fila): não é entidade do domínio. A plataforma consulta o estado dele para
  decidir, e não o copia para dentro do registro.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Com uma execução presa, iniciar coleta nova da mesma ferramenta **funciona**, sem SQL.
- **SC-002**: O bloqueio sai **sem** que ninguém abra a tela.
- **SC-003**: Duas execuções presas por causas diferentes exibem motivos **diferentes**, e nenhum
  deles é a palavra "erro" sozinha.
- **SC-004**: Execução encerrada por este caminho preserva **100%** dos checkpoints, contagens e
  payloads que produziu.
- **SC-005**: Nenhuma execução com trabalho vivo é encerrada automaticamente — verificado com um
  trabalho em execução de fato.
- **SC-006**: A ação de encerrar aparece **apenas** nas execuções que a plataforma não consegue
  provar vivas.
- **SC-007**: Execução encerrada por pessoa tem autor; encerrada pela plataforma tem autor
  **ausente**, e a tela diz qual dos dois foi.
- **SC-008**: Trabalho órfão retomado **não recoleta** o que já havia coletado.
- **SC-009**: O estado e o motivo são legíveis com a cor removida, e anunciados por leitor de tela.
- **SC-010**: Um tenant não alcança execução de outro, e a mensagem não confirma existência.
- **SC-011**: Encerrar duas vezes não altera o primeiro motivo nem o primeiro autor.

---

## Assumptions

- **`interrupted` serve, e nenhum estado novo é criado.** Ele já significa "não terminou e não vai
  terminar". O que faltava não era estado: era **motivo** e **autor**.
- **Autor ausente é informação.** Nulo diz "quem encerrou foi a plataforma", e é diferente de
  "não se sabe quem" — a plataforma sabe que não foi pessoa.
- **A decisão tem um caminho só, com vários gatilhos.** Perceber o fim do trabalho, carregar a
  tela e a ação humana chamam **a mesma** decisão. Três implementações da mesma regra é o defeito
  que este projeto já pagou em `classification/2`, na prévia contra o recálculo, e na coleta contra
  o recálculo.
- **Retomar é seguro porque a coleta é idempotente.** Cursores por entidade e chave natural na
  gravação já existem; retomar é o comportamento que o desenho da coleta pressupõe.
- **A tela não vira monitor de fila.** Ela mostra execuções de coleta. O estado do trabalho é
  consultado para decidir, e não exibido como painel de infraestrutura.

## Dependencies

- A fila de trabalhos precisa expor o estado de um trabalho por identificação — é o que sustenta
  FR-005 e FR-008.
- O design system em `docs/design-system.md`: estado e motivo em texto, ausência nomeada, e o
  padrão de confirmação para ação destrutiva.

## Out of Scope

| Fora | Por quê |
|---|---|
| cancelar uma coleta **em andamento** | é outra pergunta: parar o que está vivo, e ninguém pediu |
| painel de trabalhos da fila | a tela mostra coleta, não infraestrutura |
| repetir automaticamente a coleta que falhou | quem decide tentar de novo é quem administra; automatizar esconderia falha permanente |
| notificar por e-mail quando uma coleta falha | não foi pedido; entra quando houver a segunda pessoa administrando |
| remover o índice de uma execução por ferramenta | ele é a defesa correta; o defeito era não encerrar o registro |
