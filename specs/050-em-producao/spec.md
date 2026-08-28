# Feature Specification: O The Band em produção

**Feature Branch**: `050-em-producao`

**Created**: 2026-08-28

**Status**: Especificada — backlog (execução adiada por decisão de 2026-08-28:
"faça o deploy depois"; clarificações de hospedagem, domínio e backup já resolvidas)

**Input**: User description: "Colocar o The Band em produção: a plataforma acessível
por HTTPS num endereço estável para as pessoas do tenant, com autenticação real
(feature 045) na porta. O deploy não roda seeds de desenvolvimento (a senha padrão é
recusada em produção), a chave mestra e credenciais vivem fora do repositório,
migrações rodam no deploy, e os dados sobrevivem a releases (backup e restauração
testados). Inclui a feature 048 já especificada como parte do polimento do mesmo
sprint."

## O problema

Tudo o que a plataforma faz hoje, faz num laptop. A porta existe (045), os escopos
existem, os dados existem — mas só para quem senta na máquina onde o `mix phx.server`
roda. Para a organização, uma plataforma que ninguém alcança não observa nada: as
pessoas do tenant precisam abrir um endereço, entrar com as credenciais que já têm, e
ver os mesmos painéis — de qualquer lugar, a qualquer hora, sobrevivendo a releases.

Produção não é "o mesmo, hospedado": é um regime diferente. O que em desenvolvimento
é conveniência (seeds com senha padrão, chave mestra num `.env` local, banco
descartável) em produção é vulnerabilidade ou perda de dados. Esta feature entrega o
regime, não só o endereço.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A plataforma num endereço estável (Priority: P1)

Uma pessoa do tenant abre o endereço da plataforma num navegador, de fora da rede de
quem desenvolve. A conexão é cifrada (HTTPS), a tela de login da 045 aparece, as
credenciais que quem administra criou funcionam, e os painéis respondem com os dados
reais do tenant. Quem administra publica uma versão nova e as pessoas continuam
entrando no mesmo endereço — sessões válidas sobrevivem ao release, e as migrações de
banco correm como parte da publicação, nunca como passo manual esquecível.

**Why this priority**: é a feature. Sem o endereço alcançável, nada do resto existe
para a organização.

**Independent Test**: de uma rede que não é a de desenvolvimento, abrir o endereço,
entrar, ver um painel com dado real; publicar um release com uma migração pendente e
conferir que ela rodou e que o login continua valendo.

**Acceptance Scenarios**:

1. **Given** o endereço publicado, **When** uma pessoa abre por HTTP simples, **Then**
   é levada ao HTTPS — nunca uma página sem cifra.
2. **Given** credenciais válidas criadas por quem administra, **When** a pessoa entra,
   **Then** vê os painéis do seu escopo (045), com os dados reais do tenant.
3. **Given** uma versão nova com migração de banco pendente, **When** quem administra
   publica, **Then** a migração roda antes de a versão atender, e o dado anterior
   permanece.
4. **Given** uma sessão válida, **When** um release é publicado, **Then** a pessoa
   continua logada — release não desloga o tenant inteiro.
5. **Given** a plataforma fora do ar durante uma publicação, **When** a pessoa tenta
   abrir, **Then** a janela é curta (ver SC-002) e ao voltar tudo está onde estava.

---

### User Story 2 - Os dados sobrevivem (Priority: P2)

A organização confia dados de meses de coleta à plataforma. Quem administra sabe que
existe uma cópia recente e — mais importante — já **viu uma restauração funcionar**:
o teste da cópia é restaurá-la, não listá-la. Se a máquina de produção morrer, o
caminho de volta é conhecido, documentado e ensaiado.

**Why this priority**: perda de dados é o único defeito sem conserto. Vem antes de
qualquer polimento, logo depois de existir produção.

**Independent Test**: gerar a cópia, restaurá-la num banco vazio, apontar uma
instância para ele e conferir que uma pessoa entra e vê os mesmos painéis.

