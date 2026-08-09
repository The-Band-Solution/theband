# Feature Specification: Coleta de pessoas e equipes do GitHub para a Enterprise Ontology

**Feature Branch**: `001-github-eo-ingestion`

**Created**: 2026-08-09

**Status**: Draft

**Input**: Fundação de coleta multitenant do The Band, entregando de ponta a ponta o caminho de uma organização até as pessoas que o sistema conhece — incluindo cadastro de ferramentas e credenciais por organização, coleta do GitHub, preservação de proveniência e tela de consulta.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Conectar uma ferramenta com credencial protegida (Priority: P1)

Uma organização cliente é cadastrada na plataforma. Um administrador dessa organização declara que ela usa o GitHub, informa em qual instância (o serviço público ou uma instalação própria) e fornece as credenciais de acesso. A plataforma verifica se as credenciais funcionam antes de aceitá-las, e a partir daí a chave nunca mais é exibida.

**Why this priority**: Sem uma ferramenta conectada e uma credencial válida, nenhuma outra parte da feature existe. É também onde mora o maior risco: uma credencial vazada dá acesso ao código-fonte da organização.

**Independent Test**: Cadastrar uma organização, conectar o GitHub com uma credencial real e ver a conexão confirmada como válida. Depois recarregar a tela e confirmar que a chave não é mais legível. Entrega valor por si só: a organização passa a ter um registro auditável de quais ferramentas e quais contas de serviço estão em uso.

**Acceptance Scenarios**:

1. **Given** uma organização cliente cadastrada, **When** o administrador conecta o GitHub informando instância e credencial válida, **Then** a plataforma confirma o acesso e registra a ferramenta como conectada.
2. **Given** um administrador conectando uma ferramenta, **When** a credencial informada é inválida ou não tem as permissões necessárias, **Then** a conexão é recusada com explicação do que faltou, e nada é gravado.
3. **Given** uma ferramenta já conectada, **When** qualquer pessoa consulta seu cadastro, **Then** a credencial aparece apenas por uma identificação parcial que permita distinguir uma chave da outra, nunca em forma utilizável.
4. **Given** uma organização que usa duas contas de serviço no mesmo GitHub, **When** o administrador conecta a segunda credencial, **Then** ambas coexistem e podem ser usadas ou desativadas independentemente.
5. **Given** uma credencial que deixou de funcionar, **When** a plataforma tenta usá-la, **Then** a ferramenta é marcada como precisando de atenção, com a data e o motivo da falha, sem interromper as demais ferramentas da organização.

---

### User Story 2 - Conhecer as pessoas e equipes de uma organização (Priority: P2)

Com a ferramenta conectada, o administrador dispara uma sincronização. A plataforma consulta o GitHub e passa a conhecer a organização, as pessoas que têm conta ali e as equipes existentes, incluindo quem integra cada equipe. Executar a sincronização de novo não duplica nada.

**Why this priority**: É a entrega central — o sistema deixa de estar vazio e passa a conhecer o quadro de pessoas. Depende da US1, mas é o que justifica a feature existir.

**Independent Test**: Disparar a sincronização para uma organização real e conferir que a quantidade de pessoas e equipes conhecidas corresponde ao que existe no GitHub. Rodar de novo e confirmar que os números não mudam.

**Acceptance Scenarios**:

1. **Given** uma ferramenta conectada e válida, **When** o administrador dispara a sincronização, **Then** a plataforma passa a conhecer a organização, suas pessoas e suas equipes.
2. **Given** uma sincronização já concluída, **When** o administrador dispara a mesma sincronização de novo, **Then** nenhum registro é duplicado e nenhum registro existente é alterado sem que o dado de origem tenha mudado.
3. **Given** uma sincronização interrompida no meio, **When** ela é retomada, **Then** o trabalho recomeça de onde parou, sem repetir o que já havia sido coletado.
4. **Given** uma conta identificada como automação e não como pessoa, **When** ela é encontrada em uma equipe, **Then** ela é registrada e classificada separadamente, sem contar como pessoa.
5. **Given** uma equipe do GitHub, **When** suas pessoas são registradas, **Then** o vínculo entre pessoa e equipe é preservado com o nível de acesso observado, e permanece marcado como pendente de papel organizacional.
6. **Given** o limite de uso da API sendo atingido durante a coleta, **When** a plataforma percebe a proximidade do limite, **Then** ela pausa e retoma sozinha, sem perder o progresso e sem falhar a sincronização.

