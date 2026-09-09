# O que consertar agora — o risco do sistema em produção, separado do requisito de feature

**Data**: 2026-09-09 · **Versão avaliada**: `v0.6.0` em `app.theband.dev` · **Branch da
avaliação**: `security/o-que-consertar-agora` a partir de `development` (`f4bdeeb`)

> **Nota de estado, para quem ler isto em `development`.** O documento companheiro,
> `docs/seguranca/2026-09-09-api-com-token.md`, **ainda não está em `development`** nesta data
> — ele vive na branch `docs/mkdocs-em-developers`, junto das entradas de nav do `mkdocs.yml`
> que citam os dois. O link abaixo resolve quando os dois chegarem juntos; o site só é
> construído em `main` (`.github/workflows/docs.yml:18-19`), então nada quebra no caminho.

Este documento responde a uma pergunta diferente da de
[`2026-09-09-api-com-token.md`](2026-09-09-api-com-token.md). Aquele declara a superfície de
risco de uma feature que **ainda não tem código** — os dez achados altos de lá são requisito,
já numerados como FR-070 a FR-078 na spec 061 e decididos na ADR 0009. Este aqui é sobre o
sistema que **está rodando com dado real**, e nada nele depende de a 061 existir.

A âncora foi a §11 daquele documento (*"riscos que já existem hoje"*). Ela foi ampliada, e o
resultado mudou de forma: **quatro dos achados abaixo foram medidos com teste, não deduzidos
por leitura** — o que confirmou dois que eu havia classificado como médios de desenho e
levantou um terceiro que eu não havia visto.

---

## 0. As ferramentas, o que elas mediram, e o código de saída

Rodadas contra a árvore de `development` em 2026-09-09. **Redirecionadas para arquivo e lidas
depois** — nunca por `| tail`, que devolveria o código de saída do `tail` (constituição,
princípio XI).

| Comando | Código de saída | O que saiu |
|---|---:|---|
| `mix gates` (1ª execução, árvore de `development` em `f4bdeeb`) | **0** | `15 gates verdes` — **é este o veredito** |
| `mix gates` (2ª execução, para reconferir depois do documento) | **1** | reprovou em `knowledge.validate` por **causa ambiental**, não por regressão — ver a nota abaixo |
| `mix sobelow --exit low --skip` | **0** | `... SCAN COMPLETE ...`, nenhum achado |
| `mix hex.audit` | **0** | `No retired or security advisory packages found` **+ o aviso de que a exceção do `mix.exs` ficou obsoleta** (achado H11) |
| `mix deps.audit` | **0** | `No vulnerabilities found.` |
| segundo validador próprio (script) | **0** | 56 pacotes travados × 28 arquivos de aviso comparados → **0** versões em faixa vulnerável |

**A nota sobre a segunda execução, porque ausência de erro lida como resultado é o defeito
reincidente desta casa — e o inverso também precisa ser dito.** A segunda passagem reprovou com
saída 1, e **não** por causa deste documento (que é um arquivo Markdown, lido por gate nenhum).
Ela reprovou porque, no meio da execução, a árvore de dependências foi **apagada** por uma
troca de branch — o efeito da entrada `deps` commitada como link simbólico, que é o achado
**H12**. As 56 dependências passaram a responder *"the dependency is not available"*, e
`ls deps` devolveu zero pacotes.

Registro isto em vez de reportar só o verde da primeira execução por dois motivos: **o veredito
é o código de saída, e houve dois**; e a reprovação é a evidência que subiu a severidade de H12
de Baixa para Média. O verde que sustenta este documento é o da **primeira** execução, sobre a
árvore de `development` em `f4bdeeb`, antes de qualquer alteração minha.

### Que as ferramentas mediram, e não que nada apareceu

Zero achados é o estado normal desta base, e é **indistinguível de conversor quebrado**. Cada
ferramenta foi provada:

**Sobelow.** Injetado um `send_file/3` sobre parâmetro de requisição num controller de
mentira. O Sobelow o achou —
`Traversal.SendFile: Directory Traversal in send_file - High Confidence`, **saída 1**. O
arquivo foi removido, a remoção foi **conferida com `test ! -f`** e a varredura voltou a
**saída 0** com zero achados de `Traversal`. A ferramenta lê o que eu acho que ela lê.

**`mix deps.audit`.** A base de avisos que o `mix_audit` consulta não vem no pacote: é um
clone em `~/.local/share/elixir-security-advisories-mirego`, e um clone vazio ou velho
produziria o mesmo *"No vulnerabilities found"*. Medido: **118 arquivos de aviso**, último
commit da base em **2026-09-04**, e ela **contém** avisos para pacotes que esta base usa —
`bandit` 7, `phoenix` 5, `plug` 4, `ecto` 2, `req` 2, `decimal` 1.

**O segundo validador.** Escrito para conferir, independentemente do `mix_audit`, cada versão
de `mix.lock` contra as faixas `vulnerable_version_ranges` da mesma base. Ele carrega a guarda
que o resultado exige: **se nenhum aviso for comparado, ele sai com erro em vez de imprimir
zero**. Comparou 28 arquivos, achou 0, e provou o próprio comparador — `bandit 1.10.4` casa
com `>= 1.0.0, < 1.11.0` do `GHSA-375f-4r2h-f99j`, enquanto a versão travada, `1.12.5`, não.
Os dois validadores concordam.

E esse aviso do Bandit importa mais que os outros aqui, porque ele descreve exatamente o
mecanismo do qual o cookie desta plataforma depende: *"Bandit trusts client-supplied URI
scheme on plaintext connections"* — `conn.scheme` refletido do pedido do cliente, o que
enganaria `Plug.SSL` e o `secure: true` do cookie. **Corrigido em 1.11.0; esta base está em
1.12.5, e portanto não é afetada.** Verificado, e não presumido.

---

## 1. O que é de hoje e o que é da feature — a separação, em uma tabela

| Grupo | Onde está registrado | O que fazer com ele |
|---|---|---|
| **risco do sistema hoje** | **este documento**, H1 a H14 | virar issue e priorizar |
| requisito da API com token | spec 061 FR-070 a FR-078, ADR 0009, `2026-09-09-api-com-token.md` §3 a §10 | já está no ciclo; não é conserto |
| falso positivo de metadado | `2026-09-08-decimal-expoente-ilimitado.md` | nada, exceto H11 (a exceção ficou obsoleta) |

O critério da separação foi um só: **existe caminho de exploração contra o código que está
rodando hoje?** O achado A01-6 do documento da API é o exemplo de por que o critério precisou
de cuidado — ele tem duas metades. *"O token sobrevive ao desligamento"* é requisito da 061.
*"Não existe estado de conta desativada"* é de hoje, e virou H3 aqui — ampliado, porque medir
mostrou que a lacuna é maior do que a coluna que falta.

---

## 2. Os achados, ordenados por severidade

Cada um traz: **onde** (arquivo e linha), **o caminho concreto**, **a consequência para o
negócio**, **o conserto mínimo** e **o que NÃO muda**, **se exige migração**, e **se dá para
consertar sem release**.

A severidade é minha; **a prioridade é do Product Owner**. Achado alto é *recomendação* de
bloqueio, e liberar com ele aberto é decisão dele — que precisa ir para
`docs/releases/vX.Y.Z.md` como risco residual aceito, com quem decidiu e por quê, como a
v0.6.0 já fez com a exceção do `decimal`.

---

### H1 — `POST /set-password` troca a senha sem exigir a atual

**Severidade: Alta** · OWASP A07 · ASVS V2.1.5 (*troca de senha exige a senha atual*)
· **MEDIDO com teste**

**Onde.**

- `lib/the_band_web/controllers/session_controller.ex:83-97` — `set_password/2`. O `with`
  confere três coisas: que há `user_id` na sessão, que a conta existe, e que o
  `session_token` casa. **Não confere `must_change_password`**;
- `lib/the_band/tenants/auth.ex:153-158` — `set_password/3` grava a senha que recebe, sem
  olhar o estado da conta;
- `lib/the_band/tenants/user.ex:119-140` — `senha_changeset/3` gira o `session_token` e
  põe `must_change_password: false`.

**O caminho concreto.** Quem tem uma sessão válida daquela conta — o navegador esquecido
aberto, a máquina compartilhada, o cookie capturado — abre `GET /set-password`, que renderiza
para qualquer sessão, pega o `_csrf_token` do formulário e faz o POST. A senha nova passa a
valer **sem que a antiga tenha sido apresentada em momento nenhum**, e o giro do
`session_token` derruba as outras sessões: a pessoa legítima perde o acesso na ação seguinte.

**A prova.** Um teste temporário, rodado e depois removido, com a guarda de que o cenário foi
de fato estabelecido (`refute alvo.must_change_password` — sem isso o teste mediria o fluxo da
temporária, que é legítimo):

- `POST /set-password` numa conta em regime normal → redireciona para `/people` (se recusasse,
  seria `/sign-in`), a senha nova autentica, e a antiga passa a devolver
  `{:error, :invalid_credentials}`;
