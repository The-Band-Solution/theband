# Feature Specification: Perfil de competências e evolução

**Feature Branch**: `056-perfil-de-competencias`

**Created**: 2026-08-15

**Status**: Draft

**Input**: User description: "Perfil de competências e evolução na página da pessoa. Uma aba mostrando as habilidades principais que a evidência sustenta, como o trabalho mudou ao longo do tempo, onde há destaque e onde a evidência é rala, envelheceu ou o trabalho trava. O texto é escrito por um modelo de linguagem a partir das descrições das tarefas concluídas e em aberto, e é derivado — não observado."

## Por que esta feature existe

Quem coordena o trabalho precisa responder três perguntas sobre cada pessoa da equipe: **em que ela é boa, como isso mudou, e onde ainda não há evidência**. Hoje a resposta mora na memória de quem acompanhou de perto, e por isso não escala, não se confere e some quando a pessoa que lembrava troca de time.

A plataforma já observa o trabalho: 2949 pares pessoa-tarefa concluída, com descrição textual em quase todos. O que falta é ler esse material e devolvê-lo em forma legível.

**E aqui está o risco que esta spec existe para conter.** Um texto sobre uma pessoa, escrito por uma máquina, lido por quem decide alocação, é o artefato mais fácil de transformar em julgamento sem lastro. Três medições de 2026-08-15 mostram por quê:

| medição | o que ela impede de afirmar |
|---|---|
| **1298 de 2949** descrições foram escritas por outra pessoa, não por quem executou | que o texto revele como a pessoa comunica ou pensa |
| **355 issues** têm dois ou mais designados | que o resultado seja atribuível a uma pessoa só |
| o corpo mediano das descrições do projeto foi de **216 para 1310 caracteres** entre 2025-01 e 2026-06 | que crescimento de texto individual seja crescimento da pessoa |

A terceira é a mais traiçoeira: sem uma linha de base do projeto por período, **todo perfil conclui que a pessoa aprendeu a documentar**, e todos concluem isso no mesmo mês — o mês em que o time mudou de convenção.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ler o perfil de uma pessoa (Priority: P1)

Quem coordena abre a página de uma pessoa da equipe, entra na aba de perfil e lê, em três minutos, quais são as habilidades principais dela, como o trabalho mudou desde que começou a ser observado, e o que merece atenção. Sai sabendo em que frentes a evidência já existe.

**Why this priority**: é a feature. Sem esta história não há nada — as outras protegem esta de produzir texto errado.

**Independent Test**: com uma pessoa que tenha material suficiente, abrir a aba e verificar que o resumo nomeia habilidades concretas, que o texto distingue mudança da pessoa de mudança do time, e que a origem do texto está declarada antes dele.

**Acceptance Scenarios**:

1. **Given** uma pessoa com 97 tarefas concluídas com descrição, **When** a aba é aberta, **Then** o resumo abre com uma linha de três a cinco habilidades nomeadas em termos técnicos concretos, e nenhuma delas é categoria genérica como "backend" ou "DevOps".
2. **Given** que o perfil foi gerado por um modelo, **When** a aba é exibida, **Then** o bloco aparece **hachurado e rotulado como derivado**, com o modelo, a data e o recorte de entrada visíveis **antes** do texto.
3. **Given** que o corpo mediano das descrições da pessoa cresceu na mesma proporção do projeto, **When** o texto fala de evolução, **Then** ele atribui o crescimento à convenção do time, e **não** à pessoa.
4. **Given** uma pessoa cujo trabalho não mudou de domínio em nenhum período, **When** a aba é aberta, **Then** o texto diz que não mudou, e não constrói progressão.

---

### User Story 2 - Recusar quando não há material (Priority: P1)

Quem coordena abre a aba de uma pessoa com pouco registro e recebe uma recusa que diz **quanto** material existe e **por que** não basta — em vez de um perfil de aparência normal construído sobre nada.

**Why this priority**: mesma prioridade da primeira, e pelo mesmo motivo que a plataforma existe. Um perfil sobre 41 descrições, das quais a maioria vazia, sai com a mesma confiança de um sobre 97 completas. Quem lê não tem como distinguir, e é justamente aí que o texto vira dano.

