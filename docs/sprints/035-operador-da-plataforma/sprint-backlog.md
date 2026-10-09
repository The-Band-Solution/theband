# Sprint 035 — O operador da plataforma

**Período**: a partir de 2026-10-03, quando termina a Sprint 034. A duração fica para a pessoa mantenedora decidir junto com a iteration.
**Feature**: [070 — o operador da plataforma](../../../specs/070-operador-da-plataforma/spec.md)
**Plano**: [plan.md](../../../specs/070-operador-da-plataforma/plan.md) · **Tarefas**: [tasks.md](../../../specs/070-operador-da-plataforma/tasks.md)

## Objetivo do sprint

Quem opera a plataforma suspende uma organização pela tela, com a razão e o segundo fator. Toda
sessão e todo token da organização caem na mesma transação, e reativar não devolve nenhum. Isso
fecha a #1009.

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md). As lições abertas que valem aqui entram como
**restrição**:

| Lição | Como está sendo aplicada |
|---|---|
| L42 — mensagem atrasada de telemetria entra na contagem seguinte | as guardas de telemetria (R10, SC-003; T041) drenam a caixa e se desligam antes de afirmar |
| L50 — teste que compara duas medidas precisa provar que mediu | toda captura tem o controle "a captura mediu alguma coisa" (T041, T049, T056) |
| L56 — filtrar telemetria pela `source` não alcança SQL cru | R10 e T041 afirmam também pelo texto do SQL (`"users"`), e não só pela `source` |
| L90 — contar só o vencedor da corrida não prova o perdedor | os testes de concorrência (A1, A5, O9, FR-014) afirmam o vencedor **e** a recusa do perdedor |
| L105 — o segredo chegou ao texto sem ninguém registrar | os códigos de definição, de guarda e de recuperação e o segredo TOTP nunca vão a log, flash nem redirect (T5); o filtro de parâmetros cobre os nomes de campo (A10) |
| L108 — features sem sprint backlog, e a aceitação sem lugar | este documento existe **antes** de qualquer código, e a US só fecha com aceitação |
| L109 — tarefa fechada "sem código" com o critério intacto | T002, T003 e T003a continuam abertas até a evidência estar colada na issue, mesmo com os PRs já mergeados |

## Sprint no GitHub

**Iteration**: **pendente**. As 74 issues foram criadas na Sprint 034 (`8808ca77`), que termina em
2026-10-03. Criar a iteration "Sprint 035" altera a configuração do projeto e é decisão da pessoa
mantenedora. Com ela criada, as 74 issues passam para lá.
**Projeto**: The Band (`PVT_kwDODHSRm84BAAnT`)

## User stories selecionadas

