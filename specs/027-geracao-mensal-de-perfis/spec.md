# Feature Specification: Geração mensal dos perfis de competência

**Feature Branch**: `027-geracao-mensal-de-perfis`

**Created**: 2026-08-16

**Status**: Draft

**Input**: User description: "Geração automática e mensal dos relatórios de competência. Hoje o perfil só existe quando alguém clica. A necessidade é que os relatórios passem a ser gerados sozinhos, uma vez por mês, para as pessoas que a plataforma observa — sem que alguém precise lembrar de pedir. Cron próprio, não pendurado no sync. Regra de mudança antes de regenerar, com os limiares na base de conhecimento. A credencial do provedor por tenant faz parte desta feature. Fora do escopo: contestação do texto e mudança do formato do relatório."

## Por que esta feature existe

A feature 026 entregou o perfil de competências, e entregou junto uma dependência que não escala: **o perfil só existe se alguém lembrar de pedir**. Quem coordena precisa saber que abriu a página e o texto está lá — não descobrir que o último foi gerado em março porque foi a última vez que alguém clicou.

O que muda para quem usa: o perfil deixa de ser um botão e passa a ser um estado da plataforma.

### O que já está medido, e é o que governa o desenho

Medições sobre o banco real, em 2026-08-16:

| medição | valor |
|---|---|
| pessoas que passam nos pisos de material da 026 | **34** de 41 |
| material mediano por pessoa, antes de as tarefas em aberto saírem do prompt | 191 mil caracteres ≈ **48 mil tokens** |
| custo de uma rodada completa, na mesma base | **1,63 milhão** de tokens de entrada |
| pessoas que fecharam **10 ou mais** tarefas nos últimos 30 dias | 6 |
| pessoas que fecharam **de 1 a 9** | 14 |
| pessoas que **não fecharam nenhuma** | **14** |

A última linha é a que decide a feature. Para 14 das 34 pessoas o material de um mês para o outro é praticamente o mesmo, e um texto novo diria a mesma coisa com outras palavras. Como a tabela de perfis é **somente-acréscimo** — decisão da `FR-015` da 026, e ela existe para que duas datas possam ser comparadas —, gerar para todo mundo todo mês encheria o histórico de textos quase idênticos. **O histórico viraria ruído, e o valor de comparar duas datas morreria junto.**

Uma medição desta rodada ainda precisa ser refeita: as tarefas em aberto saíram do material depois da última contagem, e isso corta de 17% a 80% do texto de entrada conforme a pessoa. O custo real de uma rodada é **menor** que 1,63 milhão de tokens, e o quanto menor é pergunta a responder antes de fixar os limiares — não depois.

### O que a automação cria de novo, e não é técnico

Hoje a existência de um texto sobre uma pessoa é **ato de alguém**: alguém clicou, e quem clicou sabe o que pediu. Automática, somada à leitura aberta a todo o tenant (`FR-023` da 026) e à ausência de caminho de contestação (`FR-024` da 026), a geração significa que **ninguém decide** — o texto passa a existir sobre todo mundo, por padrão, todo mês.

Isso não é impeditivo, e esta spec não o trata como tal. É decisão, e tem o mesmo peso das outras duas: precisa estar escrita, com quem decidiu e quando.

## Clarifications

### Session 2026-08-16

- Q: Com a geração automática, quem decide que um texto derivado sobre cada pessoa passa a existir? → A: a organização inteira, ligada por quem administra — sem entrada nem saída por pessoa nesta versão (`FR-018`).
- Q: Ao subir a versão, a geração automática de uma organização nasce ligada ou desligada? → A: desligada até alguém ligar. Nenhum texto passa a existir por efeito de deploy, e o ato de ligar tem autor e data (`FR-018a`).
- Q: "A cada 3 meses" muda a cadência da rodada, ou é o M? → A: é o M. A rodada continua mensal, e uma pessoa é regerada quando fecha N tarefas desde o recorte anterior **ou** quando o perfil dela completa 3 meses (`FR-001`, `FR-006`).
- Q: "Acumulativo para não perder o histórico" — o que precisa ser acumulativo? → A: os dois. Cada geração lê o histórico inteiro observado da pessoa, e não só o que entrou desde o perfil anterior; e o perfil anterior continua gravado (`FR-022`).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - O perfil está lá quando eu abro (Priority: P1)

