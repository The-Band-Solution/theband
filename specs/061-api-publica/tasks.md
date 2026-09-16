# Tasks: a API pública com token — fatia 1

**Spec**: [spec.md](spec.md) · **Plano**: [plan.md](plan.md) · **Decisões**: [research.md](research.md)

**Modelo**: [data-model.md](data-model.md) · **Contratos**: [contracts/](contracts/) · **Validação**: [quickstart.md](quickstart.md)

---

## Três coisas que mudam como este arquivo se lê

**O protótipo vem primeiro, e é bloqueio.** A tela de tokens tem quatro momentos que
só se decidem vendo, e errar qualquer um é erro de segurança, não de estética. A
T001 bloqueia toda a fase 3, e a régua do QA sai do `PROMPT.md` dela.

**Zero dependência nova.** Nenhuma tarefa abaixo mexe no `mix.exs`. `Plug.Crypto` e
`:crypto` já estão instalados. Se alguma tarefa levar você a acrescentar uma
dependência, ela está sendo mal entendida — o `open_api_spex` pertence à US4, que
está fora desta fatia.

**Os testes que importam aqui são os da violação, não os do caminho feliz.** "A
credencial não aparece no HTML" prova mais que "a tela renderiza". Cinco tarefas
abaixo têm o teste escrito nessa forma, de propósito.

---

## Fase 1 — o protótipo, antes do código

- [ ] **T001** Protótipo da tela de tokens
  - **Pronta quando**: nada além do repositório — a spec e o plano estão escritos
  - **Descrição**: protótipo navegável em `specs/061-api-publica/prototipo/`, publicado como artifact, com o `PROMPT.md` que o gerou e as decisões da pessoa mantenedora. Usa o design system existente — verdete, serif/grotesk/mono, marcas observado/declarado/derivado/ausente. Precisa decidir **vendo**: o momento do valor em claro com o aviso de que não volta e a ação de copiar (FR-006, FR-048); a linha mascarada com os quatro últimos (FR-007); o alcance vigente da conta dona na lista (FR-047); e a confirmação de revogação nomeando o rótulo (FR-049). A seção 3 do `PROMPT.md` é a **régua do QA**, item a item
  - **Feita quando**: o protótipo está publicado e o endereço está no `PROMPT.md`; a pessoa mantenedora aprovou por escrito; a régua da seção 3 enumera os quatro momentos acima
  - **Teste**: a régua do `PROMPT.md` tem um item conferível para cada um dos quatro momentos, e nenhum deles diz "a tela mostra os tokens" — item que não separa aprovado de reprovado não é régua

---

## Fase 2 — Fundação

**Objetivo**: o token existe, é verificável em tempo constante, e a divergência de
padrão está registrada. Nada disto chega à tela ainda.

- [ ] **T002** [P] Declarar os limiares de acesso na base
  - **Pronta quando**: nada além do repositório
  - **Descrição**: `priv/knowledge_base/rules/api_access_thresholds.yaml`, id `api.access.thresholds`, com `api.access.token_lifetime` (90 dias) e `api.access.token_idle_expiry` (30 dias sem uso). **Nenhum dos dois em constante de módulo** — FR-069, Q8. A regra diz, por limiar, se ele é **aplicado nesta fatia**: o primeiro é, o segundo não. Limiar declarado e não aplicado é pior que limiar ausente se ninguém disser qual é qual
  - **Feita quando**: `mix knowledge.validate` aceita o arquivo; nenhum `90` nem `30` referente a prazo de token aparece em `lib/`; a regra carrega com os dois limiares e com a marca de aplicação de cada um
  - **Teste**: `test/the_band/knowledge/api_access_thresholds_test.exs` — a regra existe com o id declarado, os dois limiares são lidos da base, e **o teste que importa**: `grep -rn "90" lib/the_band/tenants/api_tokens.ex` não encontra o prazo escrito no código