**Independent Test**: com `costabeber` — 100 tarefas concluídas, 41 com corpo, mediana zero caracteres — abrir a aba e verificar que não há perfil, e que a mensagem traz os números.

**Acceptance Scenarios**:

1. **Given** uma pessoa com menos de 15 tarefas concluídas com descrição, **When** a aba é aberta, **Then** nenhum perfil é exibido, e a tela diz quantas tarefas com descrição existem e o que se pode dizer com elas.
2. **Given** uma pessoa cujo material se concentra num único período, **When** a aba é aberta, **Then** a tela recusa falar de **evolução**, e diz em qual período falta registro.
3. **Given** uma recusa, **When** quem lê a examina, **Then** ela é atribuída ao **registro**, e não à pessoa — a frase não sugere que a pessoa produziu pouco.

---

### User Story 3 - Separar destaque de lacuna (Priority: P2)

Quem coordena precisa saber não só onde a pessoa é forte, mas onde a evidência é fina — e precisa que a segunda coisa não seja lida como defeito.

**Why this priority**: é o que torna o perfil útil para desenvolvimento e não só para alocação. Depende da P1 existir, por isso vem depois.

**Independent Test**: verificar que os domínios de destaque atendem a um critério declarado, e que as lacunas aparecem classificadas por forma, cada uma com o que a caracteriza.

**Acceptance Scenarios**:

1. **Given** um domínio com seis ou mais tarefas, presente em pelo menos dois períodos e com evidência no período mais recente, **When** o perfil é gerado, **Then** ele aparece como destaque.
2. **Given** um domínio que atende a apenas dois dos três critérios, **When** o perfil é gerado, **Then** ele aparece como lacuna, e a tela diz **qual** critério faltou.
3. **Given** um domínio ausente do período mais recente, **When** ele é apresentado, **Then** o texto diz **"não observado desde <mês>"**, e nunca "abandonou" ou "regrediu".
4. **Given** tarefas em aberto há mais de 90 dias, **When** o perfil é exibido, **Then** elas aparecem listadas com título e idade, porque é a única parte que vira ação imediata.

---

### User Story 4 - Regerar e ver o que mudou (Priority: P3)

Quem coordena, ou a própria pessoa, pede um perfil novo depois de meses de trabalho, e o perfil anterior não é perdido.

**Why this priority**: o valor aparece com o tempo, não na primeira geração. Um perfil de agosto e outro de dezembro contam algo que nenhum dos dois conta sozinho.

**Independent Test**: gerar duas vezes com material diferente e verificar que ambas as versões continuam acessíveis, cada uma com sua data e seu recorte.

**Acceptance Scenarios**:

1. **Given** um perfil existente, **When** alguém pede regeração, **Then** o novo perfil é gravado sem apagar o anterior, e a data de cada um fica visível.
2. **Given** um perfil gerado há meses, **When** a aba é aberta, **Then** a tela diz **quantas tarefas novas** entraram desde a geração, para que quem lê saiba se o texto está velho.

---

### Edge Cases

- **A pessoa não tem tarefa alguma designada.** A aba diz que não há designação vigente — que é diferente de não haver trabalho, e diferente de haver pouco.
- **O material é grande demais para uma geração.** O recorte precisa ser declarado: quantas tarefas entraram e quantas ficaram de fora, e por qual critério.
- **A geração falha.** A aba mostra o perfil anterior, se houver, dizendo que a regeração falhou — nunca uma tela vazia que pareça ausência de material.
- **A geração devolve texto vazio.** É falha, e é tratada como falha. Gravar vazio produziria um perfil que afirma nada com a autoridade de um perfil.
- **A pessoa muda de login no GitHub.** O perfil segue a identidade da plataforma, e não o login, senão a troca apaga o histórico.
- **Duas pessoas na mesma tarefa.** A tarefa entra no material das duas, marcada como compartilhada, e nenhuma das duas recebe crédito exclusivo por ela.

## Requirements *(mandatory)*

### O que a aba mostra