Quem coordena abre a página de uma pessoa e encontra um perfil atual, sem ter pedido nada e sem saber que existe um cron. Quando a pessoa teve trabalho novo desde a última geração, o texto reflete esse trabalho.

**Why this priority**: é a feature. Sem ela, tudo o mais é operação de algo que não acontece.

**Independent Test**: com o relógio adiantado para o dia da rodada e material novo para uma pessoa, disparar a rodada e verificar que o perfil dela ficou mais recente, sem nenhuma interação humana.

**Acceptance Scenarios**:

1. **Given** uma pessoa com perfil de dois meses atrás e 12 tarefas fechadas desde então, **When** a rodada mensal executa, **Then** um perfil novo é gravado, o anterior continua acessível, e a página mostra o novo.
2. **Given** uma pessoa com perfil de dois meses atrás e **nenhuma** tarefa fechada desde então, **When** a rodada mensal executa, **Then** nenhum perfil novo é gravado, e a página continua mostrando o anterior com a data dele.
3. **Given** que a rodada gerou um perfil, **When** quem coordena abre a aba, **Then** a proveniência exibida é a mesma de um perfil pedido a mão — modelo, data e recorte —, e **nada** na tela sugere que um perfil automático vale mais ou menos que um pedido.
4. **Given** uma pessoa que não passa nos pisos de material da 026, **When** a rodada executa, **Then** ela é pulada, e a recusa exibida na aba continua sendo a recusa do material, e não "a rodada falhou".

---

### User Story 2 - Ver o que a rodada fez, e o que ela custou (Priority: P1)

Quem administra abre uma tela e vê a última rodada: quando foi, quantas pessoas foram geradas, quantas foram puladas **e por qual motivo cada grupo foi pulado**, quantas falharam, e quanto de entrada foi consumido.

**Why this priority**: mesma prioridade da primeira, e pelo mesmo motivo que a plataforma existe. Uma rodada que gasta dinheiro e não mostra o que fez é indistinguível de uma rodada que não rodou — e a diferença só apareceria na fatura. É também a fatia vertical: sem esta tela, a US1 é infraestrutura sem consumidor visível.

**Independent Test**: disparar uma rodada com pessoas nos três desfechos — gerada, pulada por falta de trabalho novo, pulada por falta de material — e verificar que a tela nomeia os três, com contagem por motivo.

**Acceptance Scenarios**:

1. **Given** uma rodada concluída, **When** quem administra abre a tela, **Then** vê a data, a contagem de perfis gerados, a de pulados por motivo, a de falhas, e o total de entrada consumida.
2. **Given** que uma pessoa foi pulada, **When** quem administra procura por quê, **Then** o motivo é nomeado — sem trabalho novo suficiente, sem material que passe nos pisos, ou perfil ainda recente demais — e nunca agregado num "não elegível".
3. **Given** que a organização não tem credencial de provedor, **When** a rodada chega a hora, **Then** ela **não** executa, a tela diz que não executou e por quê, e nenhum perfil é gerado com a conta de outra organização.
4. **Given** que uma geração falhou, **When** quem administra abre a tela, **Then** a falha aparece nomeada, com a pessoa e o motivo, e **não** como uma rodada bem-sucedida com menos gente.

---

### User Story 3 - Mudar os limiares sem mexer no código (Priority: P2)

Quem administra ajusta quanto trabalho novo justifica um texto novo, e de quanto em quanto tempo um perfil envelhece o bastante para valer regerar, sem depender de uma nova versão da aplicação.

**Why this priority**: os números vêm de uma medição de um mês, num tenant. Eles vão estar errados para outro tenant, e um número que só muda com deploy é um número que ninguém corrige.

**Independent Test**: alterar o limiar na base de conhecimento, disparar a rodada e verificar que o conjunto de pessoas geradas muda de acordo, sem recompilar.

**Acceptance Scenarios**:

1. **Given** o limiar de trabalho novo em 10 tarefas, **When** ele passa para 3, **Then** a rodada seguinte gera para as pessoas que fecharam entre 3 e 9 tarefas, e a tela reflete a mudança.
2. **Given** um limiar inválido — negativo, zero, ou ausente —, **When** a base de conhecimento é validada, **Then** a validação recusa, e a rodada anterior continua valendo em vez de rodar com valor indefinido.

---

### Edge Cases