- e a **outra porta está certa**: `POST /profile/password` com a senha atual errada não muda
  nada. É a comparação que transforma isto de "falta um controle" em "o controle existe e há
  uma segunda porta sem ele" — o antipadrão da §6.1 daquele outro documento, dentro de casa.

**Consequência para o negócio.** Quem alcança a sessão de alguém por alguns minutos converte
esse acesso temporário em **posse permanente da conta**, e expulsa a pessoa legítima. Quem
administra não tem ato que responda: o único caminho é reiniciar a senha — e isso é o mesmo
ato que o desligamento usa, o que confunde os dois no histórico. E, por H3, não existe
desativar conta.

**O conserto mínimo.** Uma cláusula na cadeia do `with`, em
`session_controller.ex:84-86`: exigir `user.must_change_password`. A conta que não está no
fluxo da temporária cai no `else` **que já existe** — `configure_session(drop: true)` e
`/sign-in`.

**O que NÃO muda**, e isto foi verificado nos chamadores: a guarda vai no **controller**, e
não em `Auth.set_password/3`. Aquela função é operação de domínio, usada por
`priv/repo/seeds.exs:51` e pelas fixtures da suíte para dar a primeira senha a uma conta nova,
onde `must_change_password` é falso por construção. Mudá-la quebraria os dois sem ganho.
`TheBand.Tenants.Bootstrap` não passa por ela — usa `User.senha_changeset` direto
(`bootstrap.ex:119`) —, e portanto a primeira conta do ambiente não é afetada. `/profile/password`
não muda. O fluxo da temporária (FR-013) não muda.

**Refinamento que é decisão de produto, não minha**: se a recusa deve derrubar a sessão ou
mandar a pessoa para `/profile` com uma frase (*"a troca de senha vive no perfil"*). O seguro
é o primeiro; o gentil é o segundo. Product Owner e Design decidem.

**Migração de esquema**: **não**. **Sem release**: não — é código.

**Cenário para o QA** (o teste que falta, e a asserção que importa):
> **Dado** uma conta com senha definida e `must_change_password` falso — e o teste MUST
> asserir esse falso, senão mede o fluxo legítimo;
> **Quando** essa sessão faz `POST /set-password` com uma senha nova válida;
> **Então** a resposta é a recusa (sessão derrubada, destino `/sign-in`);
> **E** `refute` que a senha nova autentica;
> **E** `assert` que a senha original continua autenticando;
> **E** o teste-par: com `must_change_password` verdadeiro, o POST **funciona** — senão o
> conserto teria fechado a porta legítima e ninguém saberia.

---

### H2 — o veredito de acesso vale em 2 dos 26 LiveViews autenticados

**Severidade: Alta** · OWASP A01 · ASVS V4.1 (*controle de acesso*), V4.1.3 (*menor
privilégio*) · **MEDIDO com teste**

**Onde.** `TheBand.Tenants.Access.pode_ver/3` é consultado por **dois** LiveViews, e o `grep`
é o achado inteiro:

```
lib/the_band_web/live/people_live/show.ex        (pode_ver/3, linha 280)
lib/the_band_web/live/teams_live/show.ex         (pode_ver_equipe/3)
```

Os outros 24 filtram **só por tenant**. E dentro da própria
`people_live/show.ex`, o veredito gateia parte da página e não o resto:

| O que | Linha | Gateado por `ve_o_trabalho?` |
|---|---|:---:|
| seção `Reading at a glance` | 545 | sim |
| seção `#work` (vazão, lead time, antipadrões, issues) | 643 | sim |
| **seção `#profile` — o perfil escrito por modelo de linguagem** | **1183** | **não** |
| **seção `#provenance` — inclui `mudancas`, os PRs e commits da pessoa** | **1492** | **não** |
| `paradas`, `participacao`, `mudancas` (as consultas) | 315, 316, 319 | não |
| seção `#teams`, papéis declarados, `#account` | 1768, 1825, 1878 | não |

E duas rotas inteiras sobre pessoa nomeada não consultam veredito nenhum:

- `lib/the_band_web/live/change_live/commits.ex:20-34` — `/people/:id/commits`, os commits de
  uma pessoa nomeada. Busca a pessoa com `EO.fetch_person(tenant, id)` e segue;
- `lib/the_band_web/live/verification_live/people.ex:72-83` — `/work/verifications/people`,
  cujo próprio título é **"Who merged red"**: `red_by_person/1` e `red_by_integrator/1`
  agrupam por pessoa e devolvem `login` no `select` (`lib/the_band/verification.ex:653-654`).
  É um **ranking nominal de quem integrou com a verificação vermelha**, aberto a qualquer
  conta autenticada do tenant.

**O caminho concreto, medido.** Uma conta `member` sem elo declarado e sem concessão nenhuma —
o veredito devolve `{:nao, :conta_sem_pessoa_declarada}`, e o teste **assere essa recusa antes
de qualquer outra coisa**, senão não mediria nada. Com ela:

- `GET /people/:id` → a aba de trabalho fecha (`refute html =~ "Reading at a glance"`) — **a
  defesa que existe funciona**;
- e a mesma resposta traz `"Where this came from"`, `"Profile & growth"` e o nome da pessoa;
- `GET /people/:id/commits` → abre, com a identidade da pessoa no cabeçalho e na migalha;
- `GET /work/verifications/people` → abre.

**Por que isto é lacuna e não decisão.** A FR-012 da spec 023 fala em *"a visibilidade da
**aba**"*, e a aba é o que foi fechado. O regime que ela substituiu — *"toda pessoa
autenticada do tenant vê qualquer outra"* — está descrito na própria spec como algo que
*"vigorava **por omissão**: o roteador exigia `require_user` e nada além"*
(`specs/023-painel-da-pessoa/spec.md:209-216`). As seções construídas depois herdaram a
omissão. E o comentário de `show.ex:636-640` diz que a ordem da página é *"primeiro o que se lê
para decidir (trabalho, **perfil**)"* — o perfil está declarado como material de decisão, e é
o que fica aberto.

O texto da recusa que a tela mostra hoje é o argumento mais forte de que a assimetria não foi
escolhida (`show.ex:611-620`): *"A panel is reachable by the person themselves, by a team or
project scope that includes them… being an administrator manages the platform, it does not
open panels."* A tela afirma um regime que ela aplica a uma seção e a dois módulos de
vinte e seis.

**Consequência para o negócio.** Qualquer conta da organização lê, de qualquer pessoa: o texto
que o modelo escreveu sobre o trabalho dela, os PRs e commits dela, o trabalho parado dela com
a discussão, e a posição dela num ranking de quem integrou com o CI vermelho. É a leitura mais
individualmente atributiva do produto, e é justamente a que a FR-012 existe para não deixar
aberta. Numa plataforma que mede pessoas, isto é o risco que gera conversa com quem é medido.

**O conserto mínimo — e ele começa por uma decisão, não por código.** Não existe conserto
cego aqui: aplicar `pode_ver/3` nas 22 rotas mudaria o produto, e afrouxar as 2 mudaria o
produto na direção oposta. **O que fecha, na ordem:**

1. **decisão registrada da pessoa mantenedora**: o regime da FR-012 vale para *todo* dado
   nominal de pessoa, ou vale só para as medidas de desempenho da aba? A resposta é uma FR
   nova numerada, não uma linha de conversa;
2. **o inventário como parte da decisão** — a tabela acima e as duas rotas, para que ela seja
   tomada sobre o que existe e não sobre a ideia geral;
3. **um teste de paridade**: para cada rota que sirva dado nominal de pessoa, a conta recusada
   por `pode_ver/3` recebe a mesma recusa. É o teste que impede a próxima seção de herdar a
   omissão — e sem ele o conserto de hoje é desfeito pela tela de amanhã.

**Enquanto a decisão não vem**, as três com o caminho mais curto e o dano mais direto são
`/work/verifications/people`, `/people/:id/commits` e a seção `#profile` — as duas primeiras
porque são rotas inteiras sem veredito, a terceira porque o perfil derivado é o texto mais
sensível que a plataforma produz sobre uma pessoa.

**Migração de esquema**: **não**. **Sem release**: não — é código, e antes disso é decisão.

**Cenário para o QA:**
> **Dado** dois tenants povoados e, no primeiro, uma conta `member` sem elo e sem concessão,
> mais uma pessoa observada com commits, perfil gerado e uma integração vermelha;
> **E** `assert {:nao, _} = Tenants.pode_ver(tenant, conta, pessoa.id)` — a guarda, primeiro;
> **Quando** essa conta abre `/people/:id`, `/people/:id/commits` e
> `/work/verifications/people`;
> **Então** `refute` que o nome, o login ou o texto do perfil da pessoa apareçam em qualquer
> uma das três;
> **E** `assert length(...) > 0` sobre o que a conta COM alcance vê nas mesmas três — senão a
> suíte celebraria três telas quebradas.

---

### H3 — não existe revogação de acesso que funcione: nem por conta, nem por organização