- [ ] **T003** [P] Registrar a ADR do hash do token
  - **Pronta quando**: nada além do repositório — a decisão já está tomada em Q1 da spec
  - **Descrição**: ADR em `docs/adr/` registrando que o token de API é guardado como **SHA-256 do segredo**, e não com `TheBand.Encrypted.Binary` como toda outra credencial. FR-004 e FR-005 exigem ADR porque isto é divergência de padrão público. A ADR carrega o par que ensina: Cloak é **reversível** e devolveria todos os tokens em claro com a chave mestra — proteção certa para credencial de **terceiro**, que a plataforma **replica**, e errada para verificador do próprio segredo, que a plataforma só **confere**; bcrypt custa ~100 ms por verificação, que é defesa contra senha humana e auto-negação de serviço numa API. E registra os dois detalhes que a decisão arrasta: comparação em tempo constante, e busca pelo id público e nunca pelo hash
  - **Feita quando**: a ADR está numerada e ligada a partir da spec; o status está declarado; as duas alternativas aparecem com o motivo de cada recusa, e não só a escolhida
  - **Teste**: revisão contra `docs/seguranca/2026-09-09-api-com-token.md` — a ADR não contradiz nenhum achado da avaliação, e quem ler só a ADR entende por que o padrão da casa **continua certo** para credencial de terceiro

- [ ] **T004** A tabela dos tokens de API
  - **Pronta quando**: T002 concluída — o prazo máximo vem da base, e a migração não o inventa
  - **Descrição**: migração criando `api_access_tokens` conforme [data-model.md](data-model.md). `tenant_id` e `user_id` **NOT NULL**; único em `(tenant_id, public_id)`; índice em `(tenant_id, user_id)`. **Nenhum índice em `token_hash`** — buscar por ele é o que a decisão Q1 proíbe. Sem coluna de "ativo": o estado é derivado de `revoked_at` e `expires_at` contra o instante da requisição, porque coluna de estado exigiria job, e job cria a janela entre vencer e ser marcado, que é acesso concedido por atraso de fila. Reversível
  - **Feita quando**: `mix ecto.migrate` e o rollback completam sem erro; a tabela não tem coluna alguma para o valor em claro nem para escopo, papel ou lista de organizações
  - **Teste**: ida e volta — `mix ecto.migrate` seguido de `mix ecto.rollback`, e depois `mix ecto.migrate` de novo; e a consulta a `information_schema.columns` não devolve nenhuma coluna cujo nome contenha `scope`, `role` ou `plain`

- [ ] **T005** O schema que não deixa o hash vazar
  - **Pronta quando**: T004 concluída
  - **Descrição**: `lib/the_band/tenants/schemas/api_access_token.ex`. **Deriva `Inspect` excluindo `token_hash`** e o campo virtual do valor — FR-008. Sem isso, um `IO.inspect` de depuração ou um relatório de erro do Oban despeja o verificador no log, e foi exatamente assim que um token do GitHub ficou oito dias em claro em `oban_jobs.errors`. O valor em claro existe **apenas** como campo virtual, preenchido uma vez no retorno da criação, e nunca lido do banco porque não está lá
  - **Feita quando**: `inspect/1` de um token carregado não contém o hash nem o valor; o changeset recusa `label` vazio e `user_id` nulo
  - **Teste**: `test/the_band/tenants/api_access_token_test.exs` — **o teste é a violação**: `inspect(token)` não contém nenhum byte do hash, e `inspect(%{token: token})` aninhado também não

- [ ] **T006** O formato do token e a verificação em tempo constante
  - **Pronta quando**: T003 concluída — a decisão do hash está registrada; T005 concluída
  - **Descrição**: em `lib/the_band/tenants/api_tokens.ex`, a geração e a conferência. Formato `tb_api_<id_publico>_<segredo>` (FR-001, R5): prefixo fixo para varredura de segredo vazado, id público indexado por onde a linha é buscada, e segredo de no mínimo 32 bytes de `:crypto.strong_rand_bytes/1` em Base64 URL-safe sem padding (FR-002). A conferência usa `Plug.Crypto.secure_compare/2` — **nunca `==`**: na sessão o `==` está correto porque o valor vem de cookie assinado pelo próprio servidor, mas aqui o valor vem cru de um cabeçalho controlado por quem chama, e o canal de tempo é alcançável. A busca é pelo id público, **nunca pelo hash**
  - **Feita quando**: dois tokens gerados em sequência não compartilham id público nem segredo; entrada malformada — sem prefixo, com partes a menos, com partes a mais — é recusada sem exceção; nenhuma consulta do módulo tem `token_hash` na cláusula `where`
  - **Teste**: `test/the_band/tenants/api_tokens_test.exs` — o parser recusa seis formas malformadas nomeadas uma a uma; e **o teste que importa**: `grep -n "token_hash ==" lib/the_band/tenants/api_tokens.ex` não encontra nada