---

### User Story 3 - Rastrear de onde veio cada informação (Priority: P3)

Qualquer pessoa autorizada abre a lista de pessoas e equipes que a plataforma conhece para sua organização e vê, para cada registro, de qual ferramenta veio, qual o identificador na origem e quando foi coletado.

**Why this priority**: É o que distingue a plataforma de um relatório qualquer, e é a forma de provar que a feature funciona sem ler código ou teste. Depende das duas anteriores.

**Independent Test**: Após uma sincronização, abrir a tela e conferir que cada pessoa e cada equipe exibe origem, identificador externo e data de coleta, e que os números batem com a sincronização.

**Acceptance Scenarios**:

1. **Given** uma sincronização concluída, **When** o usuário abre a lista de pessoas, **Then** vê cada pessoa com sua origem, seu identificador na ferramenta e a data da coleta.
2. **Given** uma sincronização concluída, **When** o usuário abre a lista de equipes, **Then** vê cada equipe, quem a integra e quantos vínculos ainda estão sem papel organizacional atribuído.
3. **Given** um usuário pertencente a uma organização, **When** ele consulta qualquer lista, **Then** vê exclusivamente dados da própria organização.

---

### Edge Cases

- **Credencial revogada durante uma sincronização em andamento**: o trabalho é interrompido de forma controlada, o progresso parcial é preservado e a ferramenta é marcada como precisando de atenção.
- **Organização sem nenhuma equipe**: a sincronização conclui com sucesso registrando apenas a organização e suas pessoas; ausência de equipes não é erro.
- **Pessoa removida de uma equipe entre duas coletas**: o vínculo anterior é preservado como observação histórica e marcado como não mais observado. Nada é apagado — a plataforma não recebe evento de remoção, apenas percebe a ausência.
- **A mesma conta aparece em várias equipes**: é uma pessoa só, com vários vínculos.
- **Conta sem nome preenchido no GitHub**: a pessoa é registrada mesmo assim, identificada pelo login.
- **Instância própria de GitHub sem recursos que o serviço público tem**: a sincronização registra o que está disponível e reporta explicitamente o que não pôde ser coletado.
- **Duas credenciais da mesma organização com permissões diferentes**: a coleta usa a credencial escolhida e o resultado reflete o que aquela credencial enxerga, ficando registrado qual foi usada.
- **Sincronização disparada quando já existe uma em andamento para a mesma ferramenta**: a segunda não inicia em paralelo; o usuário é informado de que já há uma em curso.

## Requirements *(mandatory)*

### Functional Requirements

#### Cadastro e credenciais

- **FR-001**: A plataforma MUST permitir cadastrar organizações clientes, cada uma sendo uma fronteira de isolamento sobre a qual todo dado coletado é atribuído.
- **FR-002**: A plataforma MUST permitir que uma organização declare quais ferramentas utiliza, registrando o tipo da ferramenta e a instância específica em que ela roda.
- **FR-003**: O cadastro de ferramentas MUST acomodar outros tipos além do GitHub sem exigir mudança estrutural, ainda que apenas o GitHub seja coletável nesta entrega.
- **FR-004**: A plataforma MUST permitir mais de uma credencial para a mesma ferramenta na mesma organização, cada uma ativável e desativável independentemente.
- **FR-005**: A credencial MUST ser cifrada pela própria plataforma antes de ser gravada, de modo que a leitura direta da base de dados não a torne utilizável. A chave mestra usada para cifrar MUST vir da configuração do ambiente e MUST NOT residir na base de dados nem no repositório de código.
- **FR-005a**: A plataforma MUST recusar-se a iniciar quando a chave mestra não estiver configurada, em vez de operar gravando credenciais sem proteção.
- **FR-005b**: A troca da chave mestra MUST ser possível sem perda das credenciais já cadastradas, ainda que exija um procedimento explícito de recifragem.
- **FR-006**: A plataforma MUST validar a credencial contra a ferramenta no momento do cadastro, recusando o registro quando o acesso falhar ou as permissões forem insuficientes.
- **FR-007**: A plataforma MUST NOT exibir a credencial após o cadastro, permitindo apenas uma identificação parcial suficiente para distinguir uma credencial de outra.
- **FR-008**: A plataforma MUST NOT registrar a credencial em relatórios de erro, registros de atividade ou qualquer dado coletado e armazenado.
- **FR-009**: A plataforma MUST detectar credenciais que deixaram de funcionar, marcando a ferramenta como precisando de atenção com data e motivo, sem afetar as demais ferramentas da organização.