**Severidade: Alta** (era Média em `api-com-token.md` §11.5) · OWASP A01 e A07 · ASVS V3.3
(*terminação de sessão*), V4.1 · **MEDIDO com teste**

Subiu de Média para Alta por três razões, e as três são de hoje: a plataforma está em produção
com dado real; medir mostrou que a lacuna tem **três** partes e não uma; e a combinação com H2
transforma "o painel dela fecha" em "ela continua lendo a organização inteira".

**Onde, e as três partes.**

1. **`users` não tem estado de conta desativada.**
   `priv/repo/migrations/20260809120000_create_tenants_and_users.exs:26-31` — a tabela tem
   `email`, `name`, `role`, `tenant_id`. `tenants` tem `status` (linha 18); `users` não tem
   nada equivalente. `lib/the_band_web/live/accounts_live/index.ex` oferece `criar`, `reset`,
   `abrir_busca`, `buscar_pessoa`, `associar` e `revogar_elo` — **não há desativar nem
   remover**;

2. **`tenants.status` existe e não é lido em lugar nenhum.**
   `lib/the_band/tenants/tenant.ex:22` declara o campo com `default: "active"`, e a linha 31 o
   deixa castável. O `grep` por leitura desse campo em `lib/` volta vazio: nem `authenticate/2`,
   nem `Tenants.fetch_user/1`, nem `CurrentScope`, nem as hooks o consultam. **Medido**: marcar
   um tenant como `"suspended"` e, em seguida, autenticar e abrir `/people` — as duas coisas
   funcionam, com a asserção `assert suspenso.status == "suspended"` antes, para que o teste
   não passasse por não ter suspendido nada. É uma coluna que **parece** um controle e não é
   um;

3. **revogar o elo — o ato que a tela oferece a quem desliga alguém — não remove acesso.**
   **Medido**: com o elo revogado, `pode_ver/3` passa a recusar o painel da própria pessoa, e
   ao mesmo tempo `Tenants.authenticate/2` continua devolvendo `{:ok, user}` (o login por
   e-mail não exige elo — só o login por identificador do GitHub exige, em
   `auth.ex:132-148`), e `/people`, `/teams` e `/work/verifications/people` continuam abrindo
   com o conteúdo do tenant.

**O caminho concreto.** Uma pessoa sai da organização. Quem administra faz o que a tela
oferece: revoga o elo. A pessoa continua entrando com a senha que sabe e continua lendo tudo o
que H2 deixa aberto — a lista de pessoas, as equipes, o trabalho, os perfis derivados, o
ranking de quem integrou vermelho. O único ato que **de fato** corta o acesso é reiniciar a
senha e não entregar a temporária — o que funciona (`gravar_temporaria` gira o
`session_token`), mas é implícito: não está escrito em lugar nenhum, é indistinguível de um
reinício legítimo no histórico, e depende de quem administra saber que é isso que se faz.

**Consequência para o negócio.** A organização não tem como desligar alguém da plataforma. O
gesto que parece desligar — revogar o elo — não desliga, e o que desliga não parece desligar.
E enquanto a 061 não existir isso é mitigado por acidente: sem token, quem não sabe a senha
não entra. É acidente, não controle, e o documento da API mostra exatamente o dia em que ele
para de valer.

**O conserto mínimo, em duas partes com custos muito diferentes.**

**Parte A — `tenants.status`, sem migração.** A coluna existe e tem `default: "active"`. Falta
**ler**: `authenticate/2` recusa com a mensagem única quando o tenant não está `active` (a
recusa MUST ser byte-idêntica às outras — `auth.ex:21` é o ponto único, e um motivo novo ali
seria enumeração), e `CurrentScope`/`hooks` derrubam a sessão como já derrubam por token
divergente. Se a intenção nunca foi ter suspensão de organização, **o conserto é remover a
coluna** — o que também é honesto, e é o que o princípio VIII diria de uma estrutura que o
problema não justifica. As duas saídas são melhores que a de hoje, que é uma coluna que mente.

**Parte B — `users.disabled_at`, com migração.** Coluna nova em marca (`disabled_at`,
`disabled_by_user_id`), nunca `delete` — a forma de `ScopeGrant`, para que o histórico de
acesso continue sendo dado de auditoria (SC-005 da 045). Mais o ato em `/accounts` e a regra
de que conta desativada **não autentica**, com a mesma mensagem única.

**O que NÃO muda**: `revogar_elo` continua existindo e continua significando o que significa —
*"não sabemos mais qual pessoa observada é esta conta"*. Desativar é outra coisa, e juntar as
duas seria o erro que a FR-012f já separou.

**Migração de esquema: a Parte B exige, e o risco vai declarado.** A v0.6.0 subiu com
`20260908010000_saida_declarada_com_autor.exs`, que altera dados, e o registro dela
(`docs/releases/v0.6.0.md:573-584`) escreve o risco com estas palavras: *"o caminho de volta é
um backup que nunca foi restaurado"*. O ensaio de restauração do §6 do runbook continua
**adiado** — a conta S3 não existe. Então:

- a Parte B é **só-acréscimo de colunas nulas**, que é a migração de menor risco possível: não
  faz backfill, não cria CHECK, e a versão anterior sobe sobre o esquema novo (runbook §5);
- e ainda assim ela deve repetir o que a v0.6.0 fez de certo — o **ensaio contra uma cópia
  restaurada do banco real**, no formato de
  [`docs/producao/ensaio-2026-09-08-migracao-060.md`](../producao/ensaio-2026-09-08-migracao-060.md);
- **o que o ensaio não responde**, e a v0.6.0 já registrou: ele diz *"a migração roda sobre
  dado real?"*, e não *"o backup existe de verdade?"*. O segundo continua aberto desde a
  v0.1.0.

**Sem release**: a Parte A é código (release). A Parte B é código e migração (release).
**Nenhuma das duas se resolve por configuração** — e é isso que a torna a mais caras da lista.

**Cenário para o QA:**
> **(a)** **Dado** um tenant com `status: "suspended"` e uma conta com senha válida;
> **Quando** essa conta tenta entrar; **Então** `{:error, :invalid_credentials}`, e a mensagem
> é **byte-idêntica** à de senha errada (o `Enum.uniq` que `login_test.exs` já usa);
> **E** `assert` que o tenant estava mesmo suspenso — senão o teste não mediu nada.
>
> **(b)** **Dado** uma conta desativada com sessão aberta; **Quando** ela faz a ação seguinte;
> **Então** cai em `/sign-in`; **E** `refute` que a linha de `users` foi apagada — `disabled_at`
> e `disabled_by_user_id` preenchidos, porque histórico de acesso é auditoria.
>
> **(c)** **Dado** dois tenants povoados, um suspenso e outro não; **Então** `assert length(...) > 0`
> no ativo — sem isso, "o suspenso não vê nada" passaria com a consulta quebrada nos dois.

---

### H4 — nenhum evento de autenticação ou de autorização é registrado

**Severidade: Média** · OWASP A09 · ASVS V7.2 (*registro de eventos de segurança*)

**Onde.** O `grep` por `Logger` nos oito arquivos que decidem acesso volta **vazio**:
`lib/the_band/tenants/auth.ex`, `lib/the_band_web/controllers/session_controller.ex`,
`lib/the_band/tenants/access.ex`, `lib/the_band_web/plugs/current_scope.ex`,
`lib/the_band_web/live/hooks.ex`, `lib/the_band/tenants/access/scope_grant.ex`,
`lib/the_band_web/live/accounts_live/index.ex`,
`lib/the_band_web/live/access_scopes_live/index.ex`.

E o metadado do log é `metadata: [:request_id]` (`config/config.exs:70`). `Logger.metadata` não
é chamado em lugar nenhum de `lib/`, e `correlation_id` **não existe** no código — a lista de
campos de `AGENTS.md` §15 (`tenant_id`, `correlation_id`, `source_system`, `external_id`,
`job_id`, `attempt`, `status`, `error_code`, `error_reason`) não está implementada para
nenhum evento.

Não registrado hoje: entrada aceita, entrada recusada, desaceleração acionada
(`{:throttled, s}` — o valor existe no retorno e morre ali), recusa de acesso a painel,
concessão de escopo criada ou revogada, elo declarado ou revogado, troca de senha, queda de
sessão por token divergente.

**O ponto que dá a severidade, e ele é específico desta implementação.**
`auth.ex:100-112` — `registrar_sucesso/1` grava `failed_attempts: 0` e `last_failed_at: nil`.
Esses dois campos são o **único** rastro que existe de tentativa falha, e eles são um contador
de estado, não um histórico. **Uma campanha de adivinhação de senha que dá certo apaga a
própria evidência**: as tentativas falhas somem no instante do sucesso, e não sobra nada que
diga que houve campanha.