---

## Fase 3 — US1 (P1): gerar, e ver o valor uma única vez

**Objetivo**: quem administra cria um token com rótulo, copia o valor, e nunca mais
o vê.

**Teste independente**: criar um token, copiar o valor, recarregar a tela, e conferir
que o valor não aparece na página, no HTML servido, no log nem no banco.

- [ ] **T007** [US1] Gerar o token na fronteira
  - **Pronta quando**: T006 concluída
  - **Descrição**: `create_api_token/4` em `TheBand.Tenants`, por `defdelegate` (ADR 0003). Recebe tenant, conta dona, atributos e autor; devolve `{:ok, token, valor_em_claro}` — **o valor só aqui**, e nunca mais. Rótulo é obrigatório (FR-009): token sem rótulo é token que ninguém sabe revogar. A expiração respeita o teto de `api.access.token_lifetime`, lido da base. **Não existe** `update_api_token/2` nem `delete_api_token/2`: mudar a expiração de um token vivo é conceder prazo sem gerar credencial nova, e ausência marca em vez de apagar
  - **Feita quando**: o valor devolvido casa com o hash gravado; um segundo `create` da mesma conta gera um token distinto e não toca no primeiro; a fronteira não expõe função de atualizar nem de apagar
  - **Teste**: `test/the_band/tenants/api_tokens_test.exs` — o valor devolvido autentica e o banco não o contém; e a fronteira `TheBand.Tenants` não define `update_api_token` nem `delete_api_token`

- [ ] **T008** [US1] Listar os tokens com o estado lido
  - **Pronta quando**: T007 concluída
  - **Descrição**: `list_api_tokens/1` devolve, por token, rótulo, os quatro últimos, quem criou, quando, último uso, expiração e o **estado lido** — ativo, revogado ou expirado — derivado de `revoked_at` e `expires_at` contra o instante da chamada, e nunca de uma coluna. Último uso nulo é **"nunca usado"**, e expiração nula é **"sem expiração"**: nenhum dos dois vira data vazia nem a data de criação (US1 cenário 3)
  - **Feita quando**: um token recém-criado aparece como ativo e nunca usado; um token com `expires_at` no passado aparece expirado sem nenhuma escrita ter acontecido
  - **Teste**: `test/the_band/tenants/api_tokens_test.exs` — o token com expiração no passado é lido como expirado, e a contagem de linhas do banco antes e depois da leitura é a mesma

- [ ] **T009** [US1] A tela de tokens na área administrativa
  - **Pronta quando**: T001 aprovada — a tela implementada é exatamente a aprovada; T008 concluída
  - **Descrição**: LiveView em `/api-tokens`, dentro do `live_session :admin` e do `require_admin` que já servem `/accounts` e `/access-scopes` — FR-045, porque credencial é gestão, não operação. A lista traz o que T008 devolve, na forma do protótipo. Conta não administradora recebe recusa **com motivo nomeado**, e não uma página em branco
  - **Feita quando**: a rota está dentro do escopo administrativo do `router.ex`; a tela mostra, por linha, rótulo, máscara com os quatro últimos, autor, data, último uso e estado; conta comum é recusada com motivo
  - **Teste**: `test/the_band_web/live/tela_de_tokens_test.exs` — conta administradora abre e lê as colunas da régua do protótipo; conta comum recebe recusa com o motivo no texto; e **o teste que importa (SC-013)**: o HTML renderizado tem **0** ocorrências do hash e **0** do valor em claro

