# Avaliação de segurança — 070, US1: a correção do D-9 e a transação da suspensão

Agente `security`, 2026-10-02, branch `feature/1057-070-us1`. Quem avalia não escreveu o desenho
nem o código. **Leitura de código apenas**: nenhum teste nem gate foi rodado nesta avaliação (base
de teste compartilhada; a instrução foi não rodar), então nada aqui é veredito de gate. O veredito
de gate continua sendo o código de saída de `mix gates`, que é do QA.

Arquivos lidos: `lib/the_band_web/plataforma/organizacao_controller.ex`,
`lib/the_band_web/plataforma/telas_html.ex` (`organizacao/1`, `formulario_do_ato/1`),
`lib/the_band/platform/suspensions.ex`, `lib/the_band/platform/sessions.ex`,
`lib/the_band/platform/grants.ex` (`revogar/3`, `reiniciar_credencial/2`),
`lib/the_band/tenants.ex` (`trocar_estado/3`), `lib/the_band/tenants/sessions.ex`
(`encerrar_da_organizacao/1`, `avisar_encerramento/1`), `lib/the_band_web/plugs/current_scope.ex:79`,
`lib/the_band_web/plugs/api_auth.ex:79`, `lib/the_band/platform/operator.ex`,
`priv/knowledge_base/rules/platform_tenant_suspension.yaml`,
`test/the_band_web/plataforma/historico_e_ato_test.exs:207-228`, e contra eles
`contracts/suspensao.md`, `research.md` R8 e `prototipo/conferencia.md` D-9.

## Resumo

| # | ponto | veredito | severidade de achado novo |
|---|---|---|---|
| 1 | D-9, recusa `:ja_suspensa` / `:nao_suspensa` | **fecha** o caminho que foi corrigido | — |
| 1a | **o mesmo defeito pelas recusas de razão/nota e de confirmação** | **não fecha** | **S-US1-1, Média** (A04; ASVS V1.1 / V11.1) |
| 1b | sucesso e PRG, voltar do navegador, reenvio do `POST` | fecha | — |
| 1c | confirmação por slug digitado (Q2) | defesa certa para o que se propõe, **não** para troca de ato | S-US1-2, Baixa |
| 2a | ordem dos passos contra R8 | fecha | — |
| 2b | `FOR SHARE` e serialização com revogação e reinício (A15) | fecha | — |
| 2c | aviso às telas só depois do `commit` (A2) | fecha, com risco residual de chamador futuro | S-US1-3, Baixa |
| 2d | nenhum `%Tenant{}` no retorno (D1-d) | fecha | — |
| 2e | duas suspensões paralelas | fecha | — |
| 2f | `trocar_estado/3` levanta fora de transação | correto como guarda de bug; prova em teste não verificada | Informativo |
| 2g | episódios com `%Operator{}` inteiro pré-carregado | endurecimento | S-US1-4, Baixa |

---

## 1. D-9 — o formulário depois da corrida

### 1. A cláusula corrigida: fecha

`organizacao_controller.ex:74-75`: `{:error, motivo} when motivo in [:ja_suspensa, :nao_suspensa]`
re-renderiza com `%{}`. Em `telas_html.ex`, `formulario_do_ato/1` só preenche `reason` (`checked`),
`note` (texto do `textarea`) e `confirm_slug` (`value`) a partir de `@valores`; com o mapa vazio, os
três saem vazios. O caminho do achado (aba 2 envia a suspensão depois de a aba 1 já ter suspendido,
`:ja_suspensa`, a página relê o estado e mostra o formulário de reativar) não carrega mais nada.

O teste `historico_e_ato_test.exs:209` cobre a direção suspender → `:ja_suspensa`, com três `refute`
(nota, `value="<slug>"`, `checked`) e uma asserção positiva de que a página é a do outro ato
(`"Reactivate #{t.name}"`). Isso prova que o teste mediu alguma coisa. A conferência diz que ele foi
visto reprovando com o defeito injetado; **não reconferi**. Lacuna do teste: **a direção inversa
(`reativar` → `:nao_suspensa`, a página passa a mostrar o formulário de suspender) não tem teste.**
É a mesma cláusula, mas com o D-9 escrito para as duas direções, falta a segunda prova.