#### Coleta

- **FR-010**: A plataforma MUST coletar, a partir de uma ferramenta conectada do tipo GitHub, a organização, as contas de usuário e as equipes existentes, incluindo quem integra cada equipe.
- **FR-011**: A plataforma MUST preservar o dado original recebido da ferramenta, sem alteração, antes de qualquer transformação.
- **FR-012**: Todo registro conhecido pela plataforma MUST guardar de qual ferramenta veio, de qual instância dela, qual seu identificador na origem e quando foi coletado.
- **FR-013**: A transformação de dado externo em conhecimento da plataforma MUST seguir os mapeamentos semânticos declarados na base de conhecimento, e não regras embutidas no código de coleta.
- **FR-014**: Uma sincronização executada duas vezes MUST levar ao mesmo resultado, sem duplicar registros e sem alterar registros cuja origem não mudou.
- **FR-015**: A plataforma MUST registrar o progresso da coleta de forma a retomar de onde parou após uma interrupção, sem repetir trabalho já concluído.
- **FR-016**: A plataforma MUST respeitar os limites de uso impostos pela ferramenta, pausando antes de atingi-los e retomando automaticamente.
- **FR-017**: A plataforma MUST permitir reprocessar dados já coletados aplicando mapeamentos corrigidos, sem consultar a ferramenta novamente.
- **FR-018**: A plataforma MUST impedir que duas sincronizações da mesma ferramenta rodem simultaneamente.

#### Fidelidade semântica

- **FR-019**: A plataforma MUST registrar o vínculo observado entre pessoa e equipe como evidência pendente de papel, e MUST NOT tratá-lo como alocação formal, porque o papel organizacional não existe na ferramenta de origem.
- **FR-020**: A plataforma MUST registrar o nível de acesso da pessoa na equipe como atributo do vínculo, e MUST NOT interpretá-lo como papel organizacional.
- **FR-021**: A plataforma MUST informar quantos vínculos estão sem papel atribuído, tratando esse número como medida de lacuna de conhecimento e não como erro.
- **FR-022**: A plataforma MUST classificar contas de automação separadamente das pessoas.
- **FR-023**: A plataforma MUST registrar equipes como equipes da organização, e MUST NOT tratá-las como equipes de projeto na ausência de vínculo explícito com projetos ou repositórios.
- **FR-024**: A plataforma MUST deixar sem preenchimento as datas de início e fim do vínculo com a equipe, por não serem informadas pela ferramenta de origem.
- **FR-025**: A plataforma MUST NOT unificar contas distintas em uma mesma pessoa nesta entrega.

#### Consulta e isolamento

- **FR-026**: Usuários MUST conseguir consultar as pessoas e as equipes conhecidas para sua organização, vendo origem, identificador externo e data de coleta de cada registro.
- **FR-027**: Toda consulta a dados coletados MUST restringir-se à organização do usuário.
- **FR-028**: A plataforma MUST relatar, ao fim de cada sincronização, quantos registros foram coletados, quantos foram criados, quantos foram atualizados e quantos foram ignorados, com o motivo.

### Key Entities