- [ ] **T010** [US1] O valor em claro aparece uma vez
  - **Pronta quando**: T009 concluída
  - **Descrição**: a criação apresenta o valor **uma única vez**, com aviso explícito de que não voltará, ação de copiar, e a instrução de guardá-lo em gerenciador de segredo — FR-006, FR-048. O valor vive no `assign` daquele render e some ao navegar ou recarregar; **não** é gravado em nada e **não** volta por `handle_params`
  - **Feita quando**: depois de criar, o valor está na página; depois de qualquer navegação ou recarga, não está; a linha passa a mostrar a máscara com os quatro últimos
  - **Teste**: `test/the_band_web/live/tela_de_tokens_test.exs` — criar, capturar o valor, `render_patch` de volta à listagem, e afirmar que o valor **não** aparece no HTML; e o teste da violação: nenhuma das duas renderizações seguintes contém o valor

- [ ] **T011** [US1] O alcance vigente da conta dona, na lista
  - **Pronta quando**: T009 concluída
  - **Descrição**: cada linha mostra o **alcance vigente da conta dona** do token — FR-047 —, para que a consequência de FR-028 seja visível **antes** de ser reclamada: o alcance da integração muda quando a pessoa muda de equipe, e quem gerou o token precisa ver isso na hora de gerar, não na hora em que o painel de terceiro esvazia. Lê de `Access` na forma que já existe, sem materializar nada no token
  - **Feita quando**: a linha diz o alcance de hoje; encerrar um vínculo da conta dona muda o que a linha diz na carga seguinte, sem job e sem escrita no token
  - **Teste**: `test/the_band_web/live/tela_de_tokens_test.exs` — encerrar um vínculo da conta dona e recarregar muda o texto do alcance; e a linha do token continua com os mesmos valores de banco

---

## Fase 4 — US3 (P1): revogar, e a linha fica

**Objetivo**: quem administra revoga, o cliente passa a ser recusado, e o registro
permanece.

**Teste independente**: chamar com sucesso, revogar, chamar de novo — a segunda
chamada é recusada, e a lista mostra a revogação sem apagar a linha.

- [ ] **T012** [US3] Revogar marcando, nunca apagando
  - **Pronta quando**: T008 concluída
  - **Descrição**: `revoke_api_token/3` grava `revoked_at` e `revoked_by_user_id` — FR-012. **Não existe reativar** (US3 cenário 3): revogação é definitiva, e o caminho é gerar outro. Um botão de reativar transformaria a revogação em pausa, e quem revoga por suspeita de vazamento não quer uma pausa. Revogar duas vezes é idempotente e não reescreve o autor da primeira
  - **Feita quando**: a linha continua no banco depois de revogada; não há função de reativar na fronteira; revogar de novo não muda `revoked_at` nem `revoked_by_user_id`
  - **Teste**: `test/the_band/tenants/api_tokens_test.exs` — **SC-012**: a contagem de linhas antes e depois da revogação é idêntica; e `TheBand.Tenants` não define nenhuma função cujo nome contenha `reactivate` ou `unrevoke`

- [ ] **T013** [US3] A confirmação que nomeia o rótulo
  - **Pronta quando**: T012 concluída; T009 concluída
  - **Descrição**: a revogação na tela pede confirmação **nomeando o rótulo do token** — FR-049 —, porque revogar o token errado interrompe a integração de um terceiro que não está na sala. A linha revogada permanece na lista, marcada, com data e quem revogou
  - **Feita quando**: a confirmação contém o rótulo exato; depois de confirmar, a linha está lá marcada revogada, com data e autor; não há ação de reativar na tela
  - **Teste**: `test/the_band_web/live/tela_de_tokens_test.exs` — a confirmação traz o rótulo; depois da revogação a lista tem o **mesmo número de linhas**, com uma marcada; e o HTML não contém nenhum botão de reativar

---

## Fase 5 — US2 (P1, reduzida a uma rota): a chamada autenticada

**Objetivo**: um cliente com token chama `GET /api/v1/teams` e recebe as equipes do
tenant dele, com a marca de origem em cada uma.

**Teste independente**: com dois tenants povoados, chamar com o token de cada um e
conferir que nenhum identificador do outro aparece.

