# Tasks: Papéis por organização, e a promoção das evidências de vínculo

**Feature**: 043 · **Branch**: `043-papeis-por-organizacao` · **Data**: 2026-08-24
**Spec**: [spec.md](./spec.md) · **Plano**: [plan.md](./plan.md) · **Fecha**: [#317](https://github.com/The-Band-Solution/theband/issues/317)

**Sem dependência pendente.** As 101 evidências existem, `declared_by_user_id` e `started_at` existem, `platform_access_level_is_not_a_role/1` existe desde a feature 021, e os quatro papéis já estão na SRO. Esta feature liga peças que já estão no lugar.

---

## Fase 1 — Esquema (bloqueia tudo)

- [ ] T001 Papel passa a ser da organização — [#483](https://github.com/The-Band-Solution/theband/issues/483)
  - **Pronta quando**: nada além do repositório — há **zero** papéis cadastrados, conferido em 2026-08-24
  - **Descrição**: migração acrescentando a `eo_organizational_roles`: `organization_id` **`NOT NULL`**, `catalog_concept_id` nulável, `declared_by_user_id` nulável, `updated_by_user_id` nulável, `hidden_at` nulável. `NOT NULL` sem etapa intermediária porque **zero linhas para migrar** é a única janela em que sai de graça — nulo significaria "papel de todo o tenant", que é o defeito a corrigir. FR-001, FR-003, FR-005
  - **Feita quando**: `mix ecto.migrate` e `mix ecto.rollback` completam nos dois sentidos; o `@moduledoc` da migração diz por que `NOT NULL` agora e não depois
  - **Teste**: `mix ecto.migrate && mix ecto.rollback && mix ecto.migrate` — ida e volta, não só ida

- [ ] T002 Trocar o índice que bloqueia o catálogo — [#484](https://github.com/The-Band-Solution/theband/issues/484)
  - **Pronta quando**: T001 concluída
  - **Descrição**: derrubar `eo_organizational_roles_tenant_id_code_index` e criar `UNIQUE (tenant_id, organization_id, code)`. **É o bloqueio, não melhoria**: com o índice antigo, a segunda organização a materializar `scrum_master` bate na constraint, e o catálogo em todas as organizações é impossível. FR-006, research.md R5
  - **Feita quando**: duas organizações aceitam papel de mesmo código; a mesma organização recusa o código repetido
  - **Teste**: caso inserindo `scrum_master` em duas organizações — o segundo **passa** —, e um terceiro na mesma organização — **falha** com `Ecto.ConstraintError`

- [ ] T003 Uma origem só, por papel — [#485](https://github.com/The-Band-Solution/theband/issues/485)
  - **Pronta quando**: T001 concluída
  - **Descrição**: `CHECK (num_nonnulls(catalog_concept_id, declared_by_user_id) = 1)`. Do catálogo tem conceito e não tem autor; declarado tem autor e não tem conceito. Sem isto um papel poderia afirmar as duas origens, e a FR-003 exige origem visível e **única**
  - **Feita quando**: linha com as duas origens é recusada; linha sem nenhuma é recusada; linha com uma é aceita
  - **Teste**: três casos de inserção direta, dois esperando violação

---

## Fase 2 — História 1 (P1): os quatro do Scrum já estão lá

**Objetivo**: quem administra abre a tela de uma organização e já tem com o que promover.

**Teste independente**: abrir a tela numa organização recém-observada e ver os quatro, sem cadastrar nada.

- [ ] T004 [US1] Compor o catálogo com as linhas — [#486](https://github.com/The-Band-Solution/theband/issues/486)
  - **Pronta quando**: T003 concluída; `contracts/papeis.md` escrito
  - **Descrição**: `lib/the_band/ontology/seon/eo/role_catalog.ex` — lê os filhos de `sro.scrum_role` do YAML e compõe com as linhas da organização. Papel do catálogo **sem linha devolve `id: nil`**, e isso vaza para o chamador de propósito: um id sintético faria a tela achar que a linha existe. `origem` é **tupla marcada**, nunca booleano — o booleano perderia qual conceito da SRO originou o papel. FR-002, FR-003, plano decisão 1
  - **Feita quando**: os quatro aparecem numa organização sem linha alguma; um deles com linha aparece com `id` preenchido; a origem distingue catálogo de declarado
  - **Teste**: `test/the_band/ontology/seon/eo/papeis_por_organizacao_test.exs` — caso com zero linhas afirmando quatro entradas e `id: nil` em todas

- [ ] T005 [US1] Materializar na primeira promoção — [#487](https://github.com/The-Band-Solution/theband/issues/487)
  - **Pronta quando**: T004 concluída
  - **Descrição**: ao promover com `{:catalogo, conceito}`, gravar a linha com `on_conflict: :nothing` sobre o índice único e **reler** para pegar o `id` — inclusive quando outro processo a criou. `on_conflict` e não transação serializável: a corrida é rara e o desfecho correto é "use a que já existe", não "falhe". Plano decisão 1
  - **Feita quando**: duas promoções com o mesmo papel de catálogo criam **uma** linha; a segunda usa a que a primeira criou
  - **Teste**: caso promovendo duas evidências com o mesmo papel de catálogo e afirmando `Repo.aggregate(OrganizationalRole, :count) == 1`

- [ ] T006 [US1] Listar por organização, e nunca por tenant — [#488](https://github.com/The-Band-Solution/theband/issues/488)
  - **Pronta quando**: T004 concluída
  - **Descrição**: `list_roles/2` recebe a organização e filtra por ela. **É a correção do defeito**: hoje `eo_organizational_roles` só tem `tenant_id`, e um papel vazaria para as três organizações — mesma classe da issue #446. FR-001
  - **Feita quando**: papel de uma organização não aparece na listagem de outra
  - **Teste**: caso declarando em A e afirmando lista vazia de declarados em B — **e** afirmando que os quatro do catálogo aparecem nas duas

- [ ] T007 [US1] Tela de papéis por organização — [#489](https://github.com/The-Band-Solution/theband/issues/489)
  - **Pronta quando**: T006 concluída
  - **Descrição**: `lib/the_band_web/live/roles_live/index.ex` passa a ser por organização, com seletor. Cada papel mostra a **origem** — do catálogo com o conceito da SRO, ou declarado com autor — e a **contagem de vínculos**, que a FR-015 exige antes de permitir ocultar
  - **Feita quando**: os quatro do catálogo aparecem sem cadastro; a origem é visível em cada linha; trocar de organização troca a lista de declarados
  - **Teste**: `test/the_band_web/live/papeis_na_tela_test.exs` — o HTML contém os quatro nomes e a marca de origem, numa organização sem linha alguma

---

## Fase 3 — História 2 (P1): papéis próprios da organização

**Objetivo**: a organização declara papéis que o Scrum não nomeia.

**Teste independente**: declarar um papel em A e conferir que não aparece em B.

- [ ] T008 [US2] Declarar papel — [#490](https://github.com/The-Band-Solution/theband/issues/490)
  - **Pronta quando**: T003 e T006 concluídas
  - **Descrição**: `declare_role/4` conforme o contrato. `{:error, :code_taken}` quando o código já existe **naquela organização** — retorno, não exceção, porque é erro previsto de negócio (princípio VIII)
  - **Feita quando**: papel declarado grava autor e data; código repetido na mesma organização devolve erro sem levantar; o mesmo código em outra organização é aceito
  - **Teste**: três casos, e o do código repetido afirmando `{:error, :code_taken}` sem `rescue`

- [ ] T009 [US2] Renomear, sem trocar o código — [#491](https://github.com/The-Band-Solution/theband/issues/491)
  - **Pronta quando**: T008 concluída
  - **Descrição**: `rename_role/4` altera o **nome** e grava `updated_by_user_id`. **Não existe função que troque o código** — ele é a identidade, e trocá-lo faria os vínculos existentes apontarem para outra coisa sem que nada avisasse. Papel do catálogo devolve `{:error, :from_catalog}`: nome e código vêm da rede, e editá-los produziria divergência silenciosa com o YAML. FR-020, FR-021, FR-022
  - **Feita quando**: renomear declarado funciona e registra autor; renomear do catálogo é recusado; nenhuma função pública altera `code`
  - **Teste**: caso renomeando declarado, caso recusando catálogo, e uma verificação de que `code` não está na lista de campos do changeset de renomeação

- [ ] T010 [US2] Ocultar sem apagar — [#492](https://github.com/The-Band-Solution/theband/issues/492)
  - **Pronta quando**: T008 concluída
  - **Descrição**: `hide_role/3` e `unhide_role/3` preenchem e limpam `hidden_at`. `{:error, :in_use}` quando há vínculo vigente — ocultar não invalida vínculo (FR-004), e a saída honesta é recusar em vez de deixar vínculo apontando para papel oculto. **Não existe `delete_role`**
  - **Feita quando**: papel oculto some da escolha e continua na listagem marcado; ocultar com vínculo vigente é recusado; nenhuma função apaga papel
  - **Teste**: caso ocultando papel sem vínculo, caso recusando com vínculo, e ausência de função de exclusão no módulo público

---

## Fase 4 — História 3 (P1): promover as evidências

**Objetivo**: as 101 viram vínculo, e as 12 equipes deixam de estar vazias.

**Teste independente**: promover uma evidência e ver a equipe ganhar um membro, com autor.

- [ ] T011 [US3] Listar as evidências pendentes, sem o nível de acesso — [#493](https://github.com/The-Band-Solution/theband/issues/493)
  - **Pronta quando**: T006 concluída
  - **Descrição**: `pending_evidence/2` devolve **pessoa e equipe**, e **não devolve `platform_access_level`**. A garantia fica no **contrato**, não na tela: se o valor não chega à camada de apresentação, nenhum template pode exibi-lo por descuido. Evidência já promovida ou com observação encerrada não entra na lista. FR-011, FR-009, FR-010
  - **Feita quando**: o retorno não tem o campo de acesso; promovidas e encerradas ficam de fora
  - **Teste**: caso afirmando que `Map.has_key?(evidencia, :platform_access_level) == false` — a **ausência** no contrato, que é onde a garantia é mais barata

- [ ] T012 [US3] Promover, com autor e data de início — [#494](https://github.com/The-Band-Solution/theband/issues/494)
  - **Pronta quando**: T005 e T011 concluídas
  - **Descrição**: `promote_evidence/4` conforme o contrato. O papel é **tupla marcada** — `{:existente, id}` ou `{:catalogo, conceito}` —, porque materializar antes de promover deixaria lixo se a promoção falhasse. `started_at` vem nas opções e **`nil` é `nil`**, nunca a data de hoje (FR-018). **`started_at` MUST NOT ser derivado de `observed_at`** — aquilo é quando a coleta viu, e as 101 evidências têm `observed_at` entre 09 e 14 de agosto, que é quando a plataforma foi ligada (FR-019)
  - **Feita quando**: promover cria vínculo com autor; a evidência aponta para ele; data informada é gravada; data omitida deixa `started_at` nulo
  - **Teste**: caso com data explícita afirmando o valor, e caso sem data afirmando `is_nil(started_at)` — **e** afirmando que ele difere de `observed_at` da evidência

- [ ] T013 [US3] Recusar papel de outra organização — [#495](https://github.com/The-Band-Solution/theband/issues/495)
  - **Pronta quando**: T012 concluída
  - **Descrição**: validação em `EO.Constraints` — o papel do vínculo tem de ser da **mesma organização da equipe**. Não é expressável em `CHECK` porque envolve duas tabelas, então é changeset com teste próprio. `{:error, :role_from_another_organization}`. FR-008
  - **Feita quando**: papel de outra organização é recusado com o erro nomeado; a frase da tela diz por quê
  - **Teste**: caso com equipe de A e papel de B afirmando o erro exato

- [ ] T014 [US3] Contar pessoas, e nunca vínculos — [#496](https://github.com/The-Band-Solution/theband/issues/496)
  - **Pronta quando**: T012 concluída
  - **Descrição**: `team_size/2` conta **pessoas distintas**. Existe como função própria justamente para que ninguém escreva `length(memberships)` por engano — uma pessoa com dois papéis é **uma** pessoa, e somar vínculos faria a equipe parecer maior. FR-006c
  - **Feita quando**: pessoa com dois papéis conta uma vez; a contagem difere do número de vínculos
  - **Teste**: caso com uma pessoa e dois papéis afirmando `team_size == 1` **e** `length(vinculos) == 2` — as duas asserções juntas, porque só a primeira passaria por acaso

- [ ] T015 [US3] Tela de promoção — [#497](https://github.com/The-Band-Solution/theband/issues/497)
  - **Pronta quando**: T012, T013 e T014 concluídas
  - **Descrição**: em `lib/the_band_web/live/teams_live/show.ex`, a lista de pendentes com seletor de papel **vazio** e campo de data de início editável, preenchido com hoje como ponto de partida. **Retirar `platform_access_level` desta seção** — ele continua na tabela de membros, onde é fato sobre a ferramenta. FR-011, FR-017
  - **Feita quando**: o seletor começa vazio; a data é editável e pode ser esvaziada; o nível de acesso não aparece na seção de promoção
  - **Teste**: `test/the_band_web/live/promocao_de_evidencia_test.exs` — **a violação**: `refute html =~ "MAINTAINER"` e `refute html =~ "MEMBER"` na seção de promoção. É a `SC-005a`

- [ ] T016 [US3] A equipe vazia diz por quê — [#498](https://github.com/The-Band-Solution/theband/issues/498)
  - **Pronta quando**: T015 concluída
  - **Descrição**: a tela da equipe distingue *"nenhuma evidência"* de *"N evidências esperando confirmação"* — são coisas diferentes, e mostrar equipe vazia sem explicação esconde trabalho que existe. FR-014
  - **Feita quando**: equipe com pendentes mostra a contagem; equipe sem evidência alguma mostra outra frase; nenhuma das duas é "0 membros" seco
  - **Teste**: dois casos, um por estado, afirmando frases **diferentes**

---

## Fase 5 — Fechamento

- [x] T017 Quality gates verdes — [#499](https://github.com/The-Band-Solution/theband/issues/499)
  - **Pronta quando**: todas as tarefas de implementação concluídas
  - **Descrição**: `mix gates` — os treze, e **nunca** com `| tail`: o veredito é o código de saída, e o pipe devolve o do `tail`. Lição L23
  - **Feita quando**: o comando sai com código 0
  - **Teste**: `mix gates > /tmp/g.log 2>&1; ec=$?; tail -30 /tmp/g.log; exit $ec`

- [x] T018 Percorrer o quickstart a mão — [percurso-t018.md](./percurso-t018.md) — [#500](https://github.com/The-Band-Solution/theband/issues/500)
  - **Pronta quando**: T017 concluída
  - **Descrição**: os oito passos de [quickstart.md](./quickstart.md), incluindo os que nenhuma suíte cobre — a `SC-003` contra o dado real das 101, e se a frase da equipe vazia **ensina** quem nunca leu a spec
  - **Feita quando**: os oito passos produziram o esperado, e o que divergiu virou defeito registrado ou correção de spec
  - **Teste**: o registro do percurso, no formato de `specs/027-geracao-mensal-de-perfis/percurso-t026.md`

---

## Dependências

```
Fase 1 (esquema) ─→ US1 ─┬─→ US2
                          └─→ US3 ─→ Fase 5
```

**US2 e US3 são independentes entre si** e ambas dependem de US1 — as duas precisam da lista de papéis existir. Isto é independência real, ao contrário da feature 042.

## Paralelismo

| podem ir juntas | por quê |
|---|---|
| T002 e T003 | índice e constraint, na mesma migração |
| T008–T010 e T011–T014 | US2 e US3 tocam módulos diferentes depois de US1 |
| T007 e T015 | telas diferentes |

## Escopo mínimo

**US1 + US3 destravam o nível Equipe.** US2 — papéis próprios — é conveniência: com os quatro do Scrum já dá para promover as 101.

Se o sprint precisar encolher, **US2 sai**, e a feature ainda entrega o que a issue #317 pede.

## Total

**18 tarefas** · US1: 4 · US2: 3 · US3: 6 · esquema: 3 · fechamento: 2