### 1a. S-US1-1 — o mesmo defeito, pelas outras recusas (Média)

**O que é.** A correção decide pelo **motivo da recusa** se os valores vão junto, mas a página
decide pelo **estado relido** qual formulário desenha (`telas_html.ex`, `suspensa?:
assigns.resumo.status == "suspended"`). Toda recusa que não seja `:ja_suspensa`/`:nao_suspensa`
continua levando `valores` (`organizacao_controller.ex:77-78` e `:81`), e o estado pode ter mudado
entre o carregamento do formulário e o `POST` **sem que o ato descubra**, porque a recusa acontece
antes do passo `:estado`.

**Onde.** `organizacao_controller.ex:77-81`; a ordem que torna isso alcançável é
`suspensions.ex:134-136` (`:razao` antes de `:estado`) e o `if` da confirmação em
`organizacao_controller.ex:55`, que nem chama o ato.

**Caminho concreto** (dois operadores legítimos; não é preciso atacante):

1. Operador A abre a página de `acme` (ativa), escolhe `other`, **não** escreve a nota, digita
   `acme` na confirmação;
2. Operador B suspende `acme` (por exemplo, `suspected_compromise`);
3. A envia. A transação recusa no passo `:razao` (nota obrigatória para `other`), antes de `:estado`
   ver que a organização já está suspensa. Volta `{:error, %Changeset{}}`;
4. `pagina/6` relê o resumo: `suspended`. Desenha o formulário de **reativar** com `valores`:
   `other` existe também na lista de reativação (`platform_tenant_suspension.yaml`, código `other`
   sem `offered_only_against`), então vem `checked`; `confirm_slug` vem `acme`;
5. A frase de recusa é a da suspensão: *"Not suspended. A note is required for this reason (Other).
   Write what was seen and why it calls for suspension."* — **nada diz que o estado mudou**;
6. A escreve a nota, como a tela mandou, e clica. O botão agora é *"Reactivate Acme"*: reativa a
   organização que B acabou de suspender por suspeita de comprometimento.

A variante pela confirmação (`:confirmacao`, `organizacao_controller.ex:81`) é a mesma, com a
diferença de que o `confirm_slug` levado é o errado e A precisa redigitá-lo — um passo a mais, e a
mesma ausência de aviso. A direção inversa (reativação recusada por nota, alguém reativou no meio)
leva ao **suspender**; é o lado que falha fechado, mas continua sendo um ato que o operador não
escolheu.

**Por que Média, e não Alta.** Não há dado de outro tenant alcançável, nem segredo, nem contorno de
autenticação. Exige dois operadores agindo sobre a mesma organização em segundos e um operador que
não lê o título nem o botão (que muda de texto e de cor, `btn-error` → `btn-primary`). A reativação
não devolve sessão nem token (FR-013), e o episódio registra quem reativou. Mas é uma garantia
declarada — o D-9 — que vale só para um dos três motivos de recusa, e o ato em jogo devolve o acesso
de uma organização inteira. É o critério de Média desta casa: defesa que depende de o caminho certo
ter sido lembrado.

**Consequência para o negócio.** Uma organização suspensa por suspeita de comprometimento volta a
aceitar entrada por um clique de um colega que estava tentando suspendê-la, e a tela não avisou a
nenhum dos dois.

**O que fecha.** Tirar a decisão do motivo e pô-la no estado, num lugar só: os `valores` vão para a
página **somente se o formulário que será desenhado é o do ato enviado** (`:suspender` com
`status == "active"`, `:reativar` com `status == "suspended"`); senão vão vazios, e a frase de
recusa passa a ser a do estado que mudou (a mesma de `:ja_suspensa`/`:nao_suspensa`), porque é o
fato mais importante da tela. A decisão naturalmente mora em `pagina/6`, que é quem tem o resumo, e
a cláusula especial da linha 74 deixa de ser necessária. Assim uma recusa nova que se acrescente
amanhã já nasce coberta.

**O teste que prova** (cenário para o QA; todos com o estado mudado **antes** do `POST`, por outra
sessão de operador via `Platform.suspender/3`, o que torna a corrida determinística):