**O caminho concreto.** Não é um ataque — é a impossibilidade de responder à pergunta depois.
Amanhã alguém pergunta *"esta conta foi acessada por outra pessoa?"*, *"houve tentativa em
série contra este tenant?"*, *"quem concedeu a esta conta o escopo que ela usou?"*. Para a
terceira há resposta parcial: `ScopeGrant` guarda `granted_by_user_id`, `revoked_by_user_id` e
as datas — mas isso é o **estado** da concessão, não o evento, e não diz quantas vezes ela foi
usada. Para as duas primeiras não há resposta. O log de requisição do Phoenix
(`Plug.Telemetry` no endpoint, `level: :info` em `config/prod.exs:23`) registra método,
caminho e status, sem conta e sem tenant.

**Consequência para o negócio.** Com dado real em produção, a plataforma não tem como
reconstruir um incidente de acesso. E isso vale contra H1, H2 e H3: se qualquer um dos três
tiver sido explorado desde que a v0.6.0 subiu, **não há como saber**.

**O conserto mínimo, e a forma importa.** A lição **L69** desta base diz que defeito dentro de
`Logger.info` é invisível a teste, porque o nível é configuração. Então:

- os eventos vão para o log **com** os campos de §15, via `Logger.metadata` no plug e nas
  hooks (`tenant_id`, `user_id`, `request_id`);
- e a **decisão continua no retorno**: `authenticate/2` já devolve `{:error, {:throttled, s}}`
  distinto de `{:error, :invalid_credentials}` (é o que permite testar a espera crescente sem
  ler log), e `pode_ver/3` já devolve `{:nao, motivo}`. Onde o relator já existe, o log é
  registro; onde não existir, ele nasce junto — senão o teste não terá onde asserir;
- **e segredo nunca vai para o log**: nem senha, nem `session_token`, nem a temporária. O
  evento de entrada registra `user_id` e resultado, não credencial. Os cinco campos sensíveis
  já são `redact: true` (verificado — §3 abaixo), e isso protege o `inspect/1`, não uma
  interpolação escrita à mão.

**Sobre o rastro de tentativa falha**: preservá-lo não pede tabela nova se o evento for
logado. Uma tabela de eventos de acesso seria a solução completa e é decisão de desenho, com
migração — fora do conserto mínimo.

**Migração de esquema**: **não**, para o conserto mínimo.
**Sem release**: não — é código. (O `level: :info` de `config/prod.exs` já publica `Logger.info`;
o que falta é a chamada, e configuração não é controle.)

**Cenário para o QA:**
> **Dado** uma conta e quatro tentativas de entrada com senha errada;
> **Então** a quarta devolve `{:error, {:throttled, s}}` com `s > 0` — asserção sobre o
> **retorno**, não sobre o log;
> **E** `capture_log/1` sobre as quatro contém quatro registros de recusa com `user_id` e
> `tenant_id`;
> **E** `refute` que qualquer um deles contenha a senha tentada ou o `session_token`.

---

### H5 — sessão encerrada continua servindo dentro do LiveView já conectado

**Severidade: Média** · OWASP A07 · ASVS V3.3.1 (*terminação de sessão surte efeito*)

**Onde.** `lib/the_band_web/live/hooks.ex:20-45` — `on_mount(:current_scope, ...)` confere o
`session_token`, a validade e o gate de senha. `on_mount` roda **uma vez por mount**;
`handle_event/3` e `handle_info/2` não o repetem. E o `grep` por revalidação periódica em
`lib/the_band_web/` (`send_interval`, `Process.send_after`) volta **vazio**.

**O caminho concreto.** Uma aba aberta em `/people` continua respondendo a eventos — busca,
paginação, troca de aba, abrir o painel de alguém — depois de a senha ter sido trocada em
outro navegador, depois de o elo ter sido revogado, e depois de a janela de sete dias ter
vencido. A queda acontece na **próxima montagem**: recarregar a página, navegar por
`push_navigate`, ou a reconexão do socket depois de uma queda de rede. Uma aba parada e
reconectada por WebSocket pode atravessar horas.

Isto é a metade que falta do FR-015. `test/the_band_web/live/login_test.exs:109-123` prova que
a outra sessão cai *"na PRÓXIMA ação"* — e a próxima ação, no teste, é um `live/2` novo, que é
um mount. O teste está certo sobre o que mede; ele não mede a aba já conectada.

**Consequência para o negócio.** Trocar a senha porque se desconfia de acesso indevido não
expulsa quem está com a aba aberta. É exatamente a situação em que a pessoa acha que resolveu.

**O conserto mínimo.** Uma revalidação periódica na hook: `Process.send_after` no mount e um
`attach_hook(:handle_info)` que reconfere `session_token` e validade, derrubando com o mesmo
`redirect(to: "/sign-in")` que a hook já usa. O intervalo é limiar, e portanto **vive na base
de conhecimento** (FR-069), não numa constante de módulo — mesma regra que a 060 aplicou.

Alternativa mais precisa e mais caras: `Phoenix.PubSub` no giro do token, com os LiveViews da
conta inscritos. Fecha a janela para zero em vez de para o intervalo. É desenho, e o princípio
VIII pede que quem o proponha diga o que ele piora — aqui, um tópico por conta e uma segunda
verdade sobre "quem está conectado".

**O que NÃO muda**: `on_mount` continua sendo a porta; a revalidação é adicional, não
substituta.

**Migração de esquema**: **não**. **Sem release**: não — é código.

**Cenário para o QA:**
> **Dado** um LiveView conectado com sessão válida;
> **Quando** a senha da conta é trocada por outro caminho, **e o processo não é remontado**;
> **Então** o evento seguinte disparado nesse mesmo `view` recebe a recusa;
> **E** o teste MUST usar o `view` já conectado — um `live/2` novo remontaria e mediria o que
> `login_test.exs` já mede.

---

### H6 — `pode_ver_equipe/3` concede visão por `users.role`, contra o cabeçalho do próprio módulo

**Severidade: Média** · OWASP A01 · ASVS V4.1.3 (*menor privilégio*)

**Onde.** `lib/the_band/tenants/access.ex:20-24` afirma:

> *"**Administrar não é ver (FR-022).** Nenhum ramo aqui olha `users.role` para conceder
> visão."*

E `access.ex:273`, dentro de `pode_ver_equipe/3`, é
`User.admin?(user) and user.tenant_id == tenant.id -> {:ok, :admin}`.

Ver as medidas de uma equipe — incluindo a quebra por pessoa nomeada, que é o que a FR-024
fechou — **é visão**. Os outros dois ramos com `User.admin?` foram verificados e são
legítimos: `access.ex:187` está em `pode_gerir_estrutura/3` (escrita) e `access.ex:452` em
`operacional?/2` (operação). O da linha 273 é o único que decide **visão**.

A doc da própria função lista o ramo abertamente (`access.ex:262-268`), o que indica decisão
consciente — mas ela contradiz o cabeçalho, e não há registro de que a FR-022 tenha sido
revista para equipes. **E a spec 023 agrava**:
`specs/023-painel-da-pessoa/spec.md:271` ainda diz *"**FR-012j**: Quem tem `admin` de
plataforma MUST ver todos os painéis do tenant"*, sem marca de que a 045 FR-022 a revogou —
enquanto a tela, em `people_live/show.ex:619`, já diz a quem foi recusado que *"being an
administrator manages the platform, it does not open panels"*.

**Consequência para o negócio.** Três documentos afirmam três coisas sobre a mesma pergunta, e
a próxima pessoa a escrever código de acesso vai implementar a que ler primeiro. Não há
exploração hoje: quem é `admin` já pode conceder-se qualquer escopo. O risco é de **desenho**,
e ele é o mais caro desta lista no médio prazo — porque a spec da API vai congelar a resposta
que alguém escolher sem saber que havia escolha.

**O conserto mínimo — três registros, nenhuma implementação.**

1. decisão da pessoa mantenedora: *administrar concede visão de equipe, sim ou não?*;
2. correção do **cabeçalho** de `access.ex` (se a resposta for sim, o cabeçalho está errado) ou
   do **ramo** da linha 273 (se for não);
3. marca de revogação em `specs/023-painel-da-pessoa/spec.md:271` apontando para 045 FR-022 —
   `lib/the_band/ontology/seon/eo/visibility.ex` documenta a revogação; a spec, não.

**Migração de esquema**: **não**. **Sem release**: o item 3 é documentação e entra sozinho;
os itens 1 e 2 dependem da decisão.

---

### H7 — o Dokploy implanta `latest`, e `latest` não identifica o que está rodando

**Severidade: Média** · OWASP A08 · ASVS V14.2 (*integridade do artefato*)

**Onde.** `.github/workflows/cd.yml:65-71` publica as duas tags — `vX.Y.Z` e `latest` — e a
linha 90 diz o que acontece depois: *"o webhook aceito — o Dokploy puxa `$IMAGEM:latest` e
reimplanta"*.

**O caminho concreto.** Três consequências, e nenhuma delas é ataque:

- **depois de um incidente, "qual imagem estava rodando?" não tem resposta no registro.**
  `latest` é um apontador móvel; o que ele apontava ontem não é recuperável de lá;
- **dois releases próximos correm entre si**: o webhook do primeiro pode chegar ao Dokploy
  depois de o segundo já ter movido `latest`, e o que sobe é o segundo com o registro do
  primeiro;
