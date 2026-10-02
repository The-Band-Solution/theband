# Avaliação de segurança da spec 072, antes do plano e do código

**Feature**: `specs/072-papel-de-administrador/spec.md` (issue #568)
**Data**: 2026-10-02
**Papel**: Security (`AGENTS.md` §13 e §14.0). **Não escrevi este desenho.**
**Natureza**: leitura do diff pretendido (a spec) e da superfície que ela toca. **Não é varredura
completa**, e nenhum gate foi rodado: a instrução desta avaliação vedou `mix test`/`mix gates`. As
afirmações sobre o código vêm de leitura, cada uma com arquivo e linha.

## Resumo

A spec acerta nas três coisas mais visíveis: o ato confere o papel **dentro** do domínio (FR-002),
recurso de outra organização é "não encontrado" (FR-003) e o guarda do último administrador vale
também para o rebaixamento (FR-004). O risco maior não está no ato novo, e sim no que ele torna
alcançável.

**Hoje nenhum caminho tira `role = "admin"` de uma conta.** Por isso o poder de administrar ficar
**congelado no `mount` do LiveView** nunca teve consequência. A 072 cria o primeiro caminho que tira
a marca, e esse congelamento vira o achado S1: o rebaixado com uma tela de administração aberta
continua administrando. Pela tela de tokens ele ainda pode emitir uma credencial de API **em nome de
outro administrador**, e essa credencial sobrevive ao rebaixamento dele e até à desativação dele.

| # | Achado | Severidade | OWASP / ASVS |
|---|---|---|---|
| S1 | Papel congelado no `mount`, e os atos administrativos existentes não conferem o ator | **Alta** | A01 / V4.1.3, V4.2 |
| S2 | O ato novo vira escalada se conferir o ator pela struct recebida, e não no banco sob a trava | **Alta** | A01 / V4.1.3 |
| S3 | O guarda do último administrador decide sobre o papel lido **antes** da trava | Média | A04 / V1.11.3 |
| S4 | `cast` de `:role` no changeset de cadastro: a defesa mora no chamador | Média | A04 / V4.1.5, V5.1.2 |
| S5 | Promover amplia todo token vigente da conta; rebaixar não toca os tokens que o rebaixado criou para outros donos | Média | A01, A07 / V3, V4 |
| S6 | Registro somente-acréscimo e papel sem episódio: o desenho precisa do banco, como na 070 | Média | A09 / V7.3, V8.3 |
| S7 | `users.role` sem `CHECK`: estado em string livre | Baixa | A04 / V5.1 |
| S8 | A conta desativada fica sem controle e mantém a marca. Reativar devolve administração sem registro de papel | Baixa | A01 / V4.1 |
| S9 | Evento de acesso: a recusa também é sinal, e o teste precisa de relator | Baixa | A09 / V7.1, V7.2 |
| S10 | `Access.pessoas_alcancadas/2` concede `:todas` sem comparar o tenant da conta | Baixa (fora do escopo, mesma superfície) | A01 / V4.2.1 |

---

## Achados

### S1 — Alta: o papel fica congelado no `mount`, e os atos de conta não conferem quem age

**O que é.** A01. Quando um administrador é rebaixado com uma tela de administração aberta, ele
continua executando atos de administrador por aquela aba, sem prazo, porque nenhum ponto relê o
papel depois do `mount`.

**Onde.**

- `lib/the_band_web/live/hooks.ex:102-115`: `on_mount(:require_admin)` confere `User.admin?/1`
  **só no mount**.
- `hooks.ex:151-161`: `reconferir/2`, o gatilho do #1042, relê a sessão, a organização e a conta
  ativa. Ele **não** relê o papel e **não** reatribui `:current_user`. Devolve o `socket` intacto.
  Usar o #1042 sem alteração, como a FR-008 sugere, deixa a aba exatamente como estava.
- Os atos chamados pelas telas de `live_session :admin` (`router.ex:362-374`) não conferem o ator:
  - `Auth.cadastrar_conta/3` (`lib/the_band/tenants/auth.ex:311`) recebe a struct do ator e só
    usa o `id`;
  - `Auth.reset_password/3` (`auth.ex:331`) recebe um `actor_id` e não confere nada;
  - `Tenants.disable_user/4` (`lib/the_band/tenants.ex:395`) e `enable_user/4` (`:479`) não
    conferem o papel nem o tenant do ator. O próprio teste o afirma:
    `test/the_band/tenants/ultimo_admin_ativo_test.exs:55-58`, *"um membro tentando desativar o
    último admin chega ao guarda pelo contexto; a tela já o impediria"*;
  - `Tenants.declare_person/4`: o `@doc` em `tenants.ex:260` diz *"esta função NÃO verifica papel
    de plataforma"*;
  - `ApiTokens.criar/4` (`lib/the_band/tenants/api_tokens.ex:235`) não confere o papel do autor. A
    tela deixa escolher o dono do token: `api_token_live/index.ex:189`, `"escolher_dono"`;
  - `Access.grant/5` e `revoke/3` (`lib/the_band/tenants/access.ex:546`, `:579`) **conferem**
    `User.admin?(actor)`, mas sobre a struct de `socket.assigns.current_user`
    (`access_scopes_live/index.ex:111`, `:139`). Ou seja, sobre o papel do momento do mount.
- Telas **fora** de `:admin` decidem pela struct do mount:
  - `repository_live/show.ex:98` e `:129` casam `%{current_user: %{role: "admin"}}` na cabeça do
    `handle_event`;
  - `roles_live/index.ex:124`, `:152`, `people_live/show.ex:146`, `:155` e
    `teams_live/index.ex:48` usam `User.admin?(socket.assigns.current_user)`;
  - o recorte `:operacao`, montado em `hooks.ex:77-82`, é calculado uma vez.

**Caminho de exploração.** Atacante: um administrador da organização que vai ser rebaixado, por
exemplo por perda de confiança ou mudança de função. Antes do rebaixamento, ele tem uma aba aberta
em `/api-tokens` ou `/accounts`. Ele não precisa de nada além da aba.

1. Pela aba `/api-tokens`, escolhe como dono o **outro** administrador, Y, e cria um token. O
   `ApiAuth` lê o papel do **dono** a cada requisição (`lib/the_band_web/plugs/api_auth.ex:80`), e
   Y é admin. O token responde com alcance de administração (`Access.pode_ver/3` →
   `{:ok, :admin}`, `pessoas_alcancadas/2` → `:todas`) pela API e pelo MCP. Esse token **sobrevive
   ao rebaixamento e à desativação** do atacante, porque o dono é Y.
2. Ou, pela aba `/accounts`, reinicia a senha de Y, recebe a temporária e entra como Y. É uma
   tomada de conta. As sessões de Y caem, então Y percebe, mas depois do fato.
3. Ou, por `/access-scopes`, concede a si mesmo escopo `organization`, e mantém a visão como membro.

**Por que Alta.** A autorização fica contornável por quem acabou de perder o direito: é exatamente o
caso que o rebaixamento existe para resolver. A consequência para o negócio: **rebaixar alguém não
tira dele o poder de administrar enquanto ele mantiver uma aba aberta, e ele pode transformar esse
poder numa credencial permanente com alcance de administração sobre toda a organização.**

**O que fecha.** São duas camadas, e as duas são necessárias:

1. **No domínio (a garantia).** Os atos administrativos chamados pelas telas de `:admin` relêem o
   ator **no banco**, pelo id e pelo tenant, e recusam se ele não for administrador ativo. A
   alternativa mínima, se o escopo pesar, cobre no mínimo os atos que **criam credencial ou mudam
   acesso**:
   - `reset_password/3`;
   - `cadastrar_conta/3`;
   - `ApiTokens.criar/4`;
   - `Access.grant/5`;
   - `disable_user/4` e `enable_user/4`;
   - os atos novos.

   O resto pode ir para backlog com prazo.
2. **Na tela (FR-008).** O ato publica o aviso no tópico `"conta:" <> id`, depois do commit, na forma
   de `avisando_as_telas/2` (`tenants.ex:444`). Ao receber o aviso, `reconferir/2` relê a conta,
   **reatribui `:current_user`** e reaplica a condição da `live_session`: na `:admin`, a conta que
   deixou de ser admin é redirecionada com a frase de `require_admin`; na `:operacao`, recalcula
   `operacional?/2`. Hoje a hook não sabe em qual `live_session` está, e o plano precisa decidir
   como ela passa a saber. Por exemplo: o `on_mount` grava a condição num assign privado.

A segunda camada sozinha **não** satisfaz a FR-008 como está escrita (*"na próxima ação"*). O aviso
é assíncrono, e um evento que já está na caixa de mensagens do processo antes do aviso executa com
o papel antigo. Só a primeira camada fecha essa janela.

**O que acontece se não entrar agora.** A primeira promoção e o primeiro rebaixamento em produção
abrem o caminho acima. **Recomendo bloqueio**: a 072 não deveria ir para produção sem a camada 1
para os atos que criam credencial, e sem a camada 2.

### S2 — Alta: o ato novo, se conferir o ator pela struct, é escalada de privilégio

**O que é.** A01. A FR-002 diz *"conferido dentro do ato"*. O padrão da casa para isso é
`User.admin?(actor)` sobre a struct recebida (`access.ex:546`). Num ato que **concede** a marca,
essa conferência deixa o rebaixado de S1 promover a si mesmo de volta, pela mesma aba.

**Caminho de exploração.** A rebaixa B. B, com `/accounts` aberta e a struct antiga nos assigns,
clica em "promover" sobre si mesmo ou sobre um cúmplice. O ato confere `User.admin?(struct_de_B)`,
que dá `true`, e B volta a ser administrador. O registro mostra B promovendo, mas o ato não devia
ter acontecido.

**O que fecha.** A conferência do ator acontece **dentro da transação, sob a mesma trava do guarda**:

1. trava as contas administradoras ativas do tenant (`FOR UPDATE`, ordem de id, como em
   `tenants.ex:631-641`);
2. **o ator precisa estar nesse conjunto travado**. Essa condição prova ao mesmo tempo que ele é
   admin, que está ativo, que é do tenant e que **não foi rebaixado por uma transação que commitou
   antes desta**: o PostgreSQL reavalia o `WHERE` nas linhas que esperou;
3. trava a linha do alvo (`SELECT … FOR UPDATE` por `id` **e** `tenant_id`), e relê o papel e o
   estado dele **depois** da trava;
4. decide.

A assinatura do contrato pode receber `%User{}`, para manter `%Tenant{}` e `%User{}` como conceitos
na assinatura (AGENTS §7.7), mas o contrato precisa dizer que **a struct só fornece o id**.

**Consequência para o cenário 3 da US2.** Com essa ordem, quando cada um dos dois administradores
rebaixa o outro ao mesmo tempo, o segundo ato é recusado **porque o ator já não é admin**, e não
pelo guarda do último. A spec diz *"recusado pelo mesmo guarda"*. Veja a emenda à FR-004.

### S3 — Média: o guarda do último administrador decide sobre o papel lido antes da trava

**Onde.** `tenants.ex:396` lê o alvo com `usuaria_do_tenant/2` **fora** da transação. Em
`tenants.ex:409`, `resta_um_admin_ativo/2` **casa `%User{role: "admin"}` na struct lida**
(`:631`), e cai em `:ok` sem travar nada quando a struct diz `member` (`:648`).

**Caminho de exploração.** O caminho só existe a partir da 072, porque precisa de promoção. Exige
atos concorrentes de administradores, e o resultado é uma organização sem nenhum administrador
ativo:

1. A é o único administrador ativo, e C é membro;
2. A abre o ato de desativar C: `disable_user` lê C como `member`;
3. A promove C por outra aba, e o ato commita. Agora A e C são administradores;
4. C rebaixa A: o guarda trava `[A, C]`, conta dois e passa. A vira membro;
5. a desativação do passo 2 entra na transação com a struct antiga de C (`member`), pula o guarda e
   desativa C.

Resultado: zero administradores ativos. `Bootstrap.ja_ha_administrador?/0`
(`lib/the_band/tenants/bootstrap.ex:85-87`) pergunta por **qualquer** linha admin no banco inteiro,
e por isso não recupera nada. A saída é SQL à mão em produção.

Existe também um efeito sem ataque. Se B é rebaixado enquanto alguém desativa B, a desativação é
recusada com `:ja_desativada` (`tenants.ex:642`): um motivo falso, com B ativo.

**Severidade Média**, e não Alta: o caminho exige três atos concorrentes de quem já administra, e não
expõe dado. Ele derruba a governança de acesso da organização, e a recuperação é manual.

**O que fecha.** `disable_user/4` passa a usar a mesma sequência de S2:

1. trava o conjunto de administradores ativos;
2. trava e relê o alvo;
3. decide pelo papel relido.

O mais simples é **um único guarda, compartilhado** pelos três atos (desativar, rebaixar, e
promover, que trava para serializar contra os outros dois). É exatamente o que a FR-004 já pede com
*"a mesma trava"*. A spec precisa dizer que isso **inclui reler o alvo depois da trava**.

### S4 — Média: `cast` de `:role` no changeset de cadastro

**Onde.**

- `lib/the_band/tenants/user.ex:106`: `cast(attrs, [:email, :name, :role, :tenant_id])`;
- os chamadores são `Auth.cadastrar_conta/3` (`auth.ex:315`), `Tenants.create_user/2`
  (`tenants.ex:210`, usado por `priv/repo/seeds.exs:41` e pelas fixtures) e `Bootstrap`
  (`bootstrap.ex:161-166`).

**O que é.** A defesa mora no chamador. Hoje a única tela fixa `"role" => "member"`
(`accounts_live/index.ex:108`), e por isso **não há vulnerabilidade hoje**. O segundo chamador de
`cadastrar_conta/3` não vai saber disso. Pode ser uma API de cadastro, uma importação, ou o
`Map.merge` de parâmetros de formulário. Um cadastro com `"role" => "admin"` cria administrador sem
episódio e sem evento.

**O que fecha.**

- `:role` sai do `cast` de `User.changeset/2`;
- `Bootstrap` grava a marca com um changeset próprio e nomeado, `put_change(:role, "admin")`;
- o ato da 072 tem o seu;
- as fixtures de teste ganham um helper de teste que faz o mesmo. Teste com `"role" => "admin"` em
  `create_user/2` passa a criar membro, e o QA precisa varrer `test/` por isso: `ctx.b` de
  `ultimo_admin_ativo_test.exs:28-32` é um exemplo.

A SC-002 se mede no **banco** (S6), e não por `grep`. A guarda que lê código reprova a prosa, e isso
já aconteceu duas vezes nesta base.

### S5 — Média: o alcance dos tokens segue o papel do dono, nos dois sentidos

**Verificado por leitura.** O token não carrega escopo nenhum:

- `ApiAuth` relê o dono por `Tenants.fetch_user/1` **a cada requisição** (`api_auth.ex:80-86`);
- o MCP monta o estado a partir do `conn` a cada requisição (`lib/the_band_web/mcp/servidor.ex:39-45`).

Portanto, **o token de um administrador rebaixado perde o alcance de administração já na próxima
requisição**. Respondendo à pergunta da avaliação: sim, o veredito relê o papel a cada chamada da
API e do MCP. Na tela, não (S1).

**O que fica em aberto.**

1. **Promover amplia silenciosamente todo token vigente da conta promovida**, inclusive um token
   emitido por **outro** administrador para essa conta. Quem emitiu viu o valor em claro uma vez,
   na tela, e pode tê-lo guardado. Se esse emissor foi rebaixado depois, ele passa a ter de novo
   alcance de administração no momento em que o dono é promovido.
2. **Rebaixar não toca nos tokens que o rebaixado emitiu para outros donos**
   (`created_by_user_id`). Somado a S1, essa é a forma de o poder sobreviver.

**O que fecha.** Ver o que a confirmação mostra e o que o rebaixamento faz é decisão do Product
Owner. Proposta:

- a confirmação de **promover** diz quantos tokens vigentes a conta tem, e que eles passam a
  alcançar como administração;
- a confirmação de **rebaixar** diz quantos tokens vigentes o rebaixado **emitiu para outros
  donos**;
- se esses tokens são revogados no ato fica como alternativa, e não como imposição: revogar
  junto mistura dois atos, que é o que `reativar_changeset/1` já recusou fazer.

### S6 — Média: o registro e o papel precisam do banco, como na 070

**O que é.** A FR-005 pede registro somente-acréscimo. A SC-002 pede *"zero escritas de
`users.role` fora do ato"*. As duas só são verificáveis de forma durável no banco. O changeset sozinho
não é integridade (AGENTS §7.3), e um `update_all` ou um `Repo.query!` escrito depois passaria por
fora.

**O precedente está pronto, na 070.**

- `priv/repo/migrations/20261002140000_episodio_de_suspensao.exs`:
  - recusa `DELETE` e `UPDATE`;
  - recusa `TRUNCATE` com trigger por comando (A13a);
- `priv/repo/migrations/20261002140100_estado_tem_episodio.exs`:
  - trigger de constraint **adiado** para "estado tem episódio";
  - `search_path` com `pg_temp` por último (G2);
  - conferência das linhas antigas antes do `CREATE TRIGGER` (G4).

**O que fecha.**

1. A tabela do episódio recusa `DELETE`, `UPDATE` e `TRUNCATE`.
2. Ela leva `CHECK (from_role <> to_role)` e os dois papéis na lista fechada.
3. Leva FK composta `(user_id, tenant_id) → users(id, tenant_id)` e o mesmo para o ator. O índice
   único `users(id, tenant_id)` já existe em `20260929100000_sessoes_de_usuario.exs:35`. Assim, um
   episódio com ator de uma organização e alvo de outra não pode existir.
4. Um trigger adiado em `users`, `AFTER UPDATE OF role`, confere no `COMMIT` que o papel novo é o
   `to_role` do último episódio daquela conta. A criação com `admin`, que só o `Bootstrap` faz,
   grava um episódio de origem (ator nulo, ou origem `bootstrap`), ou o trigger de `INSERT` aceita
   `admin` só quando não há administrador no tenant. O plano escolhe entre as duas e diz o que cada
   uma piora.

**Risco residual declarado.** Como na 070, isso fecha o caminho **por acidente** e **não** fecha o
caminho de quem é dono das tabelas: a aplicação ainda pode desligar trigger (#1131, aberto). Vale
escrever isso no plano com as mesmas palavras.

### S7 — Baixa: `users.role` sem `CHECK`

`priv/repo/migrations/20260809120000_create_tenants_and_users.exs:31` cria a coluna como `:string`
e `null: false`, sem `CHECK`. Valor fora da lista entra por qualquer caminho que não passe pelo
changeset. Um papel desconhecido hoje cai em `User.admin?/1` → `false`, o que falha fechado. Ainda
assim, a coluna é "estado como string livre" (AGENTS §7.7).

A FR-006 já pede o `CHECK`. O que falta dizer: a migração **confere antes** que nenhuma linha viola
o `CHECK`, e se alguma violar, levanta com a contagem em vez de mapear em silêncio. É o
`conferir_contagens!/1` da 070.

### S8 — Baixa: a conta desativada mantém a marca, e reativar a devolve

A spec manda a conta desativada não ter controle nenhum (US3, cenário 1) e diz que *"desativar e
reativar não muda a marca"*. Além disso, o guarda reaproveitado como está recusaria rebaixar
administrador desativado: `user.id not in ativos` → `:ja_desativada` (`tenants.ex:642`).

Consequência: um administrador desativado por `suspected_compromise` continua administrador. A
reativação, que é feita por motivo de rotina, devolve a ele a administração **sem episódio de papel
e sem confirmação que diga isso**.

**Proposta, para decisão do Product Owner.** Permitir **rebaixar** conta desativada. Ela não conta
para o guarda, porque não é administradora ativa, então rebaixá-la não arrisca deixar a organização
sem administrador, e reduz privilégio. A confirmação de reativação passa a dizer *"returns as
administrator"* quando for o caso. Promover conta desativada continua recusado (FR-001).

### S9 — Baixa: o evento de acesso

`AccessEvents.ato_administrativo/4` (`lib/the_band/tenants/access_events.ex:150`) tira o ator do
`Logger.metadata`, que a hook preenche no mount (`hooks.ex:41`). Isso está correto para este caso,
porque o `user_id` da sessão não muda.

Três observações:

- **a recusa por não administrar também é evento.** Ela é o único rastro de uma requisição forjada
  ou de uma aba velha tentando agir (S1/S2). Proposta: `ato_administrativo_recusado` com ato,
  alvo e motivo;
- **L69**: o teste não pode depender do log, que depende do nível configurado. O ato devolve o
  episódio, e o teste asserta sobre ele. O log é registro, e não a prova;
- **a nota livre não vai ao log** (FR-007). Na tela ela é renderizada escapada: nunca `raw/1`. E
  precisa de limite de tamanho no changeset.

### S10 — Baixa, fora do escopo: `pessoas_alcancadas/2` sem tenant

`access.ex:327` concede `:todas` com `User.admin?(user)` e **não** compara `user.tenant_id` com
`tenant.id`. Todas as outras cláusulas de admin do módulo comparam (`:202`, `:268`, `:401`, `:546`,
`:579`, e a cabeça de `operacional?/2`). Não achei caminho de exploração: os chamadores que li passam
`current_tenant`, que é `user.tenant`. Ainda assim, é a mesma forma do #1034, que tinha o mesmo
defeito em outro veredito. Fica registrado para uma issue `bug, security` própria, e **não** para
entrar na 072 (§17, refatoração sem relação).

---

## Emendas propostas à spec, por FR

| FR | Emenda |
|---|---|
| **FR-002** | *"…conferido dentro do ato, **relendo o ator no banco, dentro da transação e sob a trava das contas administradoras ativas do tenant**. A struct recebida fornece só o identificador. Ator que não está no conjunto travado é recusado com `:nao_administra`, e nada é gravado."* (S2) |
| **FR-002a** (nova) | *"Os atos administrativos que criam credencial ou alteram acesso (cadastrar conta, reiniciar senha, emitir token de API, conceder escopo, desativar, reativar) MUST recusar o ator que não é administrador ativo no momento do ato, conferido no banco."* (S1, camada 1). Se o Product Owner preferir manter fora do escopo, a recusa precisa constar como **risco residual aceito**, com quem decidiu, e a 072 não sai para produção sem pelo menos `ApiTokens.criar/4` e `reset_password/3` cobertos. |
| **FR-003** | Acrescentar: *"…e também quando o identificador vem de requisição forjada. A busca do alvo filtra por `tenant_id` e `id` juntos."* |
| **FR-004** | *"…com a mesma trava, **e o papel e o estado do alvo são relidos depois da trava**. `disable_user/4` passa a usar o mesmo guarda."* (S3). No cenário 3 da US2, trocar *"recusado pelo mesmo guarda"* por *"recusado, seja porque o ator já não é administrador, seja pelo guarda do último. A organização termina com pelo menos um administrador ativo, e nenhum ato foi executado por quem já não era administrador no momento do commit."* |
| **FR-005** | Acrescentar: *"…somente-acréscimo **no banco**: `DELETE`, `UPDATE` e `TRUNCATE` são recusados por trigger, ator e alvo pertencem à mesma organização por FK composta, e a nota tem limite de tamanho."* (S6) |
| **FR-006** | Acrescentar: *"`:role` não é campo de cadastro: nenhum changeset de cadastro o aceita. O banco MUST recusar, no commit, uma mudança de `users.role` sem o episódio correspondente. A migração confere as linhas existentes antes de criar o `CHECK` e o trigger, e levanta com a contagem se alguma discordar."* (S4, S6, S7). A SC-002 passa a se medir por esse trigger, e não por busca no código. |
| **FR-007** | Acrescentar: *"A recusa por não administrar também emite evento, com o motivo. O ato devolve o episódio, para que o teste asserte sobre o retorno e não sobre o log (L69)."* (S9) |
| **FR-008** | *"…o ato avisa as telas da conta **depois do commit**. Ao receber o aviso, a tela relê a conta, **substitui a conta guardada no socket** e reaplica a condição da área: na área de administração, a conta que deixou de ser administradora é levada para fora com a frase de `require_admin`. As telas fora da área de administração que decidem por papel passam a decidir pela conta relida. A garantia de 'próxima ação' é dada pelo domínio (FR-002/FR-002a), e o aviso é o que tira a tela."* (S1, camada 2) |
| **FR-009** | Acrescentar: *"O evento da tela leva só o id da conta. O papel de destino nunca vem do cliente: promover e rebaixar são dois eventos, cada um com destino fixo. A confirmação de promover diz quantos tokens de API vigentes a conta tem. A de rebaixar diz quantos tokens o rebaixado emitiu para outros donos."* (S5) |
| **Edge case** (conta desativada) | Decisão do Product Owner sobre S8: rebaixar conta desativada passa a ser permitido, e a reativação de administrador diz isso na confirmação. |
| **Assumption** (sessões) | Manter *"o rebaixamento não encerra as sessões"* só é seguro com FR-002a e FR-008 como emendadas acima. Escrever essa dependência na própria suposição. |

---

## Cenários de ataque para o QA

Regras herdadas do QA, válidas para todos os cenários:

- dois tenants povoados sempre que o cenário tocar isolamento;
- `assert` de que a medida mediu alguma coisa **antes** de qualquer `refute`;
- cada guarda é vista **reprovando** com o defeito injetado, com backup do arquivo antes de
  injetar (memória "git checkout apaga trabalho não commitado").

Nenhum segredo real: senha e token são strings óbvias de teste.

| # | Quem, com o quê | Asserção | Defeito a injetar (o teste tem de reprovar) |
|---|---|---|---|
| A1 | Membro chama o ato de promover a si mesmo **pelo contexto** | `{:error, :nao_administra}`; `refute` papel mudado no banco; `refute` episódio gravado | Remover a conferência do ator no ato |
| A2 | Struct velha: carregar A como admin; B rebaixa A; chamar promover(alvo = A, ator = struct velha de A) | Recusado; no banco, A é `member`; nenhum episódio novo com ator A | Trocar a releitura sob trava por `User.admin?(ator)` |
| A3 | Administrador do tenant 1 promove e rebaixa o id de uma conta do tenant 2, com os dois tenants povoados e o tenant 2 com dois admins | `{:error, :not_found}`; a tela diz "not found" e `refute` "permission"; `refute` qualquer mudança no tenant 2 (`assert` antes que o tenant 2 tem as contas) | `Repo.get(User, id)` sem `tenant_id` |
| A4 | Dois admins se rebaixam em cruz, `Task.async_stream`, 10 repetições (SC-001) | Em **cada** repetição: exatamente um `{:ok, _}`, a outra recusa ∈ {`:nao_administra`, `:ultimo_admin_ativo`}, e admins ativos = 1 | Tirar `lock: "FOR UPDATE"` |
| A5 | A rebaixa B enquanto B desativa A, em paralelo | Admins ativos ≥ 1; nenhuma conta desativada **e** rebaixada pelo mesmo par | Fazer `disable_user` usar o guarda antigo, que casa a struct |
| A6 | A sequência de S3, determinística com barreira de processo (a técnica de `ultimo_admin_ativo_test.exs`, o teste *"relidas com FOR UPDATE"*): desativar C lido como `member` → promover C → C rebaixa A → a desativação prossegue | Admins ativos ≥ 1 no fim | **É o código de hoje**: o teste deve reprovar antes da correção e passar depois |
| A7 | Tela aberta: B com `/api-tokens` montada; A rebaixa B; B envia `escolher_dono` = A e `criar` | `refute` token gravado com `created_by_user_id = B`; a view é redirecionada | (a) Remover a releitura de papel em `reconferir/2`; (b) **separadamente**, remover a conferência do ator em `ApiTokens.criar/4` e enviar o evento **antes** de o aviso chegar (`unsubscribe` do tópico): o teste tem de reprovar nos dois casos |
| A8 | Igual a A7, em `/accounts` com `reset` sobre A | `refute` senha temporária devolvida; a época de A não muda | Igual a A7, sobre `reset_password/3` |
| A9 | Igual a A7, em `/access-scopes` concedendo `organization` a si | `refute` concessão gravada | Trocar a releitura por `User.admin?(socket.assigns.current_user)` |
| A10 | Tela fora de `:admin`: B rebaixado com `repository_live/show` aberta envia `"excluir"` | `refute` exclusão gravada | Remover a reatribuição de `:current_user` em `reconferir/2` |
| A11 | O rebaixado promove a si mesmo pela aba velha de `/accounts` | Recusado; no banco, continua `member` | Igual a A2 |
| A12 | `Tenants.cadastrar_conta(tenant, %{"email" => …, "role" => "admin"}, admin)` direto | A conta nasce `member`; nenhum episódio | Recolocar `:role` no `cast` |
| A13 | Banco: `Repo.update_all(set: [role: "owner"])` | `check_violation` | Remover o `CHECK` da migração |
| A14 | Banco: `Repo.update_all(set: [role: "admin"])` numa transação sem episódio | Erro no `COMMIT` com o nome da constraint; o papel continua `member` | Remover o trigger adiado |
| A15 | Banco: `DELETE`, `UPDATE` e `TRUNCATE` no episódio | Exceção nas três | Remover cada trigger, um por vez |
| A16 | API: token de B, admin. Pedir o painel de uma pessoa fora do alcance de membro: `assert 200` com motivo `admin`. Rebaixar B e repetir | Segundo pedido recusado, sem motivo `admin` no log de leitura | Fazer `ApiAuth` usar uma struct do dono guardada (por exemplo, papel copiado para o token) |
| A17 | MCP: igual a A16, pela ferramenta que lê pessoa | Igual a A16 | Igual a A16 |
| A18 | O ato com nota `"nota-de-teste-nao-logar"`, com `capture_log` em nível `:debug` | `assert` que o episódio devolvido tem ator, alvo, de, para e instante; `refute` a nota no log | Incluir a nota no `extra` de `ato_administrativo/4` |
| A19 | Rebaixar a si mesmo, com outro admin ativo | `{:ok, _}`; a própria aba é redirecionada para fora de `/accounts` | Pular o aviso para o próprio ator |
| A20 | Promover quem já é admin, e rebaixar quem já é membro | Recusa de estado mudado; nenhum episódio | Tirar a releitura do alvo depois da trava |

Este cenário **não** é de ataque e documenta comportamento (S5): o token de M, membro, passa a
alcançar como administração depois que M é promovido. O teste afirma o comportamento, e a tela o
anuncia.

---

## Risco residual, mesmo com as emendas

- **Dono das tabelas desliga trigger** (#1131, aberto). Os triggers de S6 fecham o acidente, e não a
  aplicação comprometida.
- **Janela entre o commit e o aviso**, para os atos que ficarem fora da FR-002a. Um evento que já
  está na caixa de mensagens executa com o papel antigo.
- **Tokens emitidos pelo rebaixado para outros donos** continuam vivos se o Product Owner não decidir
  revogá-los (S5).
- **Valor de token visto por um emissor** que depois perdeu a administração ganha alcance de novo
  quando o dono é promovido (S5). Isso é inerente a token emitido por terceiro, e não é desta feature.
- **`Bootstrap.ja_ha_administrador?/0` é global** e conta administrador desativado. Ele não é caminho
  de recuperação para uma organização sem administrador, e nem deve virar: decidir isso é mudança do
  contrato da 052.

## O que eu NÃO verifiquei

- **Nenhum gate e nenhuma ferramenta foi rodada**: `mix sobelow`, `mix hex.audit`, `mix deps.audit`,
  `mix credo` e `mix test`. A instrução desta avaliação vedou. Tudo acima é leitura.
- **O protótipo** em `specs/072-papel-de-administrador/prototipo/`, que está sendo escrito em paralelo.
  Não li, e a FR-009 depende dele.
- **Todos os `handle_event` que decidem por papel.** Amostrei pelo `grep` de `admin?` e
  `role == "admin"` em `lib/`. Uma tela que decida por outro caminho, como um componente que recebe a
  conta por atributo, não foi vista.
- **`teams_live/show.ex:177`**: o comentário diz que a conferência saiu do `handle_event`. Não li para
  onde foi.
- **A área da plataforma (070)**: o `grep` não achou escrita em `users.role` em `lib/`, mas não li
  `lib/the_band/platform/` nem `lib/the_band_web/plataforma/` inteiros.
- **A proteção do websocket do LiveView** (`check_origin`, token CSRF do `connect`). Assumi como
  verificada pela 045 e pela 070, sem reler `config/runtime.exs` nem `TheBandWeb.Origens`.
- **`Sessions.conferir/2` por completo.** Li só que ela relê a conta e pré-carrega o tenant
  (`lib/the_band/tenants/sessions.ex:85-90`).
- **Quantas organizações em produção têm hoje mais de um administrador**, e se algum `users.role`
  existente viola o `CHECK`. É precondição da migração, e precisa de medição, não de suposição.
- **A FR-008 original da spec 045**, para saber se o texto prometido difere do que a 072 entrega.
- **Os inventários de `docs/seguranca/`** além do título, e as issues `security` abertas além da
  listagem (#1162, #1140, #1135, #1131). Nenhuma delas toca `users.role` pelo título. O conteúdo
  não foi lido.