- **A organização nunca ligou a geração automática.** Nada executa, e a tela diz que está desligada — que é diferente de "executou e não gerou ninguém". Confundir as duas faria uma organização acreditar que não há quem gerar quando na verdade ninguém ligou.
- **A organização não tem credencial de provedor.** A rodada não executa para essa organização, e o motivo é dito na tela. Uma organização sem chave própria **não** pode cair na chave do processo: a conta de uma pagaria pela outra.
- **A chave existe e o provedor recusa no meio da rodada.** As pessoas já geradas continuam gravadas, a rodada é encerrada com o motivo registrado, e a tela distingue "rodada não executou" de "rodada parou no meio".
- **Uma pessoa falha e as outras não.** A falha é dela, e não da rodada. As demais continuam.
- **A rodada anterior ainda está executando quando a próxima é disparada.** A segunda não começa. Duas rodadas simultâneas gerariam dois perfis do mesmo material, e a tabela somente-acréscimo os guardaria os dois.
- **A pessoa deixou de ser observada** — a ferramenta que a trazia teve a observação encerrada. Ela não entra na rodada: gerar texto novo sobre quem a plataforma não observa mais afirmaria sobre um registro que parou. E a condição é reavaliada **no momento da geração**, não só no da seleção: uma rodada de trinta pessoas leva dezenas de minutos, e a observação pode ser encerrada no meio dela.
- **A pessoa entrou depois da última rodada e já passa nos pisos.** Ela entra na primeira rodada seguinte, mesmo sem perfil anterior — não há "trabalho novo desde o último perfil" quando não há perfil, e o critério que vale é o piso de material.
- **O relógio do servidor muda de mês em fuso diferente do da organização.** A rodada tem um único momento de referência declarado, e não um por fuso.

## Requirements *(mandatory)*

### Quando a rodada acontece

- **FR-001**: A plataforma MUST executar a rodada de geração **uma vez por mês**, por conta própria, sem interação humana. A cadência mensal é da **rodada**, e não de cada perfil: quem gera texto novo em cada rodada é decidido pela `FR-006`, e é por isso que uma rodada mensal convive com um M de três meses.
- **FR-001a**: O momento da rodada MUST ser um só, declarado, e MUST NOT depender do fuso de cada organização: **dia 1 de cada mês, às 03:00 no fuso do servidor**. Um momento por fuso faria a mesma rodada existir várias vezes, e a proibição da `FR-003` deixaria de significar.
- **FR-002**: A rodada MUST ser disparada por agendamento **próprio**, e MUST NOT ser acoplada à sincronização de fontes. Sincronizar é observar; gerar perfil é interpretar. Acoplar as duas faria toda observação custar dinheiro, e o sync executa muito mais de uma vez por mês.
- **FR-003**: Duas rodadas do mesmo tenant MUST NOT executar simultaneamente, **incluindo as disparadas a mão**. A segunda MUST ser recusada com motivo, e não enfileirada em silêncio. Isto cobre também a rodada que demora mais que o intervalo até a próxima: a automática seguinte é recusada, e a recusa aparece na tela.
- **FR-004**: A rodada MUST ser disparável manualmente por **quem administra**. *(Emenda de 2026-08-16, decisão da pessoa mantenedora)*: a rodada manual MUST gerar para **todas** as pessoas com material — a regra de mudança da `FR-006` não se aplica a ela. Pedir a mão já é a decisão de escrever; a regra de mudança existe para a rodada que ninguém pediu. Os pulos que permanecem são os de fato, não de critério: sem material (`FR-005`) e observação encerrada (`FR-008`). O custo disso MUST aparecer na tela antes do clique, porque uma rodada completa foi medida em ~1,63M tokens de entrada.
- **FR-004a**: Ligar a geração automática MUST disparar uma primeira rodada **imediatamente**, sem esperar o próximo dia 1. Quem liga precisa ver o efeito do ato; esperar um mês para descobrir se funcionou transforma a espera em dúvida sobre a plataforma.

### Quem entra na rodada