- **o rollback do runbook §5** manda reapontar o app para `ghcr.io/...:vX.Y.(Z-1)` — o que é
  certo, e é justamente o que mostra que o caminho normal deveria fazer o mesmo. Hoje o
  rollback é mais preciso que o deploy.

**Consequência para o negócio.** A cadeia entre commit e artefato — o que torna um deploy
auditável — tem um elo móvel exatamente no ponto em que a produção o consome. E a v0.6.0 subiu
com migração que altera dados: saber com precisão qual imagem rodou quando é o insumo de
qualquer investigação sobre aquele dia.

**O conserto mínimo.** O Dokploy passa a puxar `ghcr.io/the-band-solution/theband:vX.Y.Z`, e o
passo de delivery do `cd.yml` informa a versão ao Dokploy em vez de contar com o apontador.
`latest` continua sendo publicado — ele é útil como conveniência —, só deixa de ser o que a
produção consome.

**O que NÃO muda**: a idempotência por versão do `cd.yml:41-52`, que está correta e é o que
impede reusar versão.

**Migração de esquema**: **não**.
**Sem release: SIM** — é configuração do Dokploy mais o workflow. **Nenhuma linha de código da
aplicação.** É o item de melhor relação entre custo e ganho desta lista.

---

### H8 — as ações de terceiros do CI/CD estão fixadas por tag mutável

**Severidade: Média** para o `cd.yml`, **Baixa** para o `ci.yml` · OWASP A08 · ASVS V10.3
(*integridade de dependências*), V14.2

**Onde.**

- `.github/workflows/cd.yml:19-21` declara `contents: write` e `packages: write`, e o job usa
  `actions/checkout@v5` (linha 31) e `docker/login-action@v4` (linha 56) — **tags móveis** —,
  no mesmo job em que vivem `secrets.GITHUB_TOKEN` e `secrets.DOKPLOY_WEBHOOK_URL`;
- `.github/workflows/ci.yml` **não declara `permissions:`** — e portanto usa o padrão do
  repositório, que não está declarado em lugar nenhum. Ele roda em `push` e em
  `pull_request`, e usa `actions/checkout@v5`, `erlef/setup-beam@v1`, `actions/cache@v5`,
  `actions/upload-artifact@v6` e `dorny/paths-filter@v4`.

Verificado, e vale dizer porque é o que costuma faltar: **não há `pull_request_target` em
nenhum dos três workflows**, e `on: pull_request` não expõe segredos a fork. O
`.github/workflows/docs.yml` declara `permissions: contents: write`, com o motivo escrito.

**O caminho concreto.** `docker/login-action@v4` é uma tag, não um commit: quem controla o
repositório da ação pode movê-la. Movida para código hostil, ela roda no job do `cd.yml` com
`packages: write` e com o webhook de produção no ambiente — publicaria imagem arbitrária sob o
namespace deste repositório, que é o namespace do qual a produção puxa (H7 agrava: `latest`).
É a cadeia de suprimentos do deploy, e é o único lugar desta base onde um terceiro executa
código com credencial de publicação.

**Consequência para o negócio.** O caminho entre "alguém aprovou um merge" e "isto está em
produção" passa por três repositórios de terceiros identificados por um rótulo que eles podem
reescrever.

**O conserto mínimo.** Fixar por SHA de commit as ações do `cd.yml`, com o comentário da
versão ao lado (`uses: docker/login-action@<sha> # v4.x`), e declarar
`permissions:` explícito no `ci.yml` — o mínimo que ele precisa é `contents: read`.

**O que NÃO muda**: as ações continuam as mesmas; muda a forma de nomeá-las. E `cd.yml` já
está certo no que mais importa — `permissions` declarado com o motivo por linha.

**Migração de esquema**: **não**.
**Sem release: SIM** — workflow apenas.

---

### H9 — `ssl: true` do Repo comentado: a severidade depende da topologia, que eu não verifiquei

**Severidade: a determinar — Alta se a base roda em outro host; Baixa se roda na mesma rede
privada de contêiner** · OWASP A02 · ASVS V9.2.1 (*TLS nas conexões internas*)

**Onde.** `config/runtime.exs:86` — `# ssl: true,` comentado dentro do bloco
`config_env() == :prod`.

**O caminho concreto.** Se a base e a aplicação estiverem em hosts diferentes, o tráfego
atravessa a rede em claro — e isso inclui os valores **cifrados** (que atravessam cifrados, e
portanto continuam protegidos), mas também os hashes de senha, os `session_token`, e todo dado
de tenant, que atravessam como estão. Quem estiver no caminho lê.

**Não afirmo qual dos dois é o caso.** A topologia de produção (VPS Contabo + Dokploy) não é
legível daqui, e a `DATABASE_URL` é segredo do ambiente — que eu não peço, não leio e não
aceito em conversa. O runbook §4.1 diz que *"a URL interna gerada é o `DATABASE_URL` do app"*,
o que **sugere** rede interna do Dokploy no mesmo host, mas sugerir não é verificar.

**A pergunta para quem opera**: *a base roda no mesmo host da aplicação, pela rede interna do
Dokploy?*

**O conserto, e ele tem uma resposta útil sobre "sem release".** Verificado na fonte:
`Ecto.Repo.Supervisor.parse_uri_query/1`
(`deps/ecto/lib/ecto/repo/supervisor.ex:154-158`) trata explicitamente `ssl=true` na query
string da URL. Então **`?ssl=true` no `DATABASE_URL` do Dokploy liga TLS sem release nenhum.**

**Com um porém que muda a recomendação, e ele também foi verificado na fonte:**
`deps/postgrex/lib/postgrex/protocol.ex:98-100` e `:167-169` — `ssl: true` no postgrex
significa `cacerts: :public_key.cacerts_get()` com `verify: :verify_peer`. Um Postgres interno
do Dokploy com certificado autoassinado **falharia ao conectar**, e a aplicação não subiria.
Portanto:

| Situação | O que fazer | Release? |
|---|---|:---:|
| base em outro host, com certificado de CA pública | `?ssl=true` no `DATABASE_URL` | **não** |
| base em outro host, certificado autoassinado | a CA vai para a imagem e `ssl: [cacertfile: ...]` | sim |
| base na rede interna do mesmo host | registrar a topologia e a decisão; o item fecha como aceito | não |

**O que NÃO se faz**: `ssl: [verify: :verify_none]` como atalho. Isso é cifrar sem autenticar
a ponta, o que não é o controle que o item pede — e se for a escolha, precisa ir para o
registro como tal, com essas palavras.

---

### H10 — o cookie de sessão é assinado e não cifrado: `user_id` e `session_token` viajam legíveis

**Severidade: Baixa** · OWASP A02 · ASVS V3.4 (*atributos e proteção do cookie*)

**Onde.** `lib/the_band_web/endpoint.ex:7-12` — `@session_options` traz `store: :cookie`,
`key`, `signing_salt` e `same_site: "Lax"`. **Não traz `encryption_salt`**, e o comentário das
linhas 4-6 diz exatamente o que isso significa: *"its contents can be read but not tampered
with. Set `:encryption_salt` if you would also like to encrypt it."*

A sessão carrega `user_id`, `session_token` e `redirect_to`. O `session_token` é
`redact: true` no schema (`user.ex:51`) **justamente porque é sensível** — e viaja em claro
dentro do cookie. É a inconsistência que faz o achado: a base decidiu que aquele valor não
aparece em `inspect/1`, e ele aparece em qualquer lugar onde o cookie apareça — um print de
devtools, um log de proxy mal configurado, um relatório de erro de navegador.

**O que NÃO é achado, e vale dizer para não parecer omissão.**

- **o `signing_salt` literal do `endpoint.ex:10` não é segredo vazado.** A chave de assinatura
  deriva de `secret_key_base` + salt, e o salt não precisa ser secreto. Forjar cookie exige o
  `secret_key_base`, que é obrigatório e vem do ambiente (`runtime.exs:98-103`);
- **o atributo `Secure` está presente**, e agora foi verificado ponta a ponta em vez de
  concluído: `Plug.SSL` é o **primeiro** plug do endpoint, inserido antes dos plugs do módulo
  (`deps/phoenix/lib/phoenix/endpoint.ex:485-486`); `rewrite_on: [:x_forwarded_proto]`
  (`config/prod.exs:15`) reescreve `conn.scheme` para `:https`
  (`deps/plug/lib/plug/rewrite_on.ex:48-50`); e `put_resp_cookie/4` põe `secure: true` quando
  o scheme é `:https` (`deps/plug/lib/plug/conn.ex:1722`). `http_only` é `true` por padrão, e
  `same_site` é `"Lax"`. **A garantia depende de o proxy reverso mandar
  `x-forwarded-proto: https`** — o que é o normal do Dokploy, e é a mesma pergunta de
  topologia de H9;
- e é por isso que o `GHSA-375f-4r2h-f99j` do Bandit foi conferido: ele quebraria exatamente
  esta cadeia. Corrigido em 1.11.0, e esta base está em 1.12.5.

