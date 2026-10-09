# Sprint 036 — os papéis do banco

**Período**: 2026-10-03 a 2026-10-09, na mesma iteration da 070 (Sprint 035 no GitHub)
**Feature**: [071](../../specs/071-papeis-do-banco/spec.md) · **Plano**: [plan.md](../../specs/071-papeis-do-banco/plan.md)
**Issue de origem**: [#1131](https://github.com/The-Band-Solution/theband/issues/1131), segurança, achado G1 da 070

## Objetivo do sprint

O processo que serve deixa de conseguir desligar as guardas do banco, e a conferência diz isso
contra o ambiente.

## Lições aplicadas

| lição | como está sendo aplicada |
|---|---|
| L24 — o que só roda no ambiente limpo não é testado por quem já tem o ambiente | o papel não-dono nasce **no teste**, e o quickstart §3 roda no contêiner da release, e não só na suíte |
| L50 — o teste que compara precisa provar que mediu | toda tentativa afirma antes `current_user` e `rolsuper`; o controle positivo (A10) é por tentativa |
| L105 — o segredo chegou ao texto sem ninguém registrar | nenhuma URL nem senha em log, erro ou roteiro (FR-012); o A7 afirma a ausência da senha |
| L108 — feature sem sprint backlog | este documento existe antes do código, e as US só fecham com aceitação |
| L109 — tarefa fechada sem código e com o critério intacto | as três tarefas 👤 só fecham com a saída colada na issue; a #1131 só fecha com a conferência em vigor em produção |

## Sprint no GitHub

**Iteration**: a corrente do projeto The Band (`8808ca77`), como as issues foram criadas.
**Escopo**: a feature inteira. As três tarefas 👤 são da pessoa mantenedora.

## User stories

| # | user story | issue | Priority |
|---|---|---|---|
| US1 | A aplicação que serve não consegue desligar as guardas do banco | [#1141](https://github.com/The-Band-Solution/theband/issues/1141) | P1 |
| US2 | A migração continua acontecendo sozinha no deploy | [#1142](https://github.com/The-Band-Solution/theband/issues/1142) | P1 |
| US3 | Quem opera sabe criar os papéis, e o backup continua restaurável | [#1143](https://github.com/The-Band-Solution/theband/issues/1143) | P2 |

## Tarefas

| # | tarefa | atende | tipo | issue | estado |
|---|---|---|---|---|---|
| T001 | Conferir o estado de partida | — | Task | [#1144](https://github.com/The-Band-Solution/theband/issues/1144) | a fazer |
| T002 | Conceder os privilégios de quem serve | — | Task | [#1145](https://github.com/The-Band-Solution/theband/issues/1145) | a fazer |
| T003 | Provar que quem serve não desliga as guardas | — | Task | [#1146](https://github.com/The-Band-Solution/theband/issues/1146) | a fazer |
| T004 | Conferir no banco se a separação está em vigor | — | Task | [#1147](https://github.com/The-Band-Solution/theband/issues/1147) | a fazer |
| T005 | A suíte inteira como quem serve | US1 | Task | [#1148](https://github.com/The-Band-Solution/theband/issues/1148) | a fazer |
| T006 | Migrar e conceder com a credencial que migra | US2 | Task | [#1149](https://github.com/The-Band-Solution/theband/issues/1149) | a fazer |
| T007 | Os três estados sem a credencial que migra | US2 | Task | [#1150](https://github.com/The-Band-Solution/theband/issues/1150) | a fazer |
| T008 | O entrypoint com as duas credenciais | US2 | Task | [#1151](https://github.com/The-Band-Solution/theband/issues/1151) | a fazer |
| T009 | O aviso a cada subida | US2 | Task | [#1152](https://github.com/The-Band-Solution/theband/issues/1152) | a fazer |
| T010 | A conferência por rpc | US2 | Task | [#1153](https://github.com/The-Band-Solution/theband/issues/1153) | a fazer |
| T011 | Escrever o roteiro dos papéis | US3 | Task | [#1154](https://github.com/The-Band-Solution/theband/issues/1154) | a fazer |
| T012 | O ensaio de restauração com os papéis | US3 | Task | [#1155](https://github.com/The-Band-Solution/theband/issues/1155) | a fazer |
| T013 | 👤 Medir o papel de hoje em produção | US3 | Task | [#1156](https://github.com/The-Band-Solution/theband/issues/1156) | a fazer |
| T014 | 👤 Criar os papéis e transferir a posse | US3 | Task | [#1157](https://github.com/The-Band-Solution/theband/issues/1157) | a fazer |
| T015 | 👤 Configurar as duas credenciais no Dokploy | US3 | Task | [#1158](https://github.com/The-Band-Solution/theband/issues/1158) | a fazer |
| T016 | Escrever a nota de riscos da release | — | Task | [#1159](https://github.com/The-Band-Solution/theband/issues/1159) | a fazer |
| T017 | Rodar os gates e abrir o PR | — | Task | [#1160](https://github.com/The-Band-Solution/theband/issues/1160) | a fazer |

## Fora do escopo deste sprint

- **A #1140, a credencial no ambiente do contêiner (S5).** Foi decidido aceitar e declarar.
- **Revogar `TEMP` de `PUBLIC` (S10).** A defesa é o `search_path` conferido.

## Riscos e dependências

- **A Fase 6 depende de acesso à produção.** Sem ela, o código entra e a conferência diz "NÃO em
  vigor", e não há regressão: o primeiro estado de FR-008.
- **O CI roda PostgreSQL 17 e a produção 16** (S8).
- **As guardas reais da 070 ainda não estão em `development`.** O T003 usa guardas criadas no
  teste, e acrescenta as reais quando a pilha da 070 for mergeada.