- **FR-005**: A plataforma MUST gerar perfil apenas para quem passa nos pisos de material da feature 026. Quem não passa MUST ser pulado, e o motivo MUST ser "sem material", nunca "falhou".
- **FR-006**: Na rodada **automática**, a plataforma MUST NOT gerar perfil novo quando o material da pessoa não mudou o suficiente desde o recorte do perfil vigente. *(Escopo emendado em 2026-08-16: a rodada manual não passa por esta regra — ver `FR-004`.)* O critério de mudança MUST ser: **tarefas concluídas depois do fim do recorte do perfil vigente ≥ N**, **ou** perfil vigente gerado há mais de **M**. Os dois extremos são declarados de propósito: a contagem parte do **fim do recorte** — a última data que o texto vigente alcança —, e a idade parte da **data de geração**, que é a data que a tela exibe. Os dois ramos existem porque cobrem gente diferente: N alcança quem trabalhou muito e cujo texto ficou para trás; M alcança quem trabalhou pouco e cujo texto ficaria parado para sempre se só N valesse.
- **FR-007**: Quem nunca teve perfil e passa nos pisos MUST entrar na rodada, sem depender do critério de mudança — não há recorte anterior contra o qual comparar.
- **FR-008**: Pessoa cuja observação foi encerrada MUST NOT entrar na rodada.
- **FR-009**: Os valores de **N** e **M** MUST vir da base de conhecimento versionada, e MUST NOT estar no código. Valor ausente ou inválido MUST reprovar a validação da base, e MUST NOT ser substituído por padrão embutido — um padrão silencioso faria a rodada usar um número que ninguém escolheu.

### A credencial do provedor

- **FR-010**: A credencial do provedor de modelo MUST ser **por organização**, gravada cifrada em repouso, e conferida contra o provedor antes de ser aceita.
- **FR-011**: A rodada de uma organização MUST usar a credencial **daquela** organização. Quando a organização não tiver credencial própria, a rodada MUST NOT executar para ela, ainda que exista chave no ambiente do processo — a chave do ambiente é da instalação, e usá-la faria a conta de uma organização pagar pela outra.
- **FR-012**: A tela de credencial MUST nomear de onde a chave em uso vem: gravada para a organização, herdada do ambiente do processo, ou inexistente. As três MUST ser visualmente distinguíveis, porque pedem ações diferentes.
- **FR-013**: A chave MUST NOT aparecer em log, em mensagem de erro, ou em qualquer tela depois de gravada — apenas os quatro últimos caracteres, para distinguir uma chave de outra.

> **Esta seção corrige a `FR-021` da feature 026**, que exigia a credencial **do ambiente**. O ambiente continua valendo como origem para desenvolvimento, e deixa de valer para a geração automática de uma organização. A razão é a que a 026 não tinha como enxergar: geração sob demanda é um clique de uma pessoa, e geração automática é uma conta sendo debitada todo mês.

### O que a rodada deixa registrado

- **FR-014**: Cada rodada MUST gravar: quando começou, quando terminou, quantas pessoas foram consideradas, quantas geradas, quantas puladas **por motivo**, quantas falharam, e o total de tokens de **entrada e de saída** consumidos. Os motivos de pulo MUST ser exatamente estes **três**, e MUST NOT ser agregados: **sem material** (não passa nos pisos da 026), **sem trabalho novo** (não atinge N e o perfil é mais novo que M) e **observação encerrada**. **Falha na geração não é motivo de pulo**: é desfecho próprio, contado à parte — pular é a plataforma decidindo não escrever, e falhar é ela ter tentado e não conseguido. A rodada MUST gravar também os **quatro últimos caracteres da chave** que usou — é o que torna a `SC-006` verificável a partir do registro, e não por inspeção de código.