**O conserto mínimo.** `encryption_salt` em `@session_options`.

**O custo, que é o motivo de ser Baixa e não Média:** todas as sessões vigentes caem no
deploy, porque o cookie antigo deixa de ser decifrável. É aceitável e declarável — mas é uma
decisão de quando, não de se, e cabe ao Product Owner escolher a release.

**Migração de esquema**: **não**. **Sem release**: não — é código.

---

### H11 — a exceção de aviso do `mix.exs` ficou obsoleta, e o sinal disparou

**Severidade: Baixa** · OWASP A06 · ASVS V10.3

**Onde.** `mix.exs:38` — `hex: [ignore_advisories: ["CVE-2026-32686"]]`. E `mix hex.audit`,
saída 0, imprimiu junto:

```
ignore_advisories entry "CVE-2026-32686" (set in mix.exs) does not match any
advisory for the locked dependencies and can be removed
```

**Por que remover não enfraquece nada.** As linhas 21-37 do `mix.exs` documentam a exceção com
cuidado exemplar e escrevem o critério da própria remoção: *"`mix hex.audit` continua
imprimindo o achado sob `Ignored advisories:` e denuncia a entrada quando ela ficar obsoleta —
que é o sinal para remover esta exceção"*. **O sinal disparou.** O próprio auditor diz que não
há aviso correspondente, e remover a linha o devolve ao estado em que nada é ignorado.

Enquanto ela fica, é uma **supressão dormente**: qualquer aviso futuro com aquele identificador
é silenciado sem que ninguém decida.

**O que NÃO muda**: a proteção real nunca foi essa linha — é
`test/the_band/decimal_limitado_test.exs`, que reprova se a faixa do `Decimal` deixar de ser a
corrigida. Ele fica.

**Migração de esquema**: **não**. **Sem release**: não — mas é uma linha, e vai junto de
qualquer outra coisa.

---

### H12 — `deps` está commitada como link simbólico absoluto para si mesma

**Severidade: Média** — medida, e mais alta do que eu havia estimado · OWASP A08 · ASVS V14.2

**Onde.** Entrada de índice `120000 1d6c2a6090a0abfcbda658014d214a9e8102887a 0 deps`,
introduzida em `4626ec3` (2026-09-08). O conteúdo do blob é
`/Users/paulossjunior/projects/theband/deps` — o caminho absoluto do próprio link.

**Verificado hoje, e a diferença importa**: `git cat-file -p main:deps` responde que **não
existe em `main`**, e existe em `origin/development`. **Não está em produção.** Chega a `main`
no próximo release.

**A consequência foi medida durante esta avaliação, e é pior que a estimativa.** Enquanto eu
rodava a segunda passagem de `mix gates`, uma troca de branch entre uma branch que **tem** a
entrada `deps` e uma que **não tem** fez o git tratar o caminho como o link que ele registrou:
**a árvore de dependências foi apagada — `ls deps` passou a devolver zero pacotes** — e o
`mix gates` reprovou no meio, com `código de saída 1` e *"the dependency is not available"*
para as 56 dependências. **O repositório ficou não-construível por uma troca de branch.**

Isso muda a classificação: não é apenas *"a build deixa de ser reproduzível quando chegar a
`main`"*. É **perda de estado de trabalho a cada `git checkout`** entre branches que divirjam
nesse caminho — e é o tipo de dano que se atribui ao ambiente em vez de à causa, porque a
mensagem que aparece manda rodar `mix deps.get` e não diz por quê.

**O caminho concreto.** Um `git clone` recria o link; na máquina de origem ele aponta para si e
`mix deps.get` aborta. No CI (Linux, outro caminho) o passo de cache do `ci.yml:52-59` usa
`path: deps`, e a build passa dependendo de um caminho que não descreve nada — o que explica
por que o CI de `development` está verde. Vale menos como vulnerabilidade e mais como
**reprodutibilidade**: um artefato cuja construção depende de um caminho acidental na máquina
de uma pessoa não liga commit a imagem, e essa ligação é o que H7 também pede.

**O conserto mínimo.** `git rm --cached deps` e `deps/` já está no `.gitignore` (linha 8) —
duas linhas de comando, nenhuma de código. E um passo de gate que reprove link simbólico
apontando para dentro da própria árvore, senão isto volta.

**Migração de esquema**: **não**. **Sem release**: não se aplica — não está em produção.
**É o conserto mais barato da lista**, e o único que eu deliberadamente não fiz: correção de
segurança segue o mesmo caminho de todo código, com revisão independente (constituição,
princípio VII), e `git rm --cached` numa branch minha sem revisão seria eu decidindo pela
build de todo mundo.

---

### H13 — `PHX_HOST` cai em `"example.com"` em silêncio

**Severidade: Baixa** · OWASP A05 · ASVS V14.1 (*configuração*)

**Onde.** `config/runtime.exs:105` — `host = System.get_env("PHX_HOST") || "example.com"`.

**O caminho concreto.** Ao lado dele, `DATABASE_URL` (linha 77) e `SECRET_KEY_BASE` (linha 99)
**levantam** quando ausentes. `PHX_HOST` não — e ele alimenta `url: [host: host]` e, o que
importa mais, `check_origin: TheBandWeb.Origens.aceitas(host, ...)` (linha 115). Ausente a
variável, a plataforma sobe declarando `example.com` como o endereço dela e como a origem
aceita do socket. A falha aparece — o LiveView não conecta —, mas aparece como *"a tela não
carrega"*, longe da causa.

É **fallback silencioso** num valor que decide origem aceita, e o princípio VIII o nomeia
antipadrão declarado: ausência é nula, não é um valor plausível.

**O conserto mínimo.** `PHX_HOST` levanta como as outras duas, com a mesma frase. Três linhas,
e alinha o arquivo consigo mesmo.

**Migração de esquema**: **não**.
**Sem release: parcialmente SIM** — garantir a variável no Dokploy remove o caminho hoje (e o
runbook §2 já a lista como segredo obrigatório, o que sugere que ela está lá). O conserto do
fallback é código.

---

### H14 — a expiração de sete dias vive só na hook do LiveView, e mede outra coisa que o comentário diz

**Severidade: Baixa** · OWASP A07 · ASVS V3.3.2 (*expiração de sessão*)

**Onde.** `lib/the_band_web/live/hooks.ex:113-119` — `dentro_da_validade/1`, com
`@validade_dias 7` na linha 18. `lib/the_band_web/plugs/current_scope.ex:24-45` — o plug
confere `user_id` e `session_token`, e **não** confere validade nem `must_change_password`.

**Duas coisas, e a segunda é só de documentação.**

1. **A expiração não vale nas rotas de controller.** A única rota de controller na pipeline
   autenticada é `POST /profile/password` (`router.ex:97`), e ela exige a senha atual — o que
   torna o dano baixo hoje. O achado é a **forma**: a expiração está numa metade das duas
   portas, e a próxima rota de controller herdará a lacuna sem que nada acuse. É o mesmo
   padrão de H1;

2. **o comentário da linha 17 diz "Sete dias de inatividade"**, e o código mede dias desde
   `logged_in_at`. Verificado: `logged_in_at` é escrito **só** em `auth.ex:108`
   (`registrar_sucesso/1`), no login, e em nenhum outro lugar de `lib/`. Portanto a janela é
   **absoluta**, não de inatividade — o comportamento é **mais restritivo** que o documentado.
   Não é vulnerabilidade; é comentário errado num arquivo que decide sessão, e nesta base isso
   custa a credibilidade dos outros comentários.

**O conserto mínimo.** A validade sai da hook para um ponto único que as duas portas
consultam, e o comentário passa a dizer o que o código faz — *"sete dias desde a entrada"* —
ou o código passa a atualizar `logged_in_at`, se inatividade era a intenção. **São decisões
diferentes**, e a escolha é da pessoa mantenedora: janela absoluta é mais segura, janela de
inatividade é mais confortável.

**Migração de esquema**: **não**. **Sem release**: não — é código.

---

### H15 e H16 — endurecimento sem caminho de exploração hoje

Mantidos da §11.4 e §11.6 do documento da API, **reclassificados** porque são código de hoje e
porque a verificação confirmou que nenhum dos dois é explorável agora.

**H15 — `EO.fetch_organization_by_login(tenant_id, login)` recebe o tenant como UUID cru.**
**Severidade: Baixa** (desenho) · A01 · `lib/the_band/ontology/seon/eo/queries.ex:645-652`,
exposta por `eo.ex:158`. A consulta filtra corretamente
(`where: o.tenant_id == ^tenant_id and o.login == ^login`), e os cinco chamadores derivam o id
de fonte já escopada. **Não há vulnerabilidade.** É a **única** das 125 funções públicas dos
sete `queries.ex` que aceita o tenant como UUID em vez de `%Tenant{}` — e é exatamente a forma
que deixaria um tenant vindo de parâmetro entrar sem que a assinatura reclame.