| caso | envio de A | esperado no `422` |
|---|---|---|
| razão sem nota | `/suspension`, `reason: "other"`, sem `note`, `confirm_slug: slug` | `"Reactivate #{nome}"`; `refute "checked"`; `refute value="<slug>"`; a frase diz que já está suspensa |
| confirmação errada | `/suspension`, `reason: "other"`, `note: "nota de A"`, `confirm_slug: slug <> "x"` | idem, e `refute "nota de A"` |
| direção inversa, `:nao_suspensa` | organização suspensa, B reativa, A envia `/reactivation` completo | `"Suspend, sign everyone out"`; os três `refute` |
| direção inversa, nota | organização suspensa, B reativa, A envia `/reactivation` com `other` sem nota | idem |
| controle positivo | **sem** corrida: `/suspension` com `other` sem nota | o formulário de suspender **mantém** `checked` e o slug (os valores continuam úteis quando o ato é o mesmo) |

O controle positivo é obrigatório: sem ele, "nunca levar valores" passaria no teste e destruiria a
usabilidade que a re-renderização existe para dar. **Defeito a injetar**: voltar
`organizacao_controller.ex:78` e `:81` a passar `valores` sem a condição de estado (é o código de
hoje) — as duas primeiras linhas da tabela têm de reprovar.

### 1b. Sucesso, PRG, voltar e reenviar: fecha

- **Sucesso**: `put_flash` + `redirect` (`organizacao_controller.ex:59-62`); o `GET` de `show/2`
  renderiza com `%{}` (`:42`). Nada digitado atravessa o `302`.
- **Voltar do navegador**: toda resposta de `/platform` sai com `Cache-Control: no-store`
  (`operator_scope.ex:70-75`), então a página anterior é pedida de novo e desenhada pelo estado
  atual. Mesmo que um navegador restaure campos digitados, o formulário restaurado **posta para a
  ação dele** (a URL fixa o ato: `/suspension` nunca reativa), e o servidor recusa pelo estado no
  `UPDATE` condicional — caindo no caminho já corrigido, com o outro formulário vazio.
- **Recarregar o `422`**: reenvia o mesmo `POST`, para o mesmo ato; recusa por estado ou repete a
  recusa anterior. Não troca de ato.

A troca de ato só acontece quando **o servidor** desenha o formulário do outro ato com dados
digitados para o primeiro; por isso o S-US1-1 é o único caminho que encontrei.

### 1c. A confirmação por slug (Q2): a defesa certa, para outra coisa (S-US1-2, Baixa)

O slug digitado confirma **a organização**, não **o ato**: é a mesma string nos dois formulários.
Ele defende bem contra o clique sem leitura e contra o envio automático (o CSRF já está no
formulário), e deve ficar. Mas é exatamente por ser igual nos dois atos que o `confirm_slug` levado
para o outro formulário vale como confirmação dele — o D-9 inteiro depende disso.

**Endurecimento proposto (Baixa, decisão de protótipo, não de código):** a confirmação carregar o
verbo, `suspend acme` / `reactivate acme`. Assim um valor levado para o formulário errado deixa de
confirmar, por construção, independentemente de qualquer cláusula do controller. Não substitui a
correção do S-US1-1 (a razão e a nota continuariam indo), só faz o pior caso deixar de ser um
clique. Fica com o Design e o Product Owner, porque muda a frase aprovada.

---

## 2. A transação, agora `Repo.transaction/1`

### 2a. Ordem dos passos: fecha

`suspensao/3` (`suspensions.ex:133-144`): `:autorizacao` → `:razao` → `:estado` → `:episodio` →
`:sessoes` → `:tokens`. `reativacao/3` (`:148-159`): `:autorizacao` → `:estado` → `:aberto` →
`:razao` → `:episodio` → `:sessoes`. É a ordem de R8 e do contrato, com a emenda de 2026-10-02 que
põe `:estado` antes de `:aberto` na reativação (comentário em `:146-147`). Cada passo devolve o nome
pela função `passo/2`, e `Repo.rollback({nome, valor})` preserva o que o `Multi` dava: quem recusou.
`vocabulario/0` e `get_by_slug/1` rodam antes da transação, como o contrato (U1) diz.