> **Corrigido em 2026-08-20 — issue #454.** A versão anterior pedia só os **tokens de entrada**, e isso não fechava com a `FR-021`: ela manda medir o **custo** de uma rodada, e token de saída é cobrado a taxa mais alta que o de entrada. A soma de entrada não permite chegar ao valor.
>
> O número já chegava: o mapa `usage` do provedor carrega as duas contagens, e `GenerateWorker` lia uma e descartava a outra. Não é requisição nova.
>
> **As duas ficam separadas, e nunca somadas.** Um total agregado não serve para calcular nada, porque as taxas diferem. E a plataforma **não** converte token em dinheiro: a taxa é do provedor, muda sem aviso e varia por modelo — gravá-la faria a plataforma afirmar um preço que ela não observa. Mesma regra que mantém `merged_check_state` cru.
>
> As quatro rodadas gravadas antes desta correção ficam com a saída **nula**, nunca zero. A resposta do provedor não é preservada, então não há de onde recuperar — e a ausência fica nomeada em vez de virar zero na soma histórica.- **FR-015**: Um perfil gerado pela rodada MUST ser indistinguível, em conteúdo e proveniência, de um perfil pedido a mão. A origem do pedido MUST ser gravada junto do perfil e MUST aparecer **na tela da rodada**, e MUST NOT aparecer na aba da pessoa nem alterar como o texto é apresentado — quem lê um perfil não deve ter razão para confiar mais num ou noutro.
- **FR-016**: Falha de uma pessoa MUST NOT encerrar a rodada. **Falha de credencial** — chave recusada ou sem permissão — MUST encerrar a rodada, porque a próxima pessoa falharia pelo mesmo motivo. Limite de taxa e falha transitória de rede MUST NOT encerrar: a pessoa é marcada como falha e a rodada continua. A tela MUST distinguir "encerrada no meio" de "não executou".
- **FR-016a**: Quem falhou numa rodada MUST voltar a ser considerado na rodada seguinte pelo critério normal da `FR-006`, sem tratamento especial. Uma fila de repetição própria criaria um segundo caminho de geração, e dois caminhos divergem.
- **FR-017**: A plataforma MUST exibir a rodada mais recente e as anteriores a quem administra, com os números da `FR-014`, **restritas à própria organização**.
- **FR-017a**: Os registros de rodada MUST ser somente-acréscimo, como os perfis, e MUST NOT ser expurgados nesta versão. Uma rodada apagada leva junto a única resposta para "por que o perfil desta pessoa parou em março".

### Quem decide que o texto existe

- **FR-018**: A geração automática MUST ser ligada **por organização**, por quem administra, e MUST valer para toda pessoa que passe nos pisos de material. Não há entrada nem saída por pessoa nesta versão. **Decisão da pessoa mantenedora em 2026-08-16**, pela mesma razão que sustenta a `FR-023` da 026: o perfil serve para encontrar quem sabe fazer algo, e cobertura irregular elimina esse uso.
- **FR-018a**: A geração automática MUST nascer **desligada** em toda organização, inclusive nas que já existem quando a feature sobe. Um deploy MUST NOT fazer texto passar a existir sobre ninguém: sem um ato, a `FR-019` não teria autor para registrar, e a automação seria um estado sem dono.
- **FR-018b**: Quem administra MUST poder **desligar** a geração automática, e o desligamento MUST valer a partir da próxima rodada — rodada em execução não é interrompida no meio, porque metade das pessoas geradas seria um estado que a tela não sabe nomear.
- **FR-018c**: A subida desta feature MUST deixar toda organização existente com a geração **desligada**. É requisito de dados, e não intenção: uma organização que já existe não pode acordar gerando texto.
- **FR-019**: A plataforma MUST registrar **quem** ligou ou desligou a geração automática de uma organização e **quando**, guardando as duas coisas — a automação não pode ser um estado sem autor, e "quem desligou" é a pergunta que aparece quando os perfis param de aparecer. É a única pessoa identificável por trás de todo texto que a rodada produzir.

### Custo

- **FR-020**: A plataforma MUST exibir os **tokens de entrada** consumidos por cada rodada, para que o custo seja um número visível e não uma surpresa na fatura.
- **FR-020a**: Não há teto de custo por rodada nesta versão, e isso é **decisão declarada**, não omissão: um teto que parasse a rodada no meio produziria uma organização com metade das pessoas atualizadas e nenhuma explicação do critério de corte. A contenção é a `FR-006`, que decide quem entra antes de gastar.
- **FR-021**: A plataforma MUST recontar o custo de uma rodada completa depois da saída das tarefas em aberto do material, **antes** de os limiares serem fixados. Fixar N e M sobre a medição antiga escolheria o corte com o número errado.

### O que acumula

- **FR-022**: Cada geração MUST ler o **histórico inteiro observado** da pessoa, e MUST NOT se restringir ao que entrou desde o perfil anterior. A divisão em três períodos por volume, da feature 026, continua valendo — o que a `FR-022` proíbe é reduzir a entrada ao delta, não mudar como o histórico é dividido. Um texto escrito só sobre os últimos três meses falaria de um recorte, não de uma trajetória, e a trajetória é metade do que a 026 entrega.
- **FR-023**: A regra de não apagar perfil anterior é a `FR-015` da feature 026, e MUST continuar valendo sem alteração. Esta feature não a redefine; registra que ela pesa mais aqui — com geração automática, os perfis passam a formar uma série temporal que ninguém montou de propósito, e apagar qualquer ponto dela é apagar a única leitura que a série oferece.