- [ ] **T014** [US2] Autenticar o token na fronteira
  - **Pronta quando**: T006 concluída; T012 concluída — a revogação precisa existir para ser conferida
  - **Descrição**: `authenticate_api_token/1` separa as partes, busca por `public_id`, confere o segredo em tempo constante, lê o estado contra `DateTime.utc_now/0` e carimba `last_used_at`. **Sem cache** — Q3 decidiu latência zero entre revogar e recusar, porque cache que atrasa revogação é decisão de segurança disfarçada de desempenho. A expiração é conferida **na requisição**, e não por job: job cria janela entre o vencimento e a passagem dele, e essa janela é acesso concedido por atraso de fila. Recusa também quando a conta dona está desativada ou removida — o token não sobrevive à conta de quem herda o alcance
  - **Feita quando**: as quatro recusas — inexistente, revogado, expirado, conta desativada — devolvem o mesmo átomo de erro; o carimbo de uso é gravado só nas chamadas aceitas; chamadas concorrentes com o mesmo token não se serializam
  - **Teste**: `test/the_band/tenants/api_tokens_test.exs` — as quatro recusas são o mesmo valor de retorno, e as quatro deixam registro interno distinto; e o token expirado é recusado **sem nenhuma escrita** ter acontecido antes

- [ ] **T015** [US2] O plug da recusa uniforme
  - **Pronta quando**: T014 concluída; [contracts/erro.md](contracts/erro.md) escrito
  - **Descrição**: `lib/the_band_web/plugs/api_auth.ex`, o veredito único. Lê **só** o cabeçalho `Authorization: Bearer` — em query string, corpo ou cookie o token não é lido, porque query string vaza para log de servidor e para histórico de navegador. Toda recusa produz a mesma resposta (FR-016), e o **motivo real vai para o log interno**, recuperável pelo identificador da requisição: calar para o cliente não é calar para quem opera, e é o princípio XI
  - **Feita quando**: as quatro recusas produzem corpos idênticos exceto o identificador da requisição; o token em query string não autentica; o cabeçalho não é registrado em log nenhum
  - **Teste**: `test/the_band_web/plugs/api_auth_test.exs` — **SC-003**: as três recusas, com o identificador removido, são idênticas byte a byte; e **SC-004**: as três razões distintas são localizáveis no log capturado pelos três identificadores

- [ ] **T016** [US2] O formato único de erro
  - **Pronta quando**: [contracts/erro.md](contracts/erro.md) escrito
  - **Descrição**: `lib/the_band_web/controllers/api/v1/fallback_controller.ex` com **um** formato para todos os códigos — FR-020 —, para que o cliente escreva um tratador e não seis. `code` estável em inglês, `message` que **nunca** diz qual das causas ocorreu, e `request_id` sempre presente. `404` e não `403` para recurso de outro tenant (FR-030): `403` afirma "isto existe e você não pode", e essa afirmação é vazamento de existência
  - **Feita quando**: os quatro códigos da fatia saem no mesmo formato; nenhuma mensagem distingue revogado de expirado de inexistente
  - **Teste**: `test/the_band_web/controllers/api/v1/erro_test.exs` — os quatro códigos têm as mesmas três chaves; e nenhuma mensagem contém as palavras `revoked`, `expired` ou `unknown`

- [ ] **T017** [US2] A rota das equipes
  - **Pronta quando**: T015 concluída; T016 concluída; [contracts/api-v1-teams.md](contracts/api-v1-teams.md) escrito
  - **Descrição**: `GET /api/v1/teams` passando pela pipeline `:api` que o `router.ex` declara e nunca usou. As equipes são as **do tenant do token**, no mesmo recorte da tela — FR-026. Está escrito no contrato e precisa continuar escrito: `/teams` recorta **por tenant** e não filtra por `Access`, então esta rota também não; não é frouxidão da API, é a mesma resposta que a pessoa vê logada. Coleção vazia devolve `200` com lista vazia, nunca `404`, e a distinção é dita: *nada encontrado* não é *não coletado*
  - **Feita quando**: a rota responde `200` com as equipes do tenant; um tenant sem equipe recebe lista vazia com `200`; a pipeline `:api` deixou de estar sem uso
  - **Teste**: `test/the_band_web/controllers/api/v1/team_controller_test.exs` — a resposta traz as equipes do tenant do token; e **SC-002**: com dois tenants povoados, a interseção dos identificadores das duas respostas é vazia

