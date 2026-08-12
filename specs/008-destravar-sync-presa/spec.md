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
3. **Dado** um registro `running` cujo trabalho consta **em execução**, **quando** a tela é
   carregada, **então** ele **continua** `running`: a plataforma não encerra sozinha o que não
   consegue verificar, porque encerrar liberaria a restrição e uma segunda coleta começaria em
   paralelo.
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

1. **Dado** um registro cujo trabalho consta **em execução** num processo que morreu, **quando**
   quem administra encerra, **então** o registro fica encerrado com o autor e com o motivo dizendo
   **o que a pessoa afirmou** — que o processo não existe mais.
2. **Dado** um registro cujo trabalho a fila **vai pegar** — `available`, `scheduled`, `retryable`
   ou pausado —, **quando** a tela é exibida, **então** a ação **não** é oferecida, porque isso a
   plataforma prova.
2a. **Dado** que a ação é oferecida sobre trabalho em execução, **quando** a confirmação aparece,
   **então** ela diz que a plataforma não sabe se o processo vive, e que uma segunda coleta pode
   começar em paralelo.
3. **Dado** que a ação é oferecida, **quando** quem administra a vê, **então** o texto diz o que
   vai acontecer — encerrar o registro, não cancelar a coleta que já rodou.
4. **Dado** um registro de outro tenant, **quando** alguém tenta encerrá-lo, **então** a resposta é
   **não encontrado**.

---

### Edge Cases

1. **Trabalho descartado enquanto ninguém olha a tela.** O bloqueio precisa sair sem depender de
   alguém abrir a interface.
2. **Trabalho órfão, e o que acontece com o que ele já coletou.** A coleta rodou metade. A
   execução é encerrada, e a coleta nova recoleta desde o começo — sem duplicar linha, porque a
   gravação é por chave natural. O custo é consulta repetida à origem; o ganho é não existir
   caminho para duas execuções da mesma coleta ao mesmo tempo.
3. **Dois caminhos encerrando o mesmo registro ao mesmo tempo** — a verificação automática e a ação
   humana, no mesmo instante.
4. **Registro `running` cujo trabalho nunca existiu** — enfileirado em fila não configurada, ou
   com módulo que não existe. Dois dos cinco descartes são exatamente isto.
5. **Execução legítima e longa.** Uma coleta de 4 474 issues leva minutos; declarar presa uma
   coleta viva é o defeito oposto, e é pior.
6. **Execução aberta e trabalho ainda não criado.** Entre abrir o registro e o trabalho existir há
   um intervalo, e nele a execução parece presa sem estar.
7. **Trabalho que não consegue nascer.** Se a criação do trabalho falhar depois de o registro ser
   aberto, ele fica `running` sem nada para executá-lo — o mesmo travamento da issue, por outra
   porta.

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
- **FR-005**: A verificação automática NÃO DEVE encerrar execução que tenha **qualquer** trabalho
  não terminal — inclusive trabalho que **consta em execução**. Se a coleta estiver de fato
  rodando, encerrar o registro libera a restrição e uma segunda coleta começa **em paralelo**.
- **FR-005a**: Trabalho **em execução NÃO é prova de vida**. É um registro de que algum processo
  reivindicou o trabalho, e a reivindicação sobrevive ao processo. A plataforma consegue provar
  "vai executar" para o que a fila ainda vai pegar; para o que consta em execução, **não consegue
  provar nada** — e é dessa lacuna que a decisão humana existe.
- **FR-005b**: A lista de estados DEVE ser derivada da própria fila, nunca escrita de memória.
- **FR-006**: O bloqueio DEVE sair **sem depender de alguém abrir a tela** — a plataforma percebe
  quando o trabalho termina mal.
- **FR-007**: A decisão de encerrar DEVE ter **um caminho só**, usado por todos os gatilhos: dois
  caminhos para a mesma decisão discordariam, e o projeto já pagou por isso três vezes.