### A tela, e o que ela precisa carregar

- **FR-024**: A tela da rodada MUST ser **própria**, separada da tela de credencial e da de sincronizações. As três respondem perguntas diferentes — com que conta trabalhamos, o que foi coletado, e o que foi interpretado —, e juntá-las contraria o princípio X da constituição.
- **FR-025**: Os números da rodada exibidos na tela MUST ser marcados como **observados**, com marca que leve texto além da cor, conforme o design system. Ausência MUST ser nomeada, nunca desenhada como zero: "a organização nunca ligou" e "a rodada executou e não gerou ninguém" são fatos diferentes.
- **FR-026**: A interface desta feature MUST falar inglês, como as demais telas da plataforma.
- **FR-027**: O registro operacional da rodada MUST conter tenant, identificador da rodada, contagens e motivos, e MUST NOT conter a chave nem o material enviado ao provedor — o material é texto de tarefas de pessoas reais, e log não é lugar dele.

### Key Entities

- **Rodada de geração**: uma execução da geração automática num tenant. Guarda início, fim, quem foi considerado, quem foi gerado, quem foi pulado e por qual motivo, quem falhou, e o consumo de entrada. É o que permite responder "o que aconteceu em agosto" depois que agosto passou.
- **Motivo de pulo**: o porquê de uma pessoa não ter gerado texto numa rodada. São **quatro**, e a lista é fechada: sem material, sem trabalho novo, observação encerrada, falha na geração. São fatos diferentes com ações diferentes, e agregá-los em "não elegível" apagaria a diferença.
- **Estado da automação**: se a geração automática de uma organização está ligada, quem a ligou ou desligou por último, e quando. É o único ato humano por trás de todo texto que a rodada produzir, e por isso não pode ser um booleano sem autor.
- **Credencial do provedor**: a chave de uma organização junto ao provedor de modelo. Guarda o provedor, a base, o modelo escolhido, quando foi conferida, e os quatro últimos caracteres. Não guarda histórico de segredo — segredo antigo guardado é superfície de ataque sem uso.
- **Limiares de perfil**: os valores N e M, versionados na base de conhecimento junto dos pisos de material da 026, porque são a mesma categoria de decisão: quanto de evidência justifica um texto.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Passado um mês sem ninguém clicar em nada, toda pessoa que teve trabalho novo acima do limiar tem perfil mais recente que o do mês anterior.
- **SC-002**: Numa rodada sobre a base medida em 2026-08-16, **no máximo 6 das 34 pessoas** geram texto novo com N=10 — o restante é pulado por motivo nomeado. Este número é derivado dos limiares vigentes: se a recontagem da `FR-021` levar a outro N, `SC-002` MUST ser corrigido junto, e não descumprido.
- **SC-003**: Nenhuma rodada gera dois perfis da mesma pessoa a partir do mesmo material.
- **SC-004**: A tela da rodada exibe, sem nenhuma interação além de abri-la, os **nove** números da `FR-014` — início, fim, consideradas, geradas, puladas por cada um dos **três** motivos, falhas e tokens. Nenhum deles exige consultar log, banco ou outra tela.
- **SC-005**: Nenhuma pessoa pulada aparece na tela sem motivo, e nenhum motivo aparece agregado com outro.
- **SC-006**: Nenhuma rodada de uma organização consome a credencial de outra, nem a do ambiente do processo — verificável com duas organizações, uma com chave e outra sem.
- **SC-007**: O custo de uma rodada completa é conhecido em número antes de os limiares serem fixados, e o número é o medido depois da saída das tarefas em aberto.
- **SC-008**: Uma falha do provedor no meio da rodada nunca produz uma tela que pareça sucesso com menos gente.
- **SC-009**: O recorte declarado de toda geração começa na **primeira tarefa observada** da pessoa, e nunca na data do perfil anterior. Verificável comparando o início do recorte de duas gerações consecutivas: ele não anda para frente.
- **SC-010**: Numa instalação que sobe a versão sem ninguém fazer nada, **nenhum** perfil é gerado. A primeira geração automática de uma organização tem sempre um ato humano registrado antes dela.

## A decisão da `FR-018`, e o resíduo dela

**Decidido em 2026-08-16 pela pessoa mantenedora: a geração automática vale para a organização inteira, ligada por quem administra.** As alternativas consideradas e recusadas:

