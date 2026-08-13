# Tarefas — Feature 015: quem escreveu a issue também é observado

**Spec**: [spec.md](spec.md) · **Plano**: [plan.md](plan.md) · **Branch**: `020-clicar-leva-a-pagina`
Sete tarefas em quatro fases. Sem migração, sem YAML novo.

## F1 — a identidade chega

### T001 Pedir o identificador do autor e dos designados
- **Pronta quando**: nada além do repositório.
- **Descrição**: em `priv/connectors/github/queries/issues.graphql`, trocar `author { login }` por
  `author { __typename login ... on User { id name } }` e `assignees` por
  `nodes { __typename id login name }`. O `__typename` **não é enfeite**: é o que
  `Mapper.account_type/1` usa para recusar `Bot` e `App` — FR-001, FR-004.
- **Feita quando**: a consulta pede identidade e tipo; o gate de validação da base passa.
- **Teste**: o payload simulado do teste de coleta traz `__typename` e `id`, e a asserção é sobre o
  que a coleta gravou — não sobre o texto da consulta.

## F2 — a pessoa nasce da coleta

### T002 Registrar quem escreveu, pelo caminho que já existe
- **Pronta quando**: T001 feita.
- **Descrição**: em `coletar_issues/2`, **antes** de gravar as issues do repositório, resolver os
  autores **e os designados** dos nós daquela página: guardar o payload como `github.user` com
  `RawData.store/1`, aplicar `Mapper.apply_mapping("github.user.to.eo.person", node)` e
  `Mapper.complete/3`, e gravar com `EO.upsert_person_from_source/2`. **É o mesmo caminho de
  `sync_github_eo`** — um segundo caminho de escrita discordaria do primeiro. FR-002, FR-003, FR-005.

  **Duas armadilhas de ordem, e as duas são da análise:**

  | Armadilha | Por que quebra |
  |---|---|
  | `ctx.pessoas` é montado **uma vez**, antes de todos os repositórios | a pessoa criada ao coletar o repositório #3 **não estaria no mapa** ao coletar o #4, e as issues dela ficariam sem vínculo até a coleta seguinte — sem erro nenhum |
  | `gravar_issue/3` lê `ctx.pessoas[login]` na **mesma passada** | registrar a pessoa depois de gravar a issue deixa `author_person_id` nulo mesmo com a pessoa existindo |

  Por isso: as pessoas do lote nascem **antes** das issues do lote, e o mapa é **reaproveitado
  acrescido** — nunca relido por issue, que seriam 4 529 consultas.

  **E vale para designado também**: `replace_assignees/3` grava `person_id` vindo do mesmo mapa —
  A3 da análise.
- **Feita quando**: uma coleta cujo autor não é membro cria a pessoa com `external_id` da origem; a
  issue grava `author_person_id` **na mesma execução**; a designação grava `person_id`; e um
  repositório coletado **depois** do que criou a pessoa também resolve o vínculo.
- **Teste**: `test/the_band/ingestion/autor_observado_test.exs` — coleta com autor externo, e a
  asserção é que a pessoa existe **com `external_id`**, não só que existe. Mais o caso da ordem:
  **dois** repositórios na mesma execução, o autor aparecendo primeiro no segundo, exigindo vínculo
  nos dois.

### T003 [P] Recusar o que não é pessoa
- **Pronta quando**: T002 feita.
- **Descrição**: nó cujo `account_type` não é `person` **não** vira pessoa. A classificação é
  `Mapper.account_type/1`, chamada — nunca reimplementada. FR-004.
- **Feita quando**: issue escrita por `dependabot[bot]` não cria pessoa; a contagem de pessoas não
  muda; e o login continua exibido.
- **Teste**: o mesmo arquivo — um autor `Bot` e um login com sufixo `[bot]`, exigindo contagem
  inalterada.

### T004 [P] Fixar a idempotência
- **Pronta quando**: T002 feita.
- **Descrição**: coletar duas vezes não cria pessoa de novo, e não reescreve `collected_at`. FR-009.
- **Feita quando**: a segunda coleta deixa a contagem igual e a data de primeira coleta intacta.
- **Teste**: comparar o mapa `{id => collected_at}` antes e depois da segunda coleta.

## F3 — trabalhar não é pertencer

### T005 Provar que a contagem de membros não muda
- **Pronta quando**: T002 feita.
- **Descrição**: teste que compara **antes e depois** da coleta: pessoas crescem, evidências de
  participação em equipe **não**. FR-006, FR-007.
- **Feita quando**: `eo_team_membership_evidence` tem a mesma contagem; nenhuma equipe ganha membro.
- **Teste**: as duas contagens no mesmo caso, e a asserção que importa é a que **não** muda.

### T006 Dizer na tela que a organização veio do trabalho
- **Pronta quando**: T002 feita.
- **Descrição**: na página da pessoa, a organização derivada do trabalho aparece **com a evidência** —
  as issues e desde quando — e **sem** dizer que a pessoa é membro. A cadeia é
  pessoa → issue → repositório → organização, e ela é observada de ponta a ponta. FR-008.
- **Feita quando**: a página de uma pessoa observada só pelo trabalho mostra a organização e o que
  sustenta a afirmação; e não usa a palavra "membro" para ela.
- **Teste**: teste de LiveView com pessoa sem evidência de equipe, exigindo o texto da evidência
  **e** a ausência de qualquer afirmação de pertencimento.

## F4 — a conferência que precisa de pessoa

### T007 Conferir no dado real
- **Pronta quando**: T001 a T006 feitas, gates verdes, e a chave mestra no terminal da pessoa
  mantenedora.
- **Descrição**: rodar uma coleta e conferir: as **288** aparições sem pessoa caem para as que a
  origem não resolve; a contagem de pessoas sai de **75**; a de evidências de equipe continua **88**;
  e `sofialctv` aparece com 64 issues em 5 repositórios. **A chave não entra no chat.**
- **Feita quando**: as quatro contagens conferem, e a página de `sofialctv` foi **olhada**.
- **Teste**: as consultas SQL do quickstart, com a saída colada no `sprint-review.md`.

## Cobertura

| Requisito | Tarefa |
|---|---|
| FR-001, FR-004 | T001, T003 |
| FR-002, FR-003, FR-005 | T002 |
| FR-006, FR-007 | T005 |
| FR-008 | T006 |
| FR-009 | T004 |
| FR-010, FR-011 | T003, T005 |
| SC-001 a SC-004, SC-006, SC-007 | T007 |
| SC-005 | T004 |