- **Organização cliente**: a empresa ou grupo que usa a plataforma. É a fronteira de isolamento: todo dado coletado pertence a exatamente uma delas.
- **Ferramenta conectada**: declaração de que uma organização cliente usa determinada ferramenta, em determinada instância.
- **Credencial de acesso**: meio de autenticação de uma ferramenta conectada. Cifrada em repouso, não legível após o cadastro, com estado de validade e histórico de falhas.
- **Sincronização**: uma execução de coleta, com início, fim, progresso, resultado e a credencial que foi usada.
- **Dado de origem**: o conteúdo recebido da ferramenta, preservado sem alteração.
- **Proveniência**: o vínculo entre um registro conhecido pela plataforma e sua origem — ferramenta, instância, identificador externo, momento da coleta e mapeamento aplicado.
- **Organização observada**: a organização como existe na ferramenta de origem, distinta da organização cliente da plataforma.
- **Pessoa**: agente humano identificado a partir de uma conta observada.
- **Equipe**: coletivo de pessoas mantido pela organização observada.
- **Vínculo observado de pessoa a equipe**: registro de que uma pessoa integra uma equipe, com o nível de acesso observado, pendente de papel organizacional.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Um administrador consegue conectar uma ferramenta e ter a credencial validada em menos de 2 minutos, sem consultar documentação.
- **SC-002**: Após a primeira sincronização de uma organização real, 100% das pessoas e equipes existentes na origem estão registradas na plataforma.
- **SC-003**: Uma segunda sincronização, sem mudança na origem, cria 0 registros novos e altera 0 registros existentes.
- **SC-004**: 100% dos registros exibidos na consulta apresentam origem, identificador externo e data de coleta.
- **SC-005**: Nenhuma credencial é recuperável em forma utilizável a partir da base de dados, dos registros de atividade ou da interface — verificado por inspeção dirigida.
- **SC-006**: Uma sincronização interrompida e retomada consulta a origem no máximo uma vez a mais, por página, do que a execução que não foi interrompida.
- **SC-007**: Uma correção de mapeamento é aplicada a dados já coletados sem nenhuma consulta adicional à ferramenta de origem.
- **SC-008**: Um usuário de uma organização não consegue, por nenhum caminho da interface, visualizar dado de outra organização — verificado com duas organizações povoadas simultaneamente.
- **SC-009**: A sincronização de uma organização com até 100 pessoas e 20 equipes conclui sem intervenção manual, mesmo atingindo o limite de uso da ferramenta durante a execução.
- **SC-010**: Ao fim da sincronização, o número de vínculos pendentes de papel organizacional é apresentado explicitamente.

## Assumptions

- **Perfis de acesso**: assume-se que existe a noção de administrador da organização, único perfil autorizado a conectar ferramentas e gerenciar credenciais; os demais usuários apenas consultam. Um modelo de permissões mais rico fica para depois.
- **Disparo da sincronização**: assume-se disparo manual sob demanda nesta entrega. Agendamento periódico é natural, mas não é necessário para provar o caminho e fica fora de escopo.
- **Escopo da coleta de pessoas**: assume-se coletar tanto os membros da organização observada quanto os integrantes de cada equipe, registrando de qual observação veio cada pessoa. Os dois conjuntos não coincidem, e restringir a um deles daria uma visão parcial sem que o usuário soubesse.
- **Ausência não é remoção**: assume-se que um registro que deixa de aparecer na origem é marcado como não mais observado, nunca apagado. A plataforma existe para preservar rastreabilidade histórica.
- **Uma credencial por sincronização**: assume-se que cada execução usa uma credencial específica, registrada junto ao resultado, já que credenciais diferentes enxergam conjuntos diferentes.
- **Idioma**: assume-se interface e mensagens em português do Brasil, como o restante da base de conhecimento.
- **Volume inicial**: assume-se organizações de até algumas centenas de pessoas nesta entrega; volumes maiores são plausíveis mas não dimensionam a solução agora.
- **Dependência da base de conhecimento**: a feature depende dos mapeamentos semânticos e das regras de derivação já declarados e validados em `priv/knowledge_base/`, em particular os de organização, pessoa e equipe do GitHub.
- **Proteção de credenciais**: decidido cifrar na própria plataforma, com chave mestra vinda do ambiente, em vez de depender de cofre de segredos externo. A justificativa é que o cofre externo passaria a ser pré-requisito de qualquer ambiente, inclusive o de desenvolvimento, para uma feature que ainda precisa provar o caminho de ponta a ponta. O custo aceito é que a chave mestra vira o segredo crítico único, e sua rotação exige recifragem — coberto por FR-005b. Migrar para cofre externo depois permanece possível e seria registrado como decisão arquitetural própria.
- **Fora de escopo confirmado**: reconciliação de identidade entre contas, cadastro de papéis organizacionais, promoção do vínculo a alocação formal, demais ontologias, outras ferramentas, medidas e indicadores.