- [ ] **T018** [US2] O serializador com a marca de origem
  - **Pronta quando**: T017 concluída
  - **Descrição**: `team_json.ex` devolve, por equipe, `id`, `name`, `slug` e **`origin`** — `observed` quando veio de ferramenta conectada, com `source_system` dizendo qual, e `declared` quando foi declarada nesta plataforma, com `source_system` nulo. A plataforma inteira existe para separar observado de declarado, e entregar número sem essa marca a destruiria exatamente no ponto de entrega — com o agravante de o consumidor previsto ser um modelo, que afirmaria o dado sem ela
  - **Feita quando**: toda equipe da resposta traz `origin`; equipe declarada traz `source_system` nulo e não uma string vazia
  - **Teste**: `test/the_band_web/controllers/api/v1/team_controller_test.exs` — com uma equipe observada e uma declarada, as duas trazem `origin` distinto; e **0** equipes na resposta vêm sem a marca

- [ ] **T019** [US2] A paginação por cursor, sem total
  - **Pronta quando**: T018 concluída
  - **Descrição**: `page_size` com padrão 50 e teto 200 (FR-018), e `after` com cursor opaco. O bloco `page` traz `has_next` e `next_cursor`; **`total` é `null`**, com `total_note` dizendo por quê — Q5: total estimado é pior que total ausente, e a nota viaja junto para que quem lê a resposta crua entenda o `null` sem abrir documentação. Cursor, e não deslocamento: deslocamento pula ou repete linha quando a coleção muda entre páginas
  - **Feita quando**: `page_size` acima do teto é reduzido ao teto e não recusado; percorrer todas as páginas devolve cada equipe exatamente uma vez; `total` é `null` com a nota ao lado
  - **Teste**: `test/the_band_web/controllers/api/v1/team_controller_test.exs` — **SC-009**: com `page_size=2` e mais de três páginas, o conjunto paginado é igual ao da consulta direta, sem repetição nem omissão

---

## Fase 6 — Transversal

- [ ] **T020** O teto de consultas por requisição
  - **Pronta quando**: T019 concluída
  - **Descrição**: teste-guardião contando consultas por requisição com `test/support/contador_de_consultas.ex`, como as sete telas que já o usam. `Access` tem de ser chamado na forma **em lote**, nunca por item: perguntar por linha é a **L38**, e `access.ex` diz literalmente que `pessoas_alcancadas/2` existe para evitá-la. O número de consultas **não muda** com o número de equipes
  - **Feita quando**: o teste afirma igualdade entre dez equipes e cem, e entre cem e o caso mínimo; a mensagem de falha diz o que reintroduziria o problema
  - **Teste**: `test/the_band_web/controllers/api/v1/teto_de_consultas_test.exs` — `dez == cem` e `cem == minimo`, com a mensagem nomeando a L38 e o `Repo.preload` como o caminho que a recria

- [ ] **T021** [P] Nenhum método de escrita responde
  - **Pronta quando**: T017 concluída
  - **Descrição**: `/api/v1` aceita **apenas** `GET` e `HEAD` — FR-017, porque não há autor honesto para a proveniência de uma escrita por token. `HEAD` responde os mesmos cabeçalhos de `GET` com corpo vazio
  - **Feita quando**: `POST`, `PUT`, `PATCH` e `DELETE` devolvem `405` no formato único de erro em todas as rotas de `/api/v1`
  - **Teste**: `test/the_band_web/controllers/api/v1/somente_leitura_test.exs` — **SC-006**: os quatro métodos devolvem `405` percorrendo a tabela de rotas, e não uma lista escrita à mão que envelhece