Observação sem severidade: `traduzir/2` (`:273-283`) não tem cláusula para `:sessoes`, `:tokens`,
nem para `:aberto` com outro motivo. Hoje são inalcançáveis (`encerrar_da_organizacao/1` e
`revogar_por_suspensao/2` só devolvem `{:ok, _}`); se um dia recusarem, o resultado é
`FunctionClauseError` **depois** do `rollback` — falha ruidosa, não silenciosa, o que é o certo
(princípio VIII).

### 2b. `FOR SHARE` e A15: fecha

`Sessions.autorizada(sessao, lock: true)` (`sessions.ex:139-160`) emite um `SELECT … FOR SHARE` sem
`OF`, sobre `platform_operator_sessions JOIN platform_operators JOIN platform_operator_grants`
(inner join, `revoked_at IS NULL`). No PostgreSQL, `FOR SHARE` sem `OF` trava **as linhas de todas
as tabelas da junção**: sessão, operador e concessão — mais do que A15 pede, e a mais é a linha do
operador, o que ajuda.

Contra cada concorrente:

| concorrente | o que ele faz | conflito com o `FOR SHARE` | quem perde |
|---|---|---|---|
| `Grants.revogar/3` (`grants.ex:110-133`) | `FOR UPDATE` no operador, depois `UPDATE` na concessão | os dois conflitam com `FOR SHARE` | revogação primeiro: a suspensão espera, reavalia a linha da concessão já com `revoked_at` (recheck de `READ COMMITTED`) e não a encontra → `:nao_autorizado`. Suspensão primeiro: a revogação espera o `commit`; o ato aconteceu antes da revogação, o que é legítimo |
| `Grants.reiniciar_credencial/2` (`grants.ex:82-102`) | `FOR UPDATE` no operador, `FOR UPDATE` nas sessões abertas, `password_epoch + 1` | conflita nas duas linhas | reinício primeiro: o recheck vê `password_epoch` diferente da sessão → `:nao_autorizado`. Suspensão primeiro: o reinício espera |
| `Sessions.encerrar/1` (logout) | `UPDATE` na sessão | conflita | logout primeiro: `ended_at` não nulo no recheck → recusa |
| `registrar_uso/2` (plug, mesma sessão em outra aba) | `UPDATE last_seen_at` | conflita | só serializa; o recheck continua passando. Custo: a outra requisição espera o fim do ato |

Não encontrei ordem de travas que produza impasse: os dois concorrentes que escrevem começam pela
linha do operador, e o ato trava sessão/operador/concessão no **primeiro** comando, antes de tocar
`tenants`, sessões de organização e tokens, que nenhum deles toca.

### 2c. O aviso só depois do `commit` (A2): fecha, com um residual (S-US1-3, Baixa)

`depois_do_commit/4` (`suspensions.ex:245-263`) roda sobre o **retorno** de `Repo.transaction/1`,
fora da função anônima: os `avisar_encerramento({:sessao, id})` e o `ato_de_plataforma` só acontecem
quando o `commit` já voltou. É o que A2 pede, e o aviso é por id de sessão, sem tópico por
organização.

**Residual**: isso só é verdade enquanto `suspender/3` e `reativar/3` forem chamados **fora** de
outra transação. Chamados dentro de uma (um futuro comando de release, ou um job que envolva o ato),
`Repo.transaction/1` vira savepoint, o "depois" deixa de ser depois do `commit` real, e a hook
reconferiria uma sessão ainda aberta para o banco — a tela continuaria. Hoje o único chamador é o
controller. **O que fecha**: o mesmo guarda que `trocar_estado/3` tem, invertido —
`if Repo.in_transaction?(), do: raise …` no começo dos dois atos públicos. **Teste**: chamar
`suspender/3` dentro de `Repo.transaction/1` e esperar o `raise`. Ressalva de prova: ver 2f, o
sandbox pode tornar esse teste impossível de escrever de forma honesta.

E uma nota de método, igual à da L69: **no sandbox de teste tudo roda numa transação só e numa
conexão só**, então nenhum teste da suíte consegue distinguir "avisou antes" de "avisou depois do
`commit"` — a hook relê pela mesma conexão e vê a sessão encerrada nos dois casos. A2 está fechado
por leitura de código, não por teste. Isso vai para a lista do que não foi verificado.