| Opção | Por que não |
|---|---|
| desligamento por pessoa | a decisão continuaria sendo de quem administra, e a pessoa precisaria saber que o texto existe para pedir para sair — meia garantia com o dobro de mecanismo |
| entrada explícita por pessoa | cobertura irregular, e o valor de encontrar quem sabe fazer algo — razão declarada da `FR-023` — some para quem não entrou |
| aviso à pessoa descrita | exige um canal de aviso que a plataforma não tem; é feature nova dentro desta |

**O resíduo, registrado para que a próxima versão saiba o que herdou.** A 026 já havia registrado um: texto de máquina sobre uma pessoa, legível por todo o tenant, sem caminho de resposta. Esta feature soma o terceiro lado — **o texto passa a existir sem que ninguém peça**, todo mês, sobre todo mundo que passe nos pisos.

A `FR-018a` é o que sobrou de contenção: a automação nasce desligada, então existe **um** ato humano, com autor e data, antes do primeiro texto de cada organização. É pouco, e é honesto dizer que é pouco — uma assinatura cobre todas as pessoas da organização, e nenhuma delas assinou.

Três consequências práticas:

- as recusas da `FR-007` e da `FR-008` da 026 — nada de senioridade, nada de gênero, nada de comparação entre pessoas — deixam de ser contenção de um texto pedido e passam a ser contenção de um texto **automático**. Cada uma vale agora para textos que ninguém revisou antes de existirem;
- a regra de mudança da `FR-006` é o que impede a automação de virar volume: sem ela, a plataforma escreveria todo mês sobre quem não trabalhou, e o histórico deixaria de servir para comparar duas datas;
- **o pedido de remoção do próprio perfil continua sem resposta**, e agora com mais material para remover. A 026 já apontava isso como o item mais provável de voltar como requisito; esta decisão aumenta a probabilidade em vez de reduzi-la.

## Assumptions

- **A geração deixa de ser sob demanda.** A 026 assumiu explicitamente o contrário — *"a geração é sob demanda, não automática"* —, e esta feature reverte essa suposição. A razão do assumido continua verdadeira e é exatamente o que a regra de mudança da `FR-006` existe para conter: gerar para quem não teve trabalho novo produz texto que ninguém pediu e ninguém lerá.
- **O botão de gerar a mão continua existindo.** A automação cobre o caso comum; quem quer um perfil agora continua podendo pedir.
- **"Mensal" é a cadência da rodada, não a de cada perfil.** A rodada olha todo mundo uma vez por mês; quem gera texto novo é decidido pela `FR-006`. Sem essa distinção, "mensal" e "regra de mudança" se contradizem.
- **Os valores iniciais são N=10 tarefas e M=3 meses.** M foi decidido em 2026-08-16; N=10 é o corte que a medição da mesma data sustenta — geraria 6 das 34 pessoas por trabalho novo. Os dois nascem de uma medição de um tenant, e são revisáveis: revisá-los é decisão registrada na base de conhecimento, nunca ajuste no código. A `FR-021` obriga a recontagem do custo antes de eles serem fixados, e se a recontagem mudar o número, `SC-002` muda junto.
- **A cadência é mensal e o M é trimestral, e isso não é contradição.** A rodada olha todo mundo uma vez por mês; quem trabalhou fecha o ciclo mais rápido pela regra N, e quem trabalhou pouco é alcançado pelo M ao completar três meses.
- **A rodada usa o mesmo material, os mesmos pisos e o mesmo formato da 026.** Esta feature muda **quando** o texto é escrito, e não **o que** ele diz.
- **O formato-alvo de sete seções está fora do escopo**, assim como qualquer caminho de contestação do texto pela pessoa descrita. Os dois são features próprias, e misturá-los aqui impediria julgar esta.
- **O provedor responde 34 gerações seguidas sem degradar.** Medido na validação de 2026-08-15, cada geração levou de 25 a 60 segundos; uma rodada completa leva de 15 a 35 minutos. A suposição é que o provedor não impõe limite de taxa nessa cadência — e a `FR-016` existe justamente porque ela pode estar errada.
- **A credencial por organização já está implementada nesta branch** — schema cifrado, conferência contra o provedor antes de gravar, e tela em `/ai`. Esta spec a incorpora como parte da feature e declara o que faltava: o comportamento da rodada quando a organização não tem chave.