**H16 — o `base_url` da credencial de modelo: a garantia mora no chamador.**
**Severidade: Baixa** (desenho) · A10 · `lib/the_band/ai/provider_credential.ex:58-71` aceita
qualquer `base_url` no changeset; quem garante `https://api.openai.com` é `TheBand.AI.put/3`,
que grava a constante `@base_url`. Correto hoje, frágil por desenho: o segundo chamador não
vai saber. O cenário de ataque que falta, e que os testes atuais não têm porque nunca mandam
uma URL hostil:

> **Quando** `AI.put(tenant, %{"provider" => "openai", "secret" => "<segredo de teste>",
> "base_url" => "http://169.254.169.254/latest/meta-data/"})`;
> **Então** a linha gravada tem `base_url == "https://api.openai.com"`;
> **E** a asserção é sobre **o que ficou no banco**, não sobre o que a função devolveu.

Nenhum dos dois exige migração; nenhum se resolve sem código.

---

## 3. O que foi verificado nesta passagem e está correto

Esta seção existe porque *"não achei nada"* e *"conferi e está certo"* são afirmações
diferentes, e a segunda precisa dizer **como**.

| O que | Como foi verificado | Resultado |
|---|---|---|
| injeção em `fragment/1` | `grep -rn 'fragment("' lib/ \| grep '#{'` | **vazio** — nenhuma interpolação dentro do literal |
| SQL cru | `grep` por `Repo.query!`/`Repo.query(` em `lib/` | dois pontos, ambos em `lib/mix/tasks/the_band.rotate_key.ex:37,70`, com `$1`/`$2` e **sem entrada externa** |
| XSS por `raw/1` | o gate `raw() fora dos templates` (`gates.ex:90,205-231`), verde | nenhum `raw(` em `lib/the_band_web` |
| tenant nos jobs Oban | os **oito** `use Oban.Worker` lidos um a um | os 5 que recebem `tenant_id` o **validam** com `Tenants.fetch/1` antes de agir (`sync_github_eo.ex:52-54`, `generate_worker.ex:77-80`, `run_worker.ex:29-30`, `reprocess_mappings.ex:21-23`, `recompute_promotions.ex:46-47`); os 3 de cron (`schedule_due_syncs`, `reconcile_stuck_syncs`, `monthly_worker`) percorrem tenants e passam `%Tenant{}` adiante |
| pipeline **e** `on_mount` em toda rota | `router.ex:48-139` lido inteiro | as três `live_session` têm o par completo (`:autenticado`/`:current_scope`, `:operacao`/`:require_operacao`, `:admin`/`:require_admin`) |
| redação de campo sensível | `grep -rn "redact: true" lib/` | 5 campos em 3 schemas: `password`, `password_hash`, `session_token`, e os dois `secret` cifrados |
| segredo em log nas bordas HTTP | `grep` por `Logger` em `integrations/`, `ai.ex`, `sources/` | **nenhum** — e `normalize/1` do cliente do GitHub (`http/req.ex:47-48`) devolve o motivo sem os headers |
| cookie de sessão | cadeia lida na fonte: ordem do `Plug.SSL`, `rewrite_on`, `maybe_secure_cookie` | `Secure` presente (dependente do `x-forwarded-proto` do proxy), `HttpOnly` por padrão, `SameSite=Lax`. **Não** cifrado — H10 |
| `GHSA-375f-4r2h-f99j` (Bandit reflete o scheme do cliente) | faixa `>= 1.0.0, < 1.11.0` contra `mix.lock` | **não afetado** — 1.12.5. Importa porque esta base decide o `Secure` do cookie por `conn.scheme` |
| contêiner sem privilégio | `Dockerfile:66-67` | `useradd --create-home band` e `USER band` |
| `dev_routes` e o LiveDashboard | `grep -rn "dev_routes" config/` | só `config/dev.exs:56`; o `if Application.compile_env` de `router.ex:141` não compila em produção |
| segredo no repositório | `.env.example` lido; `.gitignore:40-42` | `.env.example` **não carrega valor** (`THE_BAND_MASTER_KEY=` vazio); `.env` e `.env.*` ignorados com exceção do exemplo |
| FR-005a — recusa de boot sem chave | acidental, e por isso vale: um script meu tentou subir a aplicação sem a chave | recusou, com a mensagem do contrato. **Funciona em produção** |
| `pull_request_target` nos workflows | `grep` nos três arquivos | **ausente** nos três |

---

## 4. O que dá para consertar sem release, e o que exige código

A pergunta 5 do pedido, respondida como tabela.

| Achado | Sem release | O que exatamente |
|---|:---:|---|
| **H7** — `latest` implantado | **sim** | Dokploy passa a puxar `:vX.Y.Z`; ajuste no passo de delivery do `cd.yml`. Nenhuma linha da aplicação |
| **H8** — ações por tag móvel | **sim** | SHA nas ações do `cd.yml`; `permissions: contents: read` no `ci.yml` |
| **H9** — TLS no banco | **depende** | `?ssl=true` no `DATABASE_URL` **se** o certificado for de CA pública; autoassinado exige a CA na imagem (release) |
| **H13** — `PHX_HOST` | **parcial** | garantir a variável no Dokploy remove o caminho hoje; o fallback em si é código |
| **H12** — `deps` symlink | n/a | não está em `main`; dois comandos de git, sem release |
| H1, H2, H3, H4, H5, H6, H10, H11, H14, H15, H16 | não | código, e H3-B também migração |

**Nenhum conserto desta lista exige segredo novo.** Se algum vier a exigir, ele entra como
variável de ambiente no Dokploy, pelo caminho do runbook §2, cuja lista é **fechada por
contrato** — e variável nova ali é mudança de contrato, não ajuste. Nada de valor de segredo
neste documento, em nenhum arquivo do repositório, e em nenhuma conversa.

**Migração de esquema**: apenas **H3 parte B** (`users.disabled_at`), e ela entra com o risco
declarado — o ensaio de restauração do §6 do runbook continua adiado, a conta S3 não existe, e
portanto o caminho de volta é um backup que nunca foi restaurado
(`docs/releases/v0.6.0.md:573-584`, e o item está isolado em
`docs/backlog/backup-restaurado-de-verdade.md`). A mitigação disponível é a que a v0.6.0 usou: ensaiar a
migração contra uma cópia restaurada do banco real, mais o rollback do §5, que não depende de
backup. **É risco declarado, não escondido.**

---

## 5. Para o Product Owner — os itens, dimensionados

Ordenados por severidade. A prioridade é dele; a severidade é minha; a classificação do
entregável decorre dos critérios de aceitação, e quem a deriva é ele.

| # | Item | Sev. | Migração | Sem release | O que acontece se não entrar agora |
|---|---|---|:---:|:---:|---|
| H1 | `/set-password` troca a senha sem a atual | **Alta** | não | não | quem alcança uma sessão fica com a conta e expulsa a pessoa; o conserto é uma cláusula |
| H2 | o veredito vale em 2 de 26 LiveViews | **Alta** | não | não | qualquer conta lê perfil derivado, commits e ranking nominal de qualquer pessoa; **precisa de decisão antes de código** |
| H3 | não há revogação de acesso que funcione | **Alta** | **sim** (parte B) | não | quem sai continua lendo a organização; a parte A não tem migração e fecha metade |
| H4 | nenhum evento de acesso é registrado | Média | não | não | se H1/H2/H3 já foram explorados desde a v0.6.0, não há como saber |
| H5 | sessão encerrada serve no LiveView conectado | Média | não | não | trocar a senha por desconfiança não expulsa a aba aberta |
| H6 | `pode_ver_equipe` contradiz o cabeçalho e a FR-022 | Média | não | doc: sim | a spec da API congela o regime errado sem saber que havia escolha |
| H7 | Dokploy implanta `latest` | Média | não | **sim** | depois de um incidente, não há como dizer qual imagem rodava |
| H8 | ações de CI/CD por tag móvel | Média | não | **sim** | um terceiro executa código com credencial de publicação da produção |
| H9 | `ssl: true` do Repo comentado | a determinar | não | depende | **é uma pergunta para quem opera, e ela é anterior ao conserto** |
| H10 | cookie assinado e não cifrado | Baixa | não | não | `session_token` legível onde o cookie aparecer; consertar derruba as sessões vigentes |
| H11 | exceção de aviso obsoleta no `mix.exs` | Baixa | não | não | supressão dormente de um identificador |
| H12 | `deps` como symlink absoluto | **Média** | não | n/a | **medido**: uma troca de branch apagou `deps` e reprovou um `mix gates` no meio — a árvore fica não-construível |
| H13 | `PHX_HOST` cai em `example.com` | Baixa | não | parcial | fallback silencioso num valor que decide origem aceita |
| H14 | expiração só na hook; comentário diverge | Baixa | não | não | a próxima rota de controller herda a lacuna |
| H15 | assinatura com `tenant_id` cru | Baixa | não | não | a forma que deixaria um tenant de parâmetro entrar sem reclamação |
| H16 | `base_url` garantido pelo chamador | Baixa | não | não | o segundo chamador não vai saber |