| # | User story | Tipo | Épico | Issue | Priority | Estimate | Critérios |
|---|---|---|---|---|---|---|---|
| US2 | O papel de operador existe, e não vaza dado de organização | User Story | [#1056](https://github.com/The-Band-Solution/theband/issues/1056) | [#1058](https://github.com/The-Band-Solution/theband/issues/1058) | P1 | | 4 cenários |
| US1 | Suspender uma organização, e as sessões caem de verdade | User Story | [#1056](https://github.com/The-Band-Solution/theband/issues/1056) | [#1057](https://github.com/The-Band-Solution/theband/issues/1057) | P1 (MVP) | | 3 cenários |

A US2 vem primeiro porque é pré-requisito da US1. A release só sai com as duas. `Estimate` em branco
quer dizer **desconhecido**, e não zero: não foi estimado.

## Tarefas

As 71, com a issue de cada uma. A tarefa herda a prioridade da US.

| # | Tarefa | Atende | Fase | Issue | Estado |
|---|---|---|---|---|---|
| T001 | Conferir os pré-requisitos já mergeados | épico | Fase 1 | [#1059](https://github.com/The-Band-Solution/theband/issues/1059) | a fazer |
| T002 | Esperar o merge da correção da espera paralela | épico | Fase 1 | [#1060](https://github.com/The-Band-Solution/theband/issues/1060) | a fazer |
| T003 | Esperar o merge da correção do custo na espera | épico | Fase 1 | [#1061](https://github.com/The-Band-Solution/theband/issues/1061) | a fazer |
| T003a | Esperar o merge da rotação que recifra todos os campos cifrados | épico | Fase 1 | [#1062](https://github.com/The-Band-Solution/theband/issues/1062) | a fazer |
| T004 | Medir o cabeçalho de IP no proxy de produção | épico | Fase 1 | [#1063](https://github.com/The-Band-Solution/theband/issues/1063) | a fazer |
| T005 | Decidir a forma da área do operador | épico | Fase 1 | [#1064](https://github.com/The-Band-Solution/theband/issues/1064) | feito |
| T006 | Abrir o sprint backlog e as issues | épico | Fase 1 | [#1065](https://github.com/The-Band-Solution/theband/issues/1065) | a fazer |
| T007 | Rebasear o trabalho sobre a integração | épico | Fase 1 | [#1066](https://github.com/The-Band-Solution/theband/issues/1066) | a fazer |
| T008 | Conferir as emendas de segurança nos contratos — feita em 2026-10-01 pelo agente `security`; seção "Conferência das emendas" em seguranca-autenticacao.md, os seis bloqueantes cobertos | épico | Fase 2 | [#1067](https://github.com/The-Band-Solution/theband/issues/1067) | feito |
| T009 | Pesquisar a implementação do TOTP — feita em 2026-10-01: NimbleTOTP == 1.0.0, hex.audit e deps.audit com código 0; sem QR (recomendação, decisão no protótipo T012) | épico | Fase 2 | [#1068](https://github.com/The-Band-Solution/theband/issues/1068) | feito |
| T010 | Avaliar a segurança do TOTP antes do código — feita em 2026-10-01 pelo agente `security`, que não escreveu o desenho; seguranca-totp.md: T1 alta e T2 média emendadas nos contratos, T1 virou T028a (bloqueante), T3 entrou em T021; o resto fica para T011 | épico | Fase 2 | [#1069](https://github.com/The-Band-Solution/theband/issues/1069) | feito |
| T011 | Emendar os contratos com o resultado do TOTP — feita em 2026-10-01 pelo agente `security`; seguranca-totp.md §3, "Emendas de T011", aponta o trecho de cada um (T4, T5, T6, T8; T9–T11 em plan.md "Riscos"; T12 novo, o passo 2 contando só em `failed_attempts`, mantido com a razão); cenários C14–C21 do código de guarda em §4. Limite: as emendas de T011 foram escritas e conferidas pelo mesmo agente — a conferência independente fica para a revisão do PR | épico | Fase 2 | [#1070](https://github.com/The-Band-Solution/theband/issues/1070) | feito |
| T012 | Prototipar as telas do operador | épico | Fase 2 | [#1071](https://github.com/The-Band-Solution/theband/issues/1071) | feito |
| T013 | Restringir o estado da organização | épico | Fase 2 | [#1072](https://github.com/The-Band-Solution/theband/issues/1072) | a fazer |
| T014 | Declarar as razões de suspensão na base — lista aprovada pela pessoa mantenedora em 2026-10-01, como em data-model §5 | épico | Fase 2 | [#1073](https://github.com/The-Band-Solution/theband/issues/1073) | a fazer |
| T015 | Declarar a cláusula de revogação só registrada | épico | Fase 2 | [#1074](https://github.com/The-Band-Solution/theband/issues/1074) | a fazer |
| T016 | Ensinar o log a dizer o operador e a calar o segredo | épico | Fase 2 | [#1075](https://github.com/The-Band-Solution/theband/issues/1075) | a fazer |
| T017 | Compartilhar a CSP entre as duas pipelines | épico | Fase 2 | [#1076](https://github.com/The-Band-Solution/theband/issues/1076) | a fazer |
| T018 | Criar as tabelas do operador | US2 | Fase 3 | [#1077](https://github.com/The-Band-Solution/theband/issues/1077) | a fazer |
| T019 | Provar que a concessão não se apaga nem se reescreve | US2 | Fase 3 | [#1078](https://github.com/The-Band-Solution/theband/issues/1078) | a fazer |
| T020 | Criar as colunas e a tabela do segundo fator | US2 | Fase 3 | [#1079](https://github.com/The-Band-Solution/theband/issues/1079) | a fazer |
| T021 | Escrever os schemas do contexto da plataforma | US2 | Fase 3 | [#1080](https://github.com/The-Band-Solution/theband/issues/1080) | a fazer |
| T022 | Conferir o código do segundo fator | US2 | Fase 3 | [#1081](https://github.com/The-Band-Solution/theband/issues/1081) | a fazer |
| T033 | Registrar os eventos de acesso do operador | US2 | Fase 3 | [#1082](https://github.com/The-Band-Solution/theband/issues/1082) | a fazer |
| T023 | Conferir a entrada do operador | US2 | Fase 3 | [#1083](https://github.com/The-Band-Solution/theband/issues/1083) | a fazer |
| T023a | Provar que a rotação da chave alcança o segredo TOTP | US2 | Fase 3 | [#1084](https://github.com/The-Band-Solution/theband/issues/1084) | a fazer |
| T024 | Provar a espera sob rajada paralela | US2 | Fase 3 | [#1085](https://github.com/The-Band-Solution/theband/issues/1085) | a fazer |
| T025 | Provar que a espera paga o custo do hash | US2 | Fase 3 | [#1086](https://github.com/The-Band-Solution/theband/issues/1086) | a fazer |
| T026 | Definir a senha e cadastrar o segundo fator | US2 | Fase 3 | [#1087](https://github.com/The-Band-Solution/theband/issues/1087) | a fazer |
| T027 | Provar o código de uso único sob concorrência | US2 | Fase 3 | [#1088](https://github.com/The-Band-Solution/theband/issues/1088) | a fazer |
| T028 | Provar o segundo fator na entrada | US2 | Fase 3 | [#1089](https://github.com/The-Band-Solution/theband/issues/1089) | a fazer |
| T029 | Abrir e conferir a sessão do operador | US2 | Fase 3 | [#1090](https://github.com/The-Band-Solution/theband/issues/1090) | a fazer |
| T030 | Conceder, reiniciar e revogar o papel | US2 | Fase 3 | [#1091](https://github.com/The-Band-Solution/theband/issues/1091) | a fazer |
| T030a | Provar a revogação e o reinício no meio do cadastro | US2 | Fase 3 | [#1092](https://github.com/The-Band-Solution/theband/issues/1092) | a fazer |
| T028a | Provar o limite próprio do segundo fator | US2 | Fase 3 | [#1093](https://github.com/The-Band-Solution/theband/issues/1093) | a fazer |
| T031 | Provar que conceder de novo não devolve credencial | US2 | Fase 3 | [#1094](https://github.com/The-Band-Solution/theband/issues/1094) | a fazer |
| T032 | Comandos de operação para o papel | US2 | Fase 3 | [#1095](https://github.com/The-Band-Solution/theband/issues/1095) | a fazer |
| T034 | Provar a paridade das duas autenticações | US2 | Fase 3 | [#1096](https://github.com/The-Band-Solution/theband/issues/1096) | a fazer |
| T035 | Guardar a sessão do operador no cookie próprio | US2 | Fase 3 | [#1097](https://github.com/The-Band-Solution/theband/issues/1097) | a fazer |
| T036 | Montar a área do operador no roteador | US2 | Fase 3 | [#1098](https://github.com/The-Band-Solution/theband/issues/1098) | a fazer |
| T037 | Provar que o 404 do operador é o de qualquer caminho | US2 | Fase 3 | [#1099](https://github.com/The-Band-Solution/theband/issues/1099) | a fazer |
| T038 | Provar os cabeçalhos da área do operador | US2 | Fase 3 | [#1100](https://github.com/The-Band-Solution/theband/issues/1100) | a fazer |
| T038a | Ler as organizações para a área do operador, do lado de `Tenants` | US2 | Fase 3 | [#1101](https://github.com/The-Band-Solution/theband/issues/1101) | a fazer |
| T039 | Telas de entrada, definição e cadastro | US2 | Fase 3 | [#1102](https://github.com/The-Band-Solution/theband/issues/1102) | a fazer |
| T040 | Tela da lista de organizações | US2 | Fase 3 | [#1103](https://github.com/The-Band-Solution/theband/issues/1103) | a fazer |
| T041 | Provar que o operador não lê domínio | US2 | Fase 3 | [#1104](https://github.com/The-Band-Solution/theband/issues/1104) | a fazer |
| T042 | Provar que o cookie do operador não abre domínio | US2 | Fase 3 | [#1105](https://github.com/The-Band-Solution/theband/issues/1105) | a fazer |
| T043 | Limitar as tentativas por IP | US2 | Fase 3 | [#1106](https://github.com/The-Band-Solution/theband/issues/1106) | a fazer |
| T044 | Criar o episódio de suspensão | US1 | Fase 4 | [#1107](https://github.com/The-Band-Solution/theband/issues/1107) | a fazer |
| T044a | O banco recusa estado sem episódio — trigger de constraint adiado (D1-a) | US1 | Fase 4 | [#1108](https://github.com/The-Band-Solution/theband/issues/1108) | a fazer |
| T045 | Provar que o episódio é um só e não se reescreve | US1 | Fase 4 | [#1109](https://github.com/The-Band-Solution/theband/issues/1109) | a fazer |
| T046 | Encerrar as sessões de uma organização | US1 | Fase 4 | [#1110](https://github.com/The-Band-Solution/theband/issues/1110) | a fazer |
| T046a | Trocar o estado da organização dentro de um `Multi`, do lado de `Tenants` | US1 | Fase 4 | [#1111](https://github.com/The-Band-Solution/theband/issues/1111) | a fazer |
| T047 | Revogar os tokens de uma organização suspensa | US1 | Fase 4 | [#1112](https://github.com/The-Band-Solution/theband/issues/1112) | a fazer |
| T048 | Ler as razões de suspensão da base | US1 | Fase 4 | [#1113](https://github.com/The-Band-Solution/theband/issues/1113) | a fazer |
| T049 | Suspender uma organização numa transação | US1 | Fase 4 | [#1114](https://github.com/The-Band-Solution/theband/issues/1114) | a fazer |
| T050 | Reativar uma organização sem devolver nada | US1 | Fase 4 | [#1115](https://github.com/The-Band-Solution/theband/issues/1115) | a fazer |
| T056 | Tela do histórico e do ato | US1 | Fase 4 | [#1116](https://github.com/The-Band-Solution/theband/issues/1116) | a fazer |
| T051 | Provar que suspender derruba sessões e tokens | US1 | Fase 4 | [#1117](https://github.com/The-Band-Solution/theband/issues/1117) | a fazer |
| T052 | Provar a corrida entre entrar e suspender | US1 | Fase 4 | [#1118](https://github.com/The-Band-Solution/theband/issues/1118) | a fazer |
| T053 | Provar que a aba aberta cai junto | US1 | Fase 4 | [#1119](https://github.com/The-Band-Solution/theband/issues/1119) | a fazer |
| T054 | Provar a revogação com o formulário aberto | US1 | Fase 4 | [#1120](https://github.com/The-Band-Solution/theband/issues/1120) | a fazer |
| T055 | Registrar os atos de plataforma no log | US1 | Fase 4 | [#1121](https://github.com/The-Band-Solution/theband/issues/1121) | a fazer |
| T057 | Medir o tempo do ato e a recusa em lote | US1 | Fase 4 | [#1122](https://github.com/The-Band-Solution/theband/issues/1122) | a fazer |
| T058 | Apagar as sessões vencidas do operador | épico | Fase 5 | [#1123](https://github.com/The-Band-Solution/theband/issues/1123) | a fazer |
| T059 | Escrever o roteiro de operação do operador | épico | Fase 5 | [#1124](https://github.com/The-Band-Solution/theband/issues/1124) | a fazer |
| T060 | Conferir a tela contra o protótipo | épico | Fase 5 | [#1125](https://github.com/The-Band-Solution/theband/issues/1125) | a fazer |
| T061 | Rodar o roteiro de validação e os gates | épico | Fase 5 | [#1126](https://github.com/The-Band-Solution/theband/issues/1126) | a fazer |
| T062 | Escrever a nota de riscos da release | épico | Fase 5 | [#1127](https://github.com/The-Band-Solution/theband/issues/1127) | a fazer |
| T063 | Derivar os modelos da feature | épico | Fase 5 | [#1128](https://github.com/The-Band-Solution/theband/issues/1128) | a fazer |
| T064 | Abrir o PR pelo template | épico | Fase 5 | [#1129](https://github.com/The-Band-Solution/theband/issues/1129) | a fazer |

## Fora do escopo deste sprint

Nada do `tasks.md` ficou de fora. Ficam fora **da feature** o que a spec já declara: a gestão de
`admin` dentro da organização (#568, spec 071), criar, apagar ou renomear organização, e qualquer
leitura de dado de domínio pelo operador.

## Riscos e dependências

- **T004 depende da pessoa mantenedora**: medir em produção se o Traefik do Dokploy sobrescreve
  `x-forwarded-for`. Sem a medição, o limite por IP (T043) não entra, e o A4 vai para a nota da release.
- **Riscos residuais declarados**, que vão para T062:
  - A8: mesma origem que as organizações, com CSP;
  - A17;
  - T9–T11: TOTP não resiste a phishing em tempo real, o código de recuperação não revoga o aparelho, e o relógio do servidor decide a janela;
  - G1: quem é dono das tabelas pode desligar o trigger D1-a. A aplicação migra com o mesmo `DATABASE_URL`;
  - G2: *write skew* por SQL cru.
- **Dependência nova**: `nimble_totp == 1.0.0`, auditada (`hex.audit` e `deps.audit` com código 0).
- **Rede instável com o GitHub em 2026-10-02**: os scripts de issue são idempotentes e repetem.

## Definition of Done do sprint

Além da DoD por tarefa:

- [ ] quality gates verdes (`mix gates`, código de saída 0)
- [ ] base de conhecimento válida (`platform.tenant_suspension`)
- [ ] cada guarda de segurança vista reprovando com o defeito injetado, com a evidência colada na issue
- [ ] a tela implementada é a do protótipo aprovado, conferida item a item contra `prototipo/PROMPT.md` §3
- [ ] issues encerradas, ou repriorizadas com justificativa; as US só com aceitação
- [ ] `sprint-review.md` escrito
- [ ] `licoes-aprendidas.md` atualizado