Falha entre o `commit` e o aviso (nó cai): as telas abertas não recebem a mensagem. O dado está
certo — `current_scope.ex:79` e `api_auth.ex:79` recusam organização não `active` a cada requisição
e a cada uso de token — então o que sobra é uma tela LiveView já montada até o próximo evento que
releia a sessão. Fica como informativo: é território do #1044, que não reavaliei.

### 2d. Nenhum `%Tenant{}` no retorno (D1-d): fecha

- sucesso: `{:ok, ep}` com `%Suspension{}` (`:262`). O schema não tem `belongs_to :tenant`
  (`suspension.ex:12`), só `tenant_id`; as associações são aos operadores, não carregadas aqui;
- recusa: `do_contrato/2` devolve átomo ou `%Changeset{}`. Os changesets saem de `%Suspension{}`
  (`abertura/3`, `fechamento/3`, `Repo.insert/update`), nunca de `%Tenant{}`; o `{:ok, tenant}` de
  `trocar_estado/3` é descartado (`{:ok, _}`) e `rollback` só leva `{nome, valor}` de passos que
  recusaram, cujos valores são átomos ou changesets de `Suspension`;
- o terceiro elemento `tenant_id` de `{:error, motivo, tenant_id}` é consumido por
  `registrar_recusa/3` (`:289-290`) e não sai.

**Teste que prova** (sugestão para o QA, se ainda não existir): para cada retorno — sucesso e cada
motivo alcançável —, `refute inspect(resultado, limit: :infinity) =~ "%TheBand.Tenants.Tenant{"`.
**Defeito a injetar**: devolver `{:ok, %{ep | tenant: tenant}}` ou incluir o `tenant` no `rollback`.

### 2e. Duas suspensões paralelas: fecha

Duas transações, mesma organização (dois operadores, ou duplo clique): os `FOR SHARE` do passo
`:autorizacao` são compatíveis entre si. No passo `:estado`, o `UPDATE … WHERE id = ? AND status =
'active'` da segunda espera a trava de linha da primeira; com a primeira confirmada, o `READ
COMMITTED` reavalia a condição sobre a versão nova, `status = 'suspended'`, e atualiza **zero**
linhas; `trocar_estado/3` confere existência e devolve `:estado_mudou` → `:ja_suspensa`. Se de
algum modo a condição passasse, o índice parcial `tenant_suspensions_aberto_index` recusaria o
segundo episódio aberto, e `traduzir(:episodio, …)` (`:280-281`) o converte também em
`:estado_mudou`. Duas defesas, a segunda no banco. Suspensão contra reativação em paralelo: a mesma
linha de `tenants` serializa, e as condições `active`/`suspended` do `WHERE` são mutuamente
exclusivas.

O que **não** é fechado por esta transação, e o contrato já declara (O8): uma sessão de organização
ou um token criados por uma transação concorrente que confirma depois do `encerrar_da_organizacao`
não são encerrados pela suspensão. O dano é contido pela conferência de estado a cada requisição
(`current_scope.ex:79`, `api_auth.ex:79`) e pelo reencerramento na reativação (FR-015).

### 2f. `trocar_estado/3` levanta fora de transação: informativo

`tenants.ex:155-156` levanta `ArgumentError` se não houver transação. É `raise` para bug, não para
caso de negócio (§7.7), e protege o invariante "estado só com episódio" junto com o trigger adiado.
Correto. **Não verifiquei** se há teste que prove o guarda; e no sandbox do Ecto o processo de
teste costuma estar dentro de transação, o que pode tornar `Repo.in_transaction?()` verdadeiro e o
guarda indemonstrável na suíte. Se o QA não conseguir vê-lo reprovar, o registro honesto é "guarda
não provado em teste", e não "coberto".

### 2g. S-US1-4 — episódios com o `%Operator{}` inteiro (Baixa)