**Três decisões da pessoa mantenedora estão no caminho crítico**, e nenhuma é implementação:

1. **H2** — o regime da FR-012 vale para todo dado nominal de pessoa, ou só para as medidas da
   aba? Sem essa resposta, qualquer código escrito ali é palpite;
2. **H6** — administrar concede visão de equipe, sim ou não? A resposta corrige o cabeçalho de
   `access.ex` ou o ramo da linha 273, e desbloqueia a spec da API;
3. **H9** — a base roda no mesmo host da aplicação? A resposta é o que define a severidade.

**Nenhum achado alto está sendo declarado como bloqueio por mim.** H1, H2 e H3 são
**recomendação** de bloqueio da próxima release; a decisão de liberar é do Product Owner, e o
que ela não pode ser é implícita. Liberação com qualquer um deles aberto vai para
`docs/releases/vX.Y.Z.md` como risco residual aceito, com quem decidiu, quando e por quê — o
mesmo registro que a v0.6.0 já fez pela exceção do `decimal`.

E a fronteira na direção oposta: prioridade decidida não apaga o achado. Ele fica **aberto**
até ser corrigido ou explicitamente aceito. *"Despriorizado"* não é *"resolvido"*.

---

## 6. Para o QA — a ordem entre nós

**Todo achado vira teste ANTES de virar correção.** Um teste que falha por causa do defeito e
passa depois do conserto — sem isso o achado reincide e ninguém percebe, que é o mecanismo do
sucesso silencioso.

Os cenários estão escritos dentro de H1, H2, H3, H4, H5 e H16. Quatro deles **já foram
medidos** por um arquivo temporário que rodou e foi removido (a remoção conferida com
`test ! -f`, e a árvore conferida com `git status`), e as cinco asserções passaram. Isso muda o
que o QA precisa fazer: os testes não precisam descobrir se o defeito existe — precisam
**inverter** a asserção, para que passem depois do conserto e reprovem se ele for desfeito.

O que eu peço que o teste que volta carregue, e é herdado das regras da casa:

1. **a guarda de que ele mediu alguma coisa.** Todos os cinco cenários que rodei têm uma —
   `refute alvo.must_change_password`, `assert {:nao, motivo}`, `assert suspenso.status ==
   "suspended"`, `refute elo_vigente?`. Sem elas, o teste passaria por não ter estabelecido o
   cenário, e celebraria;
2. **metade das asserções em `refute`.** É a natureza do assunto: o nome **não** apareceu, a
   senha nova **não** valeu, o tenant suspenso **não** entrou, o segredo **não** foi logado;
3. **dois tenants povoados** onde houver isolamento em jogo (constituição, princípio V);
4. **nenhum segredo real em fixture** — `mix the_band.gen_key` para chave, string óbvia para
   token;
5. **o teste-par do conserto de H1**: com `must_change_password` verdadeiro, o POST **funciona**.
   Sem ele, o conserto poderia fechar a porta legítima e a suíte não acusaria.

O `mix gates` é do QA, e o veredito é o código de saída dele. Na execução que sustenta este
documento ele saiu **0**, com os 15 gates verdes, sobre a árvore de `development` em `f4bdeeb`
**antes** de qualquer conserto — o que significa que
**nenhum dos dezesseis achados acima é visível a nenhum gate atual**. Isso não é falha dos
gates; é o que a revisão independente existe para acrescentar.

---

## 7. O que eu NÃO verifiquei, e por quê

Esta seção é resultado, não ressalva. Sem ela, o documento seria lido como *"o resto está
seguro"*, e não é isso que ele diz.

1. **a topologia de produção** — se a base roda no mesmo host da aplicação (H9), e se a porta
   HTTP da aplicação é alcançável fora do proxy. A segunda pergunta importa porque
   `rewrite_on: [:x_forwarded_proto]` confia no header de quem chega: com a porta exposta, um
   cliente em texto claro pode declarar `https` e receber cookie `Secure` por um canal que não
   é. **É pergunta para quem opera**, e eu não a resolvo por leitura de código;
2. **os segredos e as variáveis do ambiente de produção** — não peço, não leio, não aceito em
   conversa. Inclui se `THE_BAND_PREVIOUS_MASTER_KEY` foi removida depois da última rotação:
   mantê-la publicada mantém viva a chave que se quis aposentar, e o estado do ambiente não é
   legível daqui;
3. **os atributos do cookie na resposta HTTP real** — a cadeia foi verificada na fonte das
   dependências, ponta a ponta, mas não houve captura de resposta de `app.theband.dev`. Não
   uso credencial nem endereço de produção para confirmar achado;
4. **os 24 LiveViews de H2 um a um quanto ao conteúdo exato.** O `grep` por veredito é
   exaustivo, e é ele que sustenta o achado — mas a leitura detalhada foi de **sete** nesta
   passagem (`people_live/show.ex`, `change_live/commits.ex`, `verification_live/people.ex`,
   `change_live/index.ex`, `people_live/index.ex`, `work_item_live/index.ex`,
   `profile_live/index.ex`) mais `teams_live/show.ex` na passagem anterior. **Os outros
   dezoito não foram lidos quanto ao que exibem** — e cada um pode conter dado nominal que eu
   não contei. O inventário de H2 é um **piso**, não um total;
5. **as duas rotas de H2 com dado povoado.** As provas mostram que as rotas **abrem** para
   quem o veredito recusou, com a identidade da pessoa na página em `/people/:id` e
   `/people/:id/commits`. Que `/work/verifications/people` exibe os logins vem do `select` da
   consulta (`verification.ex:653-654`), lido, **não medido com dado povoado**. A conclusão
   *"não consulta veredito nenhum"* está provada; *"e mostra estes nomes nesta tela"* está
   lida;
6. **o Dokploy** — não abri o painel, não sei se ele hoje puxa `latest` de fato ou se alguém
   já o apontou para uma versão. H7 vem do que o `cd.yml:90` afirma;
7. **a exportação, a impressão e a telemetria** — nenhuma passagem sobre se algum caminho
   serializa struct de conta ou de credencial para fora (`mix qa.reports`, métricas,
   relatório). Era o item 11 da §13 do documento anterior e **continua aberto**: o que eu fiz
   foi confirmar `redact: true` nos cinco campos, que protege `inspect/1` e não protege uma
   serialização escrita à mão;
8. **`mix knowledge.validate` com o YAML de limiar de H5** — o intervalo de revalidação vai
   para a base de conhecimento (FR-069), e eu não escrevi o arquivo nem sei se ele casa com o
   schema sem ajuste. Quem escrever descobre no gate;
9. **quantos tenants existem em produção, e se algum já está `suspended`.** H3 prova que a
   coluna não é aplicada; se alguém já a usou acreditando que era, isso é uma pergunta para
   quem opera, e a resposta muda a urgência;
10. **se H1, H2 ou H3 já foram explorados.** Não é verificável — é exatamente o que H4 diz. A
    plataforma não registra os eventos que responderiam, e `registrar_sucesso/1` zera o único
    contador que existia. **Registro esta impossibilidade como resultado**, porque ela é a
    consequência de H4 e não uma lacuna da minha passagem;
11. **`mix credo --strict` e `mix dialyzer` isoladamente.** Passaram dentro de `mix gates`
    (saída 0, 15 verdes), e eu não os rodei em separado nem li seus achados um a um.

**E o mais importante**: este documento cobre o que eu consegui alcançar em uma passagem
guiada pela §11 do documento anterior. **Não é uma varredura completa do repositório.** A
varredura completa é outro trabalho, e este não é ele. Dezesseis achados numa base com 15
gates verdes é o número que uma revisão independente produz quando olha o que as ferramentas
não olham — não o número total do que existe.

---

## Referências

**Nesta base**: `.specify/memory/constitution.md` (princípios III, V, VI, VII, VIII, XI) ·
`AGENTS.md` §14, §15, §17 · `lib/mix/tasks/gates.ex` (a definição única dos gates) ·
`docs/sprints/licoes-aprendidas.md` (L19, L69) · `docs/producao/runbook.md` §2, §4, §5, §6 ·
`docs/releases/v0.6.0.md` (o risco residual do backup, linhas 573-584) ·
`docs/producao/ensaio-2026-09-08-migracao-060.md` (o formato do ensaio de migração) ·
`specs/023-painel-da-pessoa/spec.md` (FR-012 a FR-012j) ·
`specs/045-autenticacao-e-acesso/contracts/auth.md` e `contracts/access-scopes.md` ·
`specs/052-primeira-conta-do-ambiente/contracts/primeira-conta.md` ·
`docs/seguranca/2026-09-09-api-com-token.md` (§11, a âncora) ·
`docs/seguranca/2026-09-08-decimal-expoente-ilimitado.md`

**Fora**: OWASP Top 10 (2021) A01, A02, A05, A06, A07, A08, A09, A10 · OWASP ASVS V2, V3, V4,
V7, V9, V10, V14 · `GHSA-375f-4r2h-f99j` (Bandit, corrigido em 1.11.0 — não afeta 1.12.5)