**Acceptance Scenarios**:

1. **Given** a produção com dados reais, **When** a rotina de cópia roda, **Then**
   uma cópia íntegra e datada existe fora da máquina de produção.
2. **Given** uma cópia existente, **When** quem administra a restaura num banco
   vazio, **Then** a plataforma sobe sobre ele e os painéis mostram os mesmos números
   de antes.
3. **Given** a rotina de cópia falhando, **When** a falha acontece, **Then** ela é
   visível para quem administra — falha de backup silenciosa é o sucesso silencioso
   mais caro que existe.

---

### User Story 3 - A produção recusa o regime de desenvolvimento (Priority: P2)

O que é conveniência no laptop é recusado em produção, com mensagem que diz o porquê:
os seeds de desenvolvimento (senha padrão) não rodam; a plataforma não sobe sem a
chave mestra, e a chave vive fora do repositório e fora da imagem publicada; nenhuma
credencial (banco, provedores, chave) aparece em código, log ou tela.

**Why this priority**: junto da US2 — a porta da 045 só vale se a chave da porta não
estiver debaixo do tapete.

**Independent Test**: tentar subir produção sem a chave mestra (recusa com
orientação); rodar os seeds em regime de produção (recusa); varrer imagem e logs por
segredo (nada).

**Acceptance Scenarios**:

1. **Given** o regime de produção, **When** os seeds de desenvolvimento rodam,
   **Then** são recusados com mensagem — a senha `senha-de-dev` não existe em
   produção (já implementado na 045; aqui é conferido no ambiente real).
2. **Given** a chave mestra ausente, **When** a plataforma tenta subir, **Then**
   recusa dizendo o que falta e onde configurar — nunca sobe cifrando com chave
   vazia.
3. **Given** a produção no ar, **When** se inspecionam logs, páginas de erro e a
   imagem publicada, **Then** nenhum segredo aparece — nem chave, nem senha de banco,
   nem token de provedor.

---

### Edge Cases

- Release com migração que falha no meio: a versão anterior continua atendendo, e o
  banco não fica num estado intermediário sem caminho de volta.
- Disco da máquina de produção cheio (a coleta cresce): quem administra é avisado
  antes de a plataforma parar, não depois.
- Certificado HTTPS expirando: renovação sem ato manual, e o vencimento nunca chega
  ao navegador das pessoas.
- Duas publicações quase simultâneas: a segunda espera ou recusa — nunca duas versões
  migrando o mesmo banco ao mesmo tempo.
- O relógio da máquina de produção importa: coleta e painéis carimbam tempo; produção
  mantém o relógio certo (NTP) — desvio de relógio viraria dado errado.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A plataforma MUST estar acessível num endereço público estável, sempre
  por HTTPS; acesso por HTTP simples é redirecionado, nunca servido.
- **FR-002**: O endereço MUST apresentar a autenticação da 045 como única porta:
  nenhuma rota de dados responde sem sessão válida (varredura SC-001 da 045 vale no
  ambiente real).
- **FR-003**: Publicar uma versão nova MUST ser um procedimento repetível e
  documentado, que roda as migrações pendentes antes de atender e não exige passo
  manual sobre o banco.
- **FR-004**: Sessões válidas MUST sobreviver a releases — o segredo que assina a
  sessão é estável entre versões e vive fora do repositório.
- **FR-005**: A chave mestra e toda credencial (banco, provedores) MUST viver fora do
  repositório e fora da imagem publicada; a plataforma MUST recusar subir sem a chave
  mestra, com mensagem que orienta.
- **FR-006**: Os seeds de desenvolvimento MUST ser recusados no regime de produção
  (comportamento da 045, conferido no ambiente real).
- **FR-007**: Uma cópia dos dados MUST ser gerada automaticamente em cadência diária,
  guardada fora da máquina de produção, e a falha da rotina MUST ser visível para quem
  administra.
- **FR-008**: A restauração MUST ser documentada e **ensaiada**: o procedimento
  escrito só é aceito depois de uma restauração real conferida contra os painéis.