`organizacao/2` (`suspensions.ex:86-93`) faz `preload: [:suspended_by_operator,
:reactivated_by_operator]`, e as structs completas vão para os `assigns` da página. Elas carregam
`password_hash`, `setup_code_hash`, `enrollment_code_hash`, `ack_code_hash` (todos `redact: true`,
`operator.ex:24-38`; `totp_secret` com `load_in_query: false`). A tela só usa `.name`. Não há
exposição hoje — `redact` cobre `inspect/1`, e o template não os renderiza —, mas é dado de
credencial do papel mais poderoso da plataforma passeando por `assigns` sem necessidade
(ASVS V8.3, minimização). **O que fecha**: preload com consulta que selecione `id` e `name`, ou um
`select` com o nome por junção. **Teste**: asserir que os episódios devolvidos por
`Platform.organizacao/2` têm `password_hash` nulo. Sem prazo.

---

## O que NÃO verifiquei

- **Nenhum teste nem gate foi executado** por mim; o que digo sobre a prova do D-9 com defeito
  injetado é o que a conferência registra, não o que vi;
- a direção `:nao_suspensa` do D-9 não tem teste (1);
- o comportamento real do recheck de `READ COMMITTED` com `FOR SHARE` sobre junção foi raciocinado
  pela semântica documentada do PostgreSQL, **não medido** com duas conexões reais; um teste de
  integração com duas conexões fora do sandbox (`:integration`) é o que provaria 2b e 2e;
- A2 só por leitura: o sandbox não distingue antes e depois do `commit` (2c);
- o guarda de `trocar_estado/3` em teste (2f);
- a hook do #1044 e o comportamento de um LiveView já montado de uma organização suspensa;
- `ApiTokens.revogar_por_suspensao/2` por dentro (o `WHERE`, o tenant, o `revoked_by_suspension_id`);
- o trigger adiado de T044a e a migração `not_recorded`;
- o resto da US1 fora destes dois pontos: a lista de organizações, as rotas, os plugs
  `require_operator`, a CSP da borda e os eventos de acesso (`AccessEvents.*`) — campos e ausência de
  segredo neles;
- concorrência entre o ato e a criação de sessão/token de organização (O8) além do que o contrato
  declara.

## Achados

| id | severidade | onde | o que fecha |
|---|---|---|---|
| S-US1-1 | **Média** (A04; ASVS V1.1, V11.1) | `organizacao_controller.ex:77-81`, com `suspensions.ex:134-136` e `telas_html.ex` (`suspensa?`) | levar `valores` só quando o formulário desenhado é o do ato enviado; frase do estado que mudou; teste da tabela de 1a com controle positivo |
| S-US1-2 | Baixa | confirmação de Q2, `telas_html.ex` (`confirm_slug`) | confirmação com o verbo; decisão de protótipo |
| S-US1-3 | Baixa | `suspensions.ex:104-129` | recusar ser chamado dentro de transação, para A2 continuar verdadeiro |
| S-US1-4 | Baixa (ASVS V8.3) | `suspensions.ex:86-93` | preload só de `id` e `name` do operador |

---

## Resolução (2026-10-02, por quem implementa)

| achado | o que mudou | prova |
|---|---|---|
| **S-US1-1**, Média | `organizacao_controller.ex`: `conferir_o_formulario/3` compara o ato enviado com o formulário que a página desenha pelo estado **relido**. Se diferem, o formulário vem vazio e a frase é a do estado que mudou (`already suspended` ou `is not suspended`), qualquer que tenha sido a recusa. Substitui a cláusula do D-9, que decidia pelo motivo | `historico_e_ato_test.exs`: as quatro corridas da tabela acima e o controle positivo. Com o defeito injetado (os valores levados sempre), as quatro e o caso do D-9 reprovaram |
| S-US1-2, Baixa | **não mudou**: a confirmação levar o verbo muda a frase aprovada (Q2). Fica para o Design e o Product Owner | — |
| S-US1-3, Baixa | `suspender/3` e `reativar/3` levantam `ArgumentError` quando chamados dentro de outra transação: o aviso às telas só sai depois do `commit` real se o ato abrir a própria | `suspender_test.exs`. Com a guarda retirada, reprovou |
| S-US1-4, Baixa | `organizacao/2` pré-carrega de quem agiu só `id` e `name` | `suspender_test.exs`. Com a struct inteira, reprovou |
| 2f, Informativo | a prova existe: no sandbox, `Repo.in_transaction?/0` é falso fora de `Repo.transaction/1` (medido), e `trocar_estado_test.exs` reprova com a guarda retirada | — |