- **FR-001**: A aba MUST exibir, no topo do perfil, uma linha de **três a cinco habilidades**, cada uma nomeando uma capacidade técnica concreta em até seis palavras. Categoria genérica, ferramenta isolada e qualidade pessoal MUST NOT aparecer nessa linha.
- **FR-002**: A aba MUST exibir um resumo em **texto corrido**, com um trecho para as forças, um para a evolução e um para o que merece atenção.
- **FR-003**: O resumo MUST NOT conter identificador de tarefa. As seções seguintes MUST carregar a evidência.
- **FR-004**: A aba MUST exibir os domínios de destaque segundo um critério declarado na tela, e MUST dizer qual critério faltou nos domínios que ficaram de fora.
- **FR-005**: A aba MUST classificar cada lacuna por forma — pouca evidência, evidência antiga, ou trabalho que trava — e MUST enquadrá-la como lacuna **do registro**, nunca como lacuna de competência.
- **FR-006**: A aba MUST listar as tarefas em aberto há mais de 90 dias, com título e idade.

### O que a aba recusa afirmar

- **FR-007**: O perfil MUST NOT afirmar qualidade de código, confiabilidade como traço da pessoa, esforço, dificuldade, ou nível de senioridade. O escopo das tarefas atribuídas reflete o nível que o time já presumia, e usá-lo para inferir nível é circular.
- **FR-008**: O perfil MUST NOT atribuir gênero à pessoa. Nenhum pronome de gênero é declarado na base, e deduzi-lo do nome erra com pessoa real.
- **FR-009**: O perfil MUST NOT comparar a pessoa com outras, nem produzir ordenação entre pessoas — a cobertura da observação é irregular, e o ranking mediria a coleta.
- **FR-010**: Toda afirmação sobre **mudança** MUST ser comparada com a linha de base do projeto nos mesmos meses. Quando a mudança da pessoa acompanhar a do projeto, o perfil MUST atribuí-la à convenção do time.
- **FR-011**: A aba MUST exibir uma seção nomeando o que o material **não alcança** — revisão de código, mentoria, discussão de arquitetura, e todo trabalho que não vira tarefa — com os números do caso: quantas descrições foram escritas por terceiro, e quantas tarefas foram compartilhadas.

### A proveniência

- **FR-012**: O perfil MUST ser exibido como **derivado**, com o preenchimento hachurado e o rótulo em texto, conforme o design system. Cor sozinha MUST NOT carregar essa distinção.
- **FR-013**: A aba MUST exibir, **antes** do texto do perfil, o modelo que o escreveu, a data da geração e o recorte de entrada — quantas tarefas concluídas e quantas em aberto.
- **FR-014**: Os números observados exibidos junto do perfil — contagens, séries, idades — MUST ser marcados como **observados**, e visualmente distintos do texto derivado.
- **FR-015**: O perfil MUST ser gravado com a proveniência completa, e uma geração nova MUST NOT apagar a anterior.
- **FR-016**: A aba MUST informar quantas tarefas novas foram observadas desde a geração exibida.

### O piso de evidência

- **FR-017**: A plataforma MUST recusar gerar perfil quando a pessoa tiver menos de 15 tarefas concluídas com descrição, e MUST recusar falar de **evolução** quando algum dos três períodos tiver menos de 5 tarefas.
- **FR-018**: A recusa MUST dizer quantas tarefas com descrição existem, como se distribuem pelos períodos, e o que se pode afirmar com elas.
- **FR-019**: A recusa MUST ser atribuída ao registro, e MUST NOT sugerir que a pessoa produziu pouco.

### O egresso de dado

- **FR-020**: A geração envia título e descrição de tarefas para um provedor externo de modelo de linguagem. A plataforma MUST declarar isso na tela, no momento em que a geração é pedida.
- **FR-021**: A credencial do provedor MUST vir do ambiente, MUST NOT ser gravada em repositório, e MUST NOT aparecer em log nem em mensagem de erro — provedores devolvem a chave dentro do texto de alguns erros.
- **FR-022**: Uma falha na geração MUST ser exibida como falha. Resposta vazia MUST NOT ser gravada como perfil.

### Quem vê

- **FR-023**: Toda pessoa autenticada do tenant MUST poder ler o perfil de qualquer pessoa do
  mesmo tenant. Decisão da pessoa mantenedora em 2026-08-15: o perfil serve para **encontrar
  quem sabe fazer algo**, e restringir a leitura à coordenação eliminaria esse uso.