- **FR-009**: Logs de produção MUST não conter segredo algum (chave, senha, token) —
  e MUST ser consultáveis por quem administra para diagnosticar um problema.
- **FR-010**: Quem administra MUST conseguir saber que a plataforma está no ar sem
  entrar nela (uma verificação de vida consultável), e a queda MUST ser detectável.
- **FR-011**: O procedimento de publicação MUST impedir duas migrações simultâneas
  sobre o mesmo banco.
- **FR-012**: A produção MUST rodar num **servidor alugado (VPS) operado via Docker**
  — decisão da pessoa mantenedora em 2026-08-28. Controle total e custo baixo; TLS,
  backup e monitoramento entram como procedimento desta feature (não há provedor
  gerenciado por trás). O provedor específico e o tamanho da máquina são decisão de
  planejamento, com requisitos mínimos declarados.
- **FR-013**: **Sem domínio próprio por ora** — decisão de 2026-08-28: um endereço
  derivado do provedor/da máquina basta, desde que estável e com HTTPS válido (FR-001
  não afrouxa). O desenho MUST permitir apontar um domínio próprio depois sem
  retrabalho — trocar o endereço não pode invalidar sessões nem exigir migração.
- **FR-014**: As cópias dos dados MUST usar o **backup gerenciado do provedor da
  hospedagem** (snapshot/backup automático do VPS, guardado fora da máquina) —
  decisão de 2026-08-28 — complementado pelo que FR-007/FR-008 exigem: cadência
  diária, falha visível, e restauração ensaiada de verdade. Se o backup do provedor
  não satisfizer a cadência ou o ensaio, o plano MUST acrescentar uma rotina própria
  em vez de afrouxar o requisito.

### Key Entities

Nenhuma entidade de domínio nova. A feature muda **onde e como** a plataforma roda,
não **o que** ela modela — o regime de produção (endereço, chave, cópia, release) é
infraestrutura declarada em documentação e procedimento, não em esquema.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Uma pessoa do tenant, de fora da rede de desenvolvimento, entra e vê um
  painel com dado real em menos de 2 minutos a partir do endereço — sem instrução
  além das credenciais.
- **SC-002**: Publicar um release leva menos de 15 minutos de procedimento e menos de
  2 minutos de indisponibilidade percebida — medidos numa publicação real.
- **SC-003**: Uma restauração completa a partir da cópia mais recente, ensaiada de
  verdade, termina com os painéis mostrando os mesmos números — e o ensaio está
  registrado com data.
- **SC-004**: Zero segredos no repositório, na imagem publicada e nos logs —
  verificado por varredura, não por leitura de código.
- **SC-005**: 100% das rotas de dados recusam acesso sem sessão no ambiente real — a
  varredura da 045 (27 rotas) reexecutada contra produção.
- **SC-006**: A rotina de cópia roda por 7 dias seguidos sem intervenção, e a cópia
  mais antiga do período restaura.

## Assumptions

- **A 045 é a porta** — nenhuma autenticação nova; produção expõe a que existe.
- **Um tenant em produção no início** — o multitenancy já existe no dado; o processo
  de criar tenant novo segue administrativo.
- **A escala é a de hoje**: dezenas de pessoas, coleta diária de três organizações.
  Produção dimensiona para isso, não para hipótese — crescer é feature futura, e o
  desenho não pode impedi-la.
- **A 048 acompanha o sprint, não esta spec**: já especificada em
  `specs/048-botao-sem-chave-desabilitado/`, entra no sprint 024 como item próprio de
  backlog — nada dela é duplicado aqui.
- **A 049 (entrar com GitHub) é candidata natural** a vir logo depois da produção
  existir, porque o retorno de OAuth exige endereço público estável — dependência
  desta, decisão de backlog.
- **Quem administra a produção é quem administra o tenant hoje** — não há equipe de
  operação separada; o procedimento é escrito para uma pessoa.