- [ ] **T022** [P] O valor em claro não existe em lugar nenhum
  - **Pronta quando**: T010 concluída; T017 concluída
  - **Descrição**: teste que gera um token, exerce a tela e a API, e varre os **quatro** lugares pelo valor conhecido — log capturado, corpo da resposta, HTML renderizado e banco. É **SC-001**, e é o critério que nenhum outro teste desta fatia substitui
  - **Feita quando**: as quatro varreduras devolvem zero; a varredura do banco procura o valor em todas as colunas de texto da tabela, e não só em `token_hash`
  - **Teste**: `test/the_band_web/api/segredo_nao_vaza_test.exs` — **o teste é a violação**: o valor conhecido tem **0** ocorrências nos quatro lugares, e o teste falha ruidosamente se qualquer varredura devolver um

- [ ] **T023** [P] Os dois tenants não se veem
  - **Pronta quando**: T017 concluída
  - **Descrição**: teste que povoa dois tenants, chama a rota com o token de cada um, e compara os conjuntos de identificadores. **SC-002**. Confere também que nenhuma consulta desta feature é emitida sem tenant (FR-031)
  - **Feita quando**: a interseção dos identificadores é vazia; nenhuma consulta do caminho da API roda sem `tenant_id` na cláusula
  - **Teste**: `test/the_band_web/api/isolamento_por_tenant_test.exs` — a interseção é vazia, e a consulta capturada por telemetria tem `tenant_id` em toda cláusula `where`

- [ ] **T024** Gates
  - **Pronta quando**: T001 a T023 concluídas
  - **Descrição**: `mix gates` com o código de saída colado no comando. O veredito é o **código de saída**, e qualquer comando depois dele substitui o código que vale — é a lição L60, e ela já reincidiu nesta sessão
  - **Feita quando**: os 16 gates rodam e o código de saída é 0; nenhum aviso novo de Credo, Sobelow ou dialyzer
  - **Teste**: `mix gates > /tmp/gates.log 2>&1; echo "EXIT=$?"` — com `echo` **colado**, e nada entre os dois

---

## Dependências

```
T001 protótipo ────────────────────────────┐
                                           ▼
T002 regra ──┐                        T009 tela ──▶ T010 ──▶ T011
             ├──▶ T004 tabela ──▶ T005 schema ──▶ T006 formato
T003 ADR ────┘                             │           │
                                           │           ├──▶ T007 ──▶ T008 ──▶ T012 ──▶ T013
                                           │           │
                                           │           └──▶ T014 ──▶ T015 ──▶ T017 ──▶ T018 ──▶ T019
                                           │                   T016 ─┘                            │
                                           └───────────────────────────────────────────────────── ▼
                                                                                    T020, T021, T022, T023
                                                                                              │
                                                                                              ▼
                                                                                           T024 gates
```

**A ordem das histórias**: US1 primeiro, porque sem token não há API e é a única que
não depende de nenhuma outra. US3 em seguida, porque emitir sem poder revogar é pior
que não emitir. US2 por último, porque é o que dá valor às duas anteriores — mas a
fatia só está entregue com as três.

---

## O que roda em paralelo

| Momento | Em paralelo |
|---|---|
| início da fase 2 | **T002** e **T003** — arquivos distintos, nenhuma dependência entre eles |
| fim da fase 5 | **T021**, **T022** e **T023** — três arquivos de teste distintos, todos sobre a rota já pronta |

**T020 não entra nesse grupo**: ele mede o mesmo caminho que os outros exercitam, e
rodar junto disputaria a telemetria que ele conta.

---

## Estratégia de entrega

**MVP**: fases 1 a 3 — o protótipo, a fundação e a US1. Ao fim delas existe token
gerado na tela, com o valor mostrado uma vez e guardado só como hash. **Não há API
ainda**, e isso é honesto: a credencial existe antes da porta.

**Incremento 2**: fase 4. O token passa a ser revogável, e a plataforma deixa de
emitir segredo permanente.

**Incremento 3**: fases 5 e 6. A porta abre, com uma rota, e os quatro testes
transversais provam o que a spec exige.

Cada incremento é entregável e conferível sozinho. Nenhum deles é infraestrutura
sem consumidor visível.