- **FR-024**: Não há mecanismo de contestação nesta versão — decisão da mesma data. A pessoa
  descrita lê o próprio perfil como qualquer outra, e não tem, nesta versão, caminho registrado
  para discordar dele.

**O resíduo desta combinação, registrado para que a próxima versão saiba o que herdou.** Um
texto escrito por máquina sobre uma pessoa, legível por todo o tenant, sem caminho de resposta
para quem é descrito, concentra em `FR-005` a `FR-011` toda a contenção do risco: se o perfil
afirmar o que não deve, a única defesa é o texto não ter sido escrito. Não há segunda barreira.

Três consequências práticas:

- as recusas de `FR-007` e `FR-008` deixam de ser higiene e passam a ser **requisito de
  segurança** — cada uma delas é uma frase que ninguém poderá pedir para tirar;
- `FR-011`, a seção do que o material não alcança, é o que substitui a contestação: ela precisa
  aparecer na mesma tela, e não atrás de um clique;
- se alguma pessoa pedir remoção do próprio perfil, **não há hoje como atender sem mexer no
  código**. Isso é o item mais provável de voltar como requisito.

### Key Entities

- **Perfil derivado**: o texto gerado sobre uma pessoa num momento. Guarda o modelo, a data, o recorte de entrada e o próprio texto. Não é atualizado — uma geração nova é outro perfil, e os dois coexistem, porque comparar duas datas é parte do valor.
- **Recorte de entrada**: o conjunto de tarefas que alimentou uma geração — quantas concluídas, quantas em aberto, o intervalo de meses, quantas escritas por terceiro, quantas compartilhadas. É o que permite dizer, depois, sobre o que aquele texto falava.
- **Linha de base do projeto**: por mês, quantas tarefas o projeto criou e concluiu, o corpo mediano das descrições e a proporção de títulos tipados. Existe para separar mudança da pessoa de mudança do time, e é a mesma para todas as pessoas.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Quem coordena identifica as três principais habilidades de uma pessoa em menos de 30 segundos após abrir a aba, sem rolar a página.
- **SC-002**: Nenhum perfil é produzido para pessoa com menos de 15 tarefas concluídas com descrição — verificável sobre as 25 pessoas com 30 ou mais tarefas designadas.
- **SC-003**: Em toda pessoa cujo crescimento de texto acompanhe o do projeto, o perfil atribui o crescimento ao time. Verificável comparando as duas razões em cada perfil gerado.
- **SC-004**: Nenhum perfil contém pronome de gênero, afirmação de senioridade, ou comparação com outra pessoa.
- **SC-005**: Toda afirmação de domínio no perfil aponta para tarefas que existem no recorte declarado — nenhuma referência a identificador inexistente.
- **SC-006**: Quem lê distingue, sem clicar em nada, qual parte da tela foi observada e qual foi concluída por um modelo.
- **SC-007**: Uma falha de geração nunca produz tela vazia nem perfil vazio: ou o perfil anterior continua visível com aviso, ou a falha é nomeada.

## Assumptions

- **A geração é sob demanda, não automática.** Um perfil de cada pessoa gerado a cada sincronização gastaria chamadas de modelo sem ninguém pedir, e produziria texto que ninguém leu. Quem quer, pede.
- **O material vem das tarefas designadas, e só delas.** Commits, revisões e comentários não entram nesta versão; a designação é o vínculo que a plataforma já observa com proveniência.
- **Três períodos, divididos por volume e não por duração.** Períodos de mesma duração comparariam quatro tarefas com noventa. Isto foi validado com dado real antes da spec.
- **O envio a provedor externo foi decidido pela pessoa mantenedora**, com credencial fora do repositório. A spec registra o egresso e a obrigação de declará-lo; não reabre a decisão.
- **A linha de base é do tenant inteiro**, e não do repositório ou do projeto. Uma pessoa que trabalha em quatro repositórios seria comparada a uma base diferente em cada um, e a comparação deixaria de significar.
- **O piso de 15 tarefas com descrição e 5 por período** vem da medição de 2026-08-15, e é revisável — mas revisá-lo é decisão registrada, não ajuste silencioso.
- **A identidade é a da plataforma**, não o login do GitHub, para que troca de login não apague o histórico de perfis.