- **FR-008**: A tela DEVE oferecer a ação de encerrar **exatamente** quando a plataforma não
  consegue provar que o trabalho vai executar — o que inclui o trabalho que **consta em execução**,
  e é o caso que aconteceu duas vezes. Trabalho que a fila vai pegar NÃO DEVE receber a ação.
- **FR-008a**: Quando o trabalho consta em execução, a confirmação DEVE dizer **o que a plataforma
  não sabe** e **qual é o risco**: se a coleta estiver rodando, uma segunda começa em paralelo.
  Pedir confirmação sem informar o risco é pedir confirmação de nada.
- **FR-009**: O encerramento **por decisão humana** DEVE registrar **quem** decidiu. O
  encerramento pela plataforma DEVE deixar o autor **ausente** — e ausente significa "não foi
  pessoa", nunca um autor inventado.
- **FR-010**: Trabalho órfão **NÃO DEVE ser resgatado para executar de novo**. A plataforma
  encerra a execução, e uma coleta nova recoleta — o que é seguro porque a gravação é por chave
  natural. Resgatar por tempo é o único mecanismo disponível, e ele **não sabe se o processo
  morreu**: resgataria coleta viva, que rodaria duas vezes.
- **FR-011**: A execução **recém-aberta** NÃO DEVE ser considerada presa. Existe um intervalo entre
  abrir o registro e o trabalho existir, e encerrar nesse intervalo derrubaria coleta que acabou de
  começar. O intervalo de carência DEVE estar declarado.
- **FR-011a**: Se **não for possível criar o trabalho** depois de abrir o registro, a execução DEVE
  ser encerrada na hora, com o motivo — e não deixada `running` esperando reconciliação.
- **FR-012**: A lista de execuções DEVE dizer o estado e o motivo em **texto**, e o estado NÃO DEVE
  ser carregado só por cor.
- **FR-013**: Nenhuma tela DEVE exibir execução de outro tenant, e a ação sobre execução de outro
  tenant DEVE responder **não encontrado**, nunca "sem permissão".
- **FR-014**: Encerrar uma execução já encerrada NÃO DEVE mudar o motivo nem o autor originais.
- **FR-015**: O escopo é a tela de sincronizações. Nenhuma outra tela recebe a ação.
- **FR-016**: A verificação automática DEVE alcançar **todos os tenants**, e isso é manutenção da
  plataforma — não consulta de tenant. Nenhum dado de um tenant DEVE aparecer para outro, e a ação
  **por pessoa** continua restrita ao tenant de quem a faz (FR-013).

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
- **SC-005**: Nenhuma execução com trabalho não terminal é encerrada **automaticamente** —
  verificado com trabalho em execução de fato na fila.
- **SC-005a**: Execução cujo trabalho consta **em execução** é encerrável **por pessoa**, e é o
  caso que motivou a feature. Se ela não for, o órfão de nó morto continua exigindo SQL.
- **SC-006**: A ação de encerrar aparece **apenas** nas execuções que a plataforma não consegue
  provar vivas.
- **SC-007**: Execução encerrada por pessoa tem autor; encerrada pela plataforma tem autor
  **ausente**, e a tela diz qual dos dois foi.
- **SC-008**: Depois de uma execução encerrada por abandono, a coleta nova **não duplica linha**:
  a contagem de registros no banco é a mesma de antes mais o que a origem passou a ter.
- **SC-008a**: A recusa acontece **na decisão**, não no botão: a requisição direta para encerrar uma
  execução com trabalho vivo é **recusada**, mesmo sem botão na tela.
- **SC-008b**: Execução aberta há menos que a carência declarada **não** é encerrada pela
  verificação automática.
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
- **Recoletar é seguro; retomar é que não era.** A gravação por chave natural garante que
  recoletar não duplique linha. Retomar exigiria resgatar o trabalho, e o único resgate disponível
  decide **por tempo**, sem saber se o processo morreu — o que resgataria coleta viva. A troca está
  registrada em R1: menos capacidade, e nenhum caminho para execução dupla.
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
