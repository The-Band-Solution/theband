# Feature Specification: A organização do tenant, e as organizações do GitHub que ela observa

**Feature Branch**: `059-organizacao-do-tenant`

**Created**: 2026-09-06

**Status**: Draft — escrita pelo papel de Product Owner a pedido da pessoa
mantenedora em 2026-09-06. **Duas decisões estão em aberto e marcadas como
tal** (o modelo ontológico e a URL da organização); nenhuma foi tomada aqui.

**Input**: User description: "Devemos reformular o conceito de tenant e
organization. No The Band um tenant é para uma organization. Não é a mesma
organization do GitHub. Uma organization do EO pode ter relação com uma ou mais
organizations do GitHub. O GitHub usa organization para agrupar repositórios.
Assim, devemos mudar isso. Devemos criar o conceito de organization ao subir o
sistema pela primeira vez. Depois planejar um Sign up em que o administrador, ao
se cadastrar no The Band, informa a sua organization (e.g., Leds, IFES, ...)."

Acréscimo da mesma pessoa, no mesmo dia: *"quando cadastrar uma organization, ela
ganha uma URL de login — `app.theband.dev/<organization>` ou
`<organization>.theband.dev` — o que é melhor?"*. E o fato que muda a resposta:
**o domínio `theband.dev` já existe, registrado na GoDaddy.**

## O problema, medido no código

A plataforma tem **duas coisas chamadas "organização"**, e o código sabe disso —
o moduledoc de `lib/the_band/tenants/tenant.ex:2-8` diz, literalmente: *"Não
confundir com `EO.Schemas.Organization`, que é a organização **observada** na
ferramenta de origem. São coisas diferentes: uma é quem usa a plataforma, a outra
é o que a plataforma conhece."* A distinção está no comentário e **não está no
modelo**: o tenant é uma linha com `name`, `slug` e `status`
(`priv/repo/migrations/20260809120000_create_tenants_and_users.exs:14-21`), e a
instituição que usa a plataforma — Leds, IFES — não existe como organização em
lugar nenhum. O que existe como `eo.organization` é **só** o que a coleta trouxe
do GitHub.

### Onde os dois conceitos estão colapsados

| # | Onde | O que o código faz | O que confunde para quem usa |
|---|---|---|---|
| 1 | `lib/the_band/tenants/bootstrap.ex:62-63`, `:117`, `:142-152` | a função documentada como *"Cria a organização e o primeiro administrador"* cria um `%Tenant{}`; as variáveis são `THE_BAND_TENANT_NOME` e `THE_BAND_TENANT_SLUG` (`:53-58`) | o runbook (`docs/producao/runbook.md:114`) pede *"nome legível da organização"* e a plataforma grava um tenant. A instituição nomeada ali não vira `eo.organization`, e nenhuma tela a mostra como organização |
| 2 | `lib/the_band/ontology/seon/eo/schemas/organization.ex:42-61` | o único changeset de `eo_organizations` é `from_source_changeset`: exige `source_system`, `external_id`, `collected_at`. Não há caminho para uma organização **declarada** | a organização do tenant não pode existir em EO sem ter sido coletada de uma ferramenta. Uma instituição sem GitHub não tem organização |
| 3 | `lib/the_band/jobs/sync_github_eo.ex:515-531` → `lib/the_band/semantic_integration.ex:200-201` → `lib/the_band/ontology/seon/eo.ex:34` | cada `organization_login` de uma ferramenta conectada vira uma linha de `eo_organizations` pelo mapeamento `github.organization.to.eo.organization` | a organização do GitHub é promovida ao conceito ontológico de organização **inteira** — e o próprio mapeamento diz que não é (ver abaixo) |
| 4 | `lib/the_band_web/components/layouts.ex:103-104` e `:149` | o menu tem o item **"Organization"** que leva a `/organizations`; o cabeçalho mostra `{@current_tenant.name}` | a mesma tela mostra "organização" duas vezes com dois significados: no cabeçalho, a instituição; no conteúdo, as organizações do GitHub |
| 5 | `lib/the_band_web/live/organization_live/index.ex:70`, `:87-99` | a página **"Organization"** lista o que a EO tem — as organizações coletadas — e, vazia, diz *"No organisation observed yet. Organisations arrive with the collection"* | para quem acabou de instalar, a plataforma afirma que a organização dela **não existe ainda** — e só passa a existir depois de uma coleta do GitHub |
| 6 | `lib/the_band_web/live/source_live/index.ex:480-482`, `:532`, `:192` | o formulário de conectar ferramenta pede *"Organisation to observe"*; a lista mostra *"observed organisation: X"*; a recusa diz *"another organization is another tool"* | aqui "organização" é o **recorte da ferramenta** — correto, mas com a mesma palavra da tela ao lado |
| 7 | `lib/the_band_web/live/sync_live/index.ex:743-747` | comentário: *"A organização vem da ferramenta conectada, que **é** a organização"* | o código afirma a identidade entre ferramenta conectada e organização — que é exatamente o que o pedido nega |
| 8 | `lib/the_band/tenants/access/scope_grant.ex:18`; `lib/the_band/tenants/access.ex:128-136`, `:469-470`; `lib/the_band_web/live/access_scopes_live/index.ex:92`, `:160`, `:209` | a concessão de escopo `organization` tem como alvo uma linha de `eo_organizations`, listada por `EO.list_organizations/1` | *"responsável pela organização"* (spec 045, FR-023, `specs/045-autenticacao-e-acesso/spec.md:288-290`) significa **responsável por uma organização do GitHub**, não pela instituição. Quem responde pela Leds inteira precisa de uma concessão por organização do GitHub |
| 9 | `lib/the_band/ontology/seon/eo/schemas/organizational_role.ex:11-15`, `:49` | papéis organizacionais têm `organization_id` — por organização do GitHub (issue #317: *"um papel cadastrado vazava para as três organizações do tenant, que não compartilham vocabulário nenhum"*) | o vocabulário de papéis da instituição está fragmentado por agrupamento de repositórios. "Tech Leader" na organização X do GitHub e "Tech Leader" na Y são dois papéis |
| 10 | `lib/the_band/ontology/seon/eo/schemas/team.ex:37`; `lib/the_band/ontology/seon/spo/schemas/project_organization.ex:19` | equipe e projeto ligam-se a `eo_organizations` — logo, a uma organização do GitHub | "a organização tem um ou mais projetos" (decisão de 2026-09-01, `docs/backlog/projeto-pertence-a-organizacao.md`) está sendo gravada contra a organização **errada**: o projeto pertence à instituição, e a tabela o liga ao agrupamento de repositórios |
| 11 | `lib/the_band_web/live/people_live/show.ex:1801-1802` | a coluna *"organisation"* da pessoa mostra `equipe.organization_login \|\| "not declared"` | a organização da pessoa é apresentada como um login do GitHub |
| 12 | `lib/the_band/mapping/decision.ex:42`; `priv/knowledge_base/rules/tenants/the_band_solution.yaml` | uma regra da base de conhecimento é chaveada pelo **slug do tenant** (`the_band_solution`) | o identificador da instalação faz papel de identificador da instituição. Quando as duas coisas se separarem, a regra precisa saber de qual fala |

A corrente que hoje liga ferramenta a organização é **por texto, não por chave**:
`connected_tools.organization_login ↔ eo_organizations.login`
(`lib/the_band_web/live/organization_live/index.ex:20-24`,
`lib/the_band_web/operacao.ex:6-9`, `lib/the_band/semantic_integration.ex:98`,
`lib/the_band/raw_data.ex:122`, `lib/the_band/ontology/seon/eo/queries.ex:554-560`).
Nenhuma dessas passagens conhece a instituição.

Ocorrências da palavra por tela, contadas em 2026-09-06 (`grep -c -i
organization lib/the_band_web/live/**`): `organization_live/index.ex` 15,
`source_live/index.ex` 14, `sync_live/index.ex` 11, `projects_live/index.ex` 11,
`people_live/show.ex` 11, `roles_live/index.ex` 8, `sync_live/mapping_rules.ex` 7,
`teams_live/show.ex` 6, `verification_live/index.ex` 5, `teams_live/index.ex` 5,
`people_live/index.ex` 5, `access_scopes_live/index.ex` 4. Em **todas**, a
palavra designa a organização do GitHub.

### O que a base de conhecimento já diz — e o código ignora

O mapeamento `priv/knowledge_base/mappings/github/eo/organization.yaml` declara
`equivalence: partial` e justifica (`:9-12`): *"Uma organização do GitHub é um
agrupamento administrativo de repositórios e pessoas. Corresponde parcialmente à
organização de EO: **não representa a estrutura organizacional real, apenas o
recorte visível na ferramenta**."* E limita (`:19`): *"Uma organização no GitHub
pode representar apenas uma unidade organizacional, não a organização inteira."*

A base já sabe que são coisas diferentes. O modelo derivado promoveu o recorte a
organização inteira mesmo assim, e é isso que o pedido corrige.

### O dado que existe

Medido em 2026-08-31 no ensaio local de restauração
(`docs/sprints/026-heranca-e-a-producao/aceitacao.md:137`): **`eo_organizations=3`
num tenant só**, com `eo_people=88` e `eo_teams=12`. Duas das três estão nomeadas
no código (`lib/the_band/ontology/seon/eo/commands.ex:644`, `:687`):
`The-Band-Solution` e `leds-conectafapes`. A terceira não consta no repositório.
**Não há medida da produção** nesta spec: a aplicação não foi consultada, e o
número acima é do ambiente de desenvolvimento.

Esse dado carrega uma pergunta que o modelo novo torna inevitável:
`leds-conectafapes` é a organização do GitHub do **Leds**, observada dentro de um
tenant chamado **The Band Solution**. Se um tenant é **uma** organização, qual
instituição é essa? Ver a pergunta 3 abaixo.

## A distinção conceitual proposta

Dois conceitos, e o pedido diz como se relacionam:

| | A organização do The Band | A organização do GitHub |
|---|---|---|
| **o que é** | a instituição que usa a plataforma — Leds, IFES | o agrupamento de repositórios e pessoas que a ferramenta expõe |
| **quantas por tenant** | **uma** — *"um tenant é para uma organization"* | **N** — *"pode ter relação com uma ou mais"* |
| **como nasce** | **declarada**: no boot da primeira instalação, ou no sign up | **observada**: pela coleta da ferramenta conectada |
| **na EO** | é `eo.organization` no sentido pleno — *"agente social que reconhece papéis organizacionais e emprega pessoas"* (`priv/knowledge_base/ontology/seon/eo/modules/organizational_structure.yaml:16-21`) | hoje é promovida a `eo.organization`; o mapeamento diz que é **parcial** |
| **hoje no código** | não existe; o tenant faz as vezes dela | `eo_organizations`, uma linha por `organization_login` coletado |

A relação entre elas é **declarada por quem conecta**: conectar uma organização
do GitHub à plataforma é afirmar que ela pertence à instituição do tenant. Não há
inferência — e não pode haver, porque nada na API do GitHub diz a que instituição
uma organização pertence.

### O que a EO oferece para representar a relação

A ontologia já tem três relações que candidatam-se a carregar isso, e uma coluna
que ninguém usa:

| Relação em EO | Cardinalidade | Onde | Serve? |
|---|---|---|---|
| `eo.organization` *is part of* `eo.organization` | muitos → zero ou um | `organizational_structure.yaml:151-156`; coluna `eo_organizations.parent_organization_id` (`organization.ex:27`), **hoje nunca preenchida pela coleta** | sim, se a organização do GitHub for tratada como organização subordinada |
| `eo.organizational_unit` *belongs to* `eo.organization` | muitos → um | `organizational_structure.yaml:197-200` | sim, se a organização do GitHub for tratada como unidade organizacional — é o que a limitação do mapeamento sugere |
| `eo.organizational_team_belongs_to_organization` | muitos → um | `organizational_structure.yaml:207-213`; `eo_teams.organization_id` | é para onde as equipes observadas apontam hoje; muda de alvo nas duas alternativas |

### Alternativa A — uma classe, duas proveniências, e a relação de composição

A organização do tenant é uma linha de `eo_organizations` **declarada**
(proveniência da decisão do tenant, sem `source_system` de ferramenta), e cada
organização do GitHub continua sendo uma linha de `eo_organizations`
**observada**, ligada à do tenant por `parent_organization_id` — a relação
*is part of* que a ontologia já declara e a coluna que já existe.

| Prós | Contras |
|---|---|
| nenhum conceito novo, nenhuma relação nova: usa `eo.organization` e a composição que a EO já tem | afirma que um **agrupamento de repositórios** é *parte de* uma organização no sentido ontológico — o mapeamento diz que é apenas "recorte visível", que pode coincidir com a instituição inteira, com uma unidade, ou com nada que exista no organograma |
| a coluna `parent_organization_id` existe e está vazia; a migração é preencher | mistura na mesma tabela o declarado e o observado, com o mesmo estereótipo `kind` |
| equipes, papéis, escopos e projetos continuam apontando para `eo_organizations`; o que muda é **para qual linha** | quando a organização do GitHub coincide com a instituição (um tenant, uma org do GitHub — o caso comum), a composição afirma que a coisa é parte de si mesma sob outro nome |
| a página `/organizations` vira a árvore: a instituição, e as organizações do GitHub abaixo dela | `eo.organization` *is part of* tem alvo `zero_or_one` — impede que uma organização do GitHub seja compartilhada por duas instituições **no mesmo tenant**; como tenant é uma instituição, não é problema hoje, e é limitação a declarar |

**Variante A′** — a organização do GitHub como `eo.organizational_unit` da
organização do tenant. É o que a limitação do mapeamento (`organization.yaml:19`)
literalmente diz. Falha nos mesmos dois casos: quando a organização do GitHub é a
instituição inteira, e quando ela não corresponde a nenhuma unidade real. Fica
registrada como variante, não como terceira alternativa.

### Alternativa B — a organização do GitHub deixa de ser `eo.organization`

Só a instituição é `eo.organization`. A organização do GitHub passa a ser o que a
ferramenta conectada **já é** no código (`sync_live/index.ex:743-744`: *"a
ferramenta conectada, que é a organização"*): um recorte de observação, do lado
das fontes (`lib/the_band/sources/`), identificado por `instance_url` +
`organization_login`, com o payload preservado. Equipes observadas passam a
pertencer à organização do tenant (`eo.organizational_team_belongs_to_organization`,
alvo trocado) e a carregar **de qual recorte** vieram como proveniência, não como
relação ontológica.

| Prós | Contras |
|---|---|
| é o que a semântica declarada pede: o mapeamento diz *partial* e *"não representa a estrutura organizacional real"* — B para de fingir que representa | a migração é larga: trocam de alvo `eo_teams.organization_id`, `eo_organizational_roles.organization_id`, `access_scope_grants` com `level = organization`, `spo_project_organizations.organization_id`, e `eo_organizations` perde as linhas observadas |
| uma só "Organization" na interface; o escopo `organization` passa a significar a instituição, que é o que a spec 045 quis dizer | a decisão da issue #317 — papéis por organização do GitHub porque *"não compartilham vocabulário"* — é revertida: os papéis passam a ser da instituição, um vocabulário só. Se a fragmentação era um sintoma da confusão, é correção; se era necessidade real, é regressão. **Precisa ser perguntado** |
| coerente com a ADR 0003: *"GitHub é fonte, não conceito"* — o agrupamento de repositórios da ferramenta é dado de fonte, e mora nas bordas | `priv/knowledge_base/sources/github.yaml:19` declara `organization` com `feeds_ontologies: [eo]`, e o mapeamento `github.organization.to.eo.organization` seria aposentado ou redirecionado — é mudança na base de conhecimento, com histórico |
| a corrente `organization_login ↔ login` por texto desaparece: a ferramenta **é** o recorte, e a relação com a instituição é a chave `tenant_id` mais o vínculo declarado | as consultas que hoje partem de `eo_organizations` (`queries.ex:472`, `:494`, `:554`, `:582`, `:608`, `:636`, `:660`, `:684`, `:716`, `:777`, `:1056`, `:1198`, `:1218`) mudam de origem |

### O que as duas têm em comum, e o que a decisão precisa dizer

Nas duas, **a organização do tenant é `eo.organization` declarada**, e a relação
com as organizações do GitHub é **declarada no ato de conectar**. O que muda é se
a organização do GitHub continua sendo um conceito da EO (A) ou volta a ser dado
de fonte (B).

**[NEEDS CLARIFICATION — decisão da pessoa mantenedora, com o perfil de
Ontologia]**: A ou B? A decisão fixa: (1) o alvo de `eo_teams.organization_id`,
`eo_organizational_roles.organization_id`, `access_scope_grants.target_id` e
`spo_project_organizations.organization_id`; (2) o destino do mapeamento
`github.organization.to.eo.organization`; (3) se os papéis organizacionais são
da instituição ou do recorte (#317). Este papel **não decide modelo ontológico**;
apresenta o que cada um custa e o que cada um exige da aceitação.

**O que nenhuma das duas viola**: a ADR 0003 (não nasce módulo `TheBand.GitHub`
no domínio; a travessia continua por mapeamento declarado); o princípio IX
(nenhuma dependência nova entre ontologias); o princípio III (o payload bruto da
organização do GitHub continua preservado, e a relação declarada guarda quem
declarou e quando).

## A URL da organização

O pedido: *"quando cadastrar uma organization, ela ganha uma URL de login —
`app.theband.dev/<organization>` ou `<organization>.theband.dev` — o que é
melhor?"*

Hoje a plataforma tem **um endereço para todos os tenants** e o tenant vem da
sessão: `lib/the_band_web/plugs/current_scope.ex:24-45` lê `user_id` da sessão,
busca a conta, e assina `user.tenant`. Nem o host nem o caminho participam. Todas
as rotas nascem em `/` sem segmento de tenant (`lib/the_band_web/router.ex:48-137`).
Com N organizações no mesmo deployment, a URL passa a **selecionar** a organização
antes da sessão — e é isso que as duas alternativas fazem de formas diferentes.

### As duas alternativas

| | Subdomínio — `<org>.theband.dev` | Caminho — `app.theband.dev/<org>` |
|---|---|---|
| **quem seleciona o tenant** | o host da requisição | o primeiro segmento do caminho |
| **onde a seleção acontece** | um plug novo antes de `CurrentScope`, lendo `conn.host` | o roteador: todas as rotas ganham o prefixo `/:org` |
| **o que muda nas telas** | nada nos links: `~p"/teams/#{id}"` continua válido dentro do host | **todo** link `~p` das telas passa a carregar o slug, ou a plataforma gera link para a organização errada |

### Fator (a) — isolamento de sessão

O cookie de sessão é definido em `lib/the_band_web/endpoint.ex:7-12`:
`store: :cookie`, `key: "_the_band_key"`, `same_site: "Lax"`, **sem `domain`**.
Cookie sem `domain` é do host que o emitiu: o navegador não envia o cookie de
`leds.theband.dev` para `ifes.theband.dev`. O socket da LiveView usa as mesmas
opções (`endpoint.ex:14-16`).

| Subdomínio | Caminho |
|---|---|
| **isolamento por construção**: a sessão de uma organização não chega à outra, sem código. A fronteira entre tenants deixa de ser só `WHERE tenant_id` e ganha uma segunda camada, do navegador | **um cookie serve a todos**: a sessão aberta em `/leds` é enviada em `/ifes`. Cada rota precisa reafirmar que a conta da sessão pertence à organização do caminho — verificação que roda em toda requisição e que, esquecida numa rota, é vazamento |
| **o risco inverso**: acrescentar `domain: ".theband.dev"` para "compartilhar o login" entrega a sessão de uma organização a todas — uma linha desfaz o isolamento. Precisa virar invariante escrito (FR-022) | a garantia é do código, não da construção; é a classe de defeito que `AGENTS.md` já nomeia (*consulta sem tenant*) com um segundo membro: **consulta com o tenant errado** |

### Fator (b) — infraestrutura

O que o repositório registra sobre o endereço de produção (`docs/producao/runbook.md`):

- a origem responde em `https://theband.5.189.161.85.sslip.io` (`:167`, `:224`);
- o domínio `app.theband.dev` está no §9 (`:151-203`), com `PHX_HOST=app.theband.dev`
  e o `sslip.io` em `THE_BAND_ORIGENS_EXTRAS` (`:224-225`);
- a emissão do certificado pelo Traefik **não foi diagnosticada** (`:201-203`: *"A
  causa não foi diagnosticada — o log do Traefik não chegou a ser lido"*);
- o caminho alternativo §9-B (`:273-294`) usa o Cloudflare à frente, com um
  certificado de origem que cobre `*.theband.dev` e `theband.dev` (`:280`), e o
  certificado apresentado ao navegador é o Universal SSL do Cloudflare, medido em
  2026-09-01 (`:292-294`);
- a aceitação da feature 054 estava **pendente** na v0.3.0
  (`docs/releases/v0.3.0.md`, seção "A exceção, declarada"): SC-002 e SC-003 só se
  medem com o domínio no ar.

**Fato novo, 2026-09-06**: o domínio `theband.dev` **existe, registrado na
GoDaddy**. Isso remove o impedimento que faria o caminho ser a única opção
viável a curto prazo.

| Subdomínio | Caminho |
|---|---|
| exige DNS curinga, certificado curinga e um domínio real — **o domínio existe** | funciona no endereço atual, inclusive no `sslip.io`, sem mexer em DNS nem certificado |
| cada organização nova **não** exige ato de infraestrutura: o curinga cobre | cada organização nova é só uma linha no banco |

**Pré-requisitos a conferir** — apontados por quem coordena a sessão em
2026-09-06; **não medidos** nesta spec, e destinados a virar itens do runbook
(§9) quando a decisão for tomada:

1. certificado curinga `*.theband.dev` exige desafio **DNS-01** no Traefik do
   Dokploy, com acesso à API do provedor de DNS;
2. a API de DNS da GoDaddy passou a exigir conta com 10+ domínios ou plano pago
   para emitir chaves de produção — o caminho comum é manter o registro na
   GoDaddy e **delegar o DNS à Cloudflare** (nameservers), usando o provedor
   Cloudflare no Traefik. O runbook §9 já descreve o Cloudflare à frente de
   `app.theband.dev` (`:176`, `:249`, `:287`); se a delegação já está feita, este
   item já está atendido — **a conferir**;
3. registros `A *.theband.dev` e `A theband.dev` apontando para o VPS. Atenção ao
   que o runbook diz em `:178-181`: o apex serve o **site público** hoje, e não
   pode ser tocado sem decisão;
4. o TLD `.dev` está na lista de **HSTS preload**: só HTTPS, desde a primeira
   requisição. Sem certificado válido para o nome, não há página — nem insegura
   (é o que a 054 já registrou em US1, cenário 3);
5. slugs reservados: `www`, `app`, `api`, `admin`, `status` — ver fator (d).

### Fator (c) — Phoenix

| Subdomínio | Caminho |
|---|---|
| **plug de resolução pelo host**: novo, antes de `CurrentScope`; lê `conn.host`, extrai o rótulo, busca o tenant pelo slug. Hoje não existe nada que leia o host | **escopo no roteador**: `scope "/:org"` envolvendo os três escopos atuais de `router.ex:48-137`; um plug lê `conn.path_params["org"]` |
| **`check_origin`**: hoje é uma lista literal montada por `TheBandWeb.Origens.aceitas/2` (`lib/the_band_web/origens.ex:45-48`) a partir de `PHX_HOST` e `THE_BAND_ORIGENS_EXTRAS` (`config/runtime.exs:114-115`). Precisa aceitar o curinga `*.theband.dev`. `docs/backlog/setup-inicial-e-multiempresa.md` afirma que a lista *"aceita `*.theband.dev` como entrada"* — **não conferido por execução nesta spec**; o módulo só concatena o esquema à entrada, e a interpretação do curinga é do transporte do Phoenix | nada muda: um host, uma origem |
| **socket da LiveView**: mesma sessão, mesmo cookie por host — isolado junto | mesmo cookie para todos os caminhos; a LiveView precisa reverificar o tenant no `mount`, porque o socket não passa pelo plug do roteador — é o `on_mount` de `lib/the_band_web/live/hooks.ex:29` que assina `current_tenant` |
| **`url: [host: ...]`** (`runtime.exs:114`) gera links absolutos com um host só — e-mails e redirecionamentos precisam do host da organização | um host só, sem mudança |
| **desenvolvimento**: `config/dev.exs:23` tem `check_origin: false` e host `localhost`; subdomínio local pede `lvh.me` ou `*.localhost` (os navegadores resolvem `*.localhost` para a própria máquina — **a conferir**) | nada muda |

### Fator (d) — slugs reservados e enumeração

`Tenant.changeset` (`lib/the_band/tenants/tenant.ex:33`) valida só o formato
`^[a-z0-9-]+$`. **Não há lista de reserva**: `app`, `www`, `api`, `admin` e
`status` passam. No subdomínio, a primeira organização chamada `app` toma o lugar
da plataforma; no caminho, `/admin` colide com rota futura. A lista é necessária
nas duas opções, e é mais urgente na primeira.

**Enumeração**: as duas opções expõem o slug na URL, e qualquer pessoa pode testar
nomes. A recusa para quem abre a URL de uma organização de que não é membro
**não pode distinguir** *"não existe"* de *"você não faz parte"* — é o invariante 2
de `docs/backlog/setup-inicial-e-multiempresa.md`, e vale igual nas duas. O sign
up (US3) tem um problema irmão: *"este slug já está em uso"* revela existência por
construção. É trade-off para o perfil de Security (ver Impacto).

### Recomendação, e de quem é

**Recomendação técnica de quem coordena a sessão, registrada como tal em
2026-09-06**: **subdomínio por organização — `<org>.theband.dev`** — para o
produto, com o domínio existindo. O caminho fica como transição apenas se a
infraestrutura do curinga atrasar; não como destino.

A razão que pesa mais é o fator (a): o isolamento por host é **do navegador**, não
do código. Uma rota esquecida não vaza sessão. Tudo o mais — plug, `check_origin`,
DNS — é trabalho com fim; a reverificação por rota do caminho é trabalho que não
acaba, porque cada rota nova a repete.

**[NEEDS CLARIFICATION — decisão da pessoa mantenedora]**: subdomínio ou caminho?
A decisão fixa FR-020 a FR-023 e o piso de infraestrutura do sprint que
implementar a US3. **Esta spec não implementa a URL**: ela decide a direção, e a
implementação do subdomínio é feature própria (ver Fora de escopo), porque exige
o runbook, o DNS e a aceitação da 054 antes.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A organização nasce com a instalação (Priority: P1)

Quem instala a plataforma pela primeira vez preenche as variáveis do §8 do
runbook, implanta, entra — e a plataforma **já sabe qual é a organização dela**:
o nome informado aparece como a organização, a página `/organizations` mostra
essa organização com zero organizações do GitHub conectadas, e diz que a
ausência é de **conexão**, não de existência.

**Why this priority**: sem a organização do tenant não há a que ligar as do
GitHub (US2), nem o que o sign up cria (US3), nem para onde migrar (US4). É a
base das outras três.

**Independent Test**: subir contra um banco vazio com as variáveis da 052;
entrar; conferir que a organização existe com o nome de `THE_BAND_TENANT_NOME`,
sem nenhuma coleta ter rodado.

**Acceptance Scenarios**:

1. **Given** um banco vazio e as variáveis do §8 definidas, **When** a plataforma
   sobe, **Then** existem o tenant, **a organização do tenant** com o nome
   informado, e o administrador — num ato único: falha em qualquer um dos três
   não deixa nenhum.
2. **Given** a plataforma do cenário 1, **When** o administrador abre
   `/organizations`, **Then** vê a organização dele nomeada, com **zero
   organizações do GitHub conectadas**, e a frase diz que nenhuma foi
   conectada — nunca *"No organisation observed yet"*.
3. **Given** a plataforma do cenário 1, **When** ela sobe de novo, **Then** nada
   é criado nem alterado — a idempotência da 052 se estende à organização.
4. **Given** um banco restaurado com tenant e sem organização (o estado que a US4
   corrige), **When** a plataforma sobe com as variáveis, **Then** a organização
   é criada para o tenant existente, e não um segundo tenant.

---

### User Story 2 - Conectar organizações do GitHub à organização (Priority: P1)

Quem administra conecta uma organização do GitHub — como hoje, em `/tools` — e o
que ela conecta passa a aparecer **como organização do GitHub observada pela
organização dele**: com login, instância, e a marca do que a distingue da
instituição. Conecta uma segunda, e as duas ficam sob a mesma organização. Encerra
a observação de uma, e ela continua no histórico como *observada até*.

**Why this priority**: é o que o pedido diz que hoje está errado — *"uma
organization do EO pode ter relação com uma ou mais organizations do GitHub"* —
e o esquema já suporta N por tenant (`connected_tools`, índice único incluindo
`organization_login`, `connected_tool.ex:68-71`; `eo_organizations=3` medidas em
2026-08-31). O que falta é a relação e a tela dizerem isso.

**Independent Test**: conectar duas organizações do GitHub; abrir
`/organizations`; ver a organização do tenant uma vez, e as duas do GitHub
abaixo dela, cada uma com seu login e sua instância.

**Acceptance Scenarios**:

1. **Given** a organização do tenant existe e nenhuma ferramenta está conectada,
   **When** o administrador conecta a organização `X` do GitHub, **Then**
   `/organizations` mostra `X` **sob** a organização do tenant, rotulada como
   organização do GitHub, e diz que a coleta ainda não rodou — ausência nomeada,
   não zero.
2. **Given** `X` conectada e coletada, **When** o administrador conecta `Y`,
   **Then** as duas aparecem sob a **mesma** organização do tenant; nenhuma delas
   aparece como "a organização" no cabeçalho.
3. **Given** `X` e `Y` conectadas, **When** a observação de `X` é encerrada,
   **Then** `X` continua listada como *observada até <data>*; suas equipes e
   pessoas continuam alcançáveis pelo histórico.
4. **Given** a relação declarada entre `X` e a organização do tenant, **When** se
   consulta a proveniência, **Then** ela diz **quem** conectou e **quando** — a
   relação é declaração, e declaração tem autor.
5. **Given** dois tenants, cada um com sua organização e suas organizações do
   GitHub, **When** qualquer tela é aberta em um deles, **Then** nenhuma
   organização — do tenant ou do GitHub — do outro aparece.

---

### User Story 3 - Sign up: o administrador informa a sua organização (Priority: P2)

Alguém que ainda não tem conta abre a página de sign up, informa os dados dela e
**o nome da organização** (Leds, IFES), e sai com um tenant novo, a organização
dele, e a própria conta como administradora — sem console, sem variável de
ambiente, sem que outro administrador exista antes.

**Why this priority**: P2 porque a US1 já entrega a primeira instalação, e o
sign up é o caminho para a **segunda organização em diante**. É também a
superfície nova de segurança (cadastro público) que precisa de avaliação antes de
existir — ver Impacto.

**Independent Test**: com a plataforma no ar e um tenant existente, fazer sign
up para uma organização nova; entrar; conferir que a nova não vê nada da
existente, e vice-versa.

**Acceptance Scenarios**:

1. **Given** a página de sign up, **When** alguém informa os dados da pessoa e o
   nome da organização, **Then** nascem tenant, organização e conta
   administradora **num ato único**, e a pessoa entra com poder de administração
   sobre a organização recém-criada — e só sobre ela.
2. **Given** um nome de organização cujo slug já existe, **When** o sign up
   tenta, **Then** recusa nomeando o conflito, e **não cria nada**.
3. **Given** um slug da lista de reservados (`www`, `app`, `api`, `admin`,
   `status`), **When** o sign up tenta, **Then** recusa, e a recusa diz que o nome
   é reservado.
4. **Given** um sign up que falha depois de criar o tenant, **When** se inspeciona
   o banco, **Then** não há tenant sem organização nem organização sem
   administrador — o mesmo invariante da 052 (FR-004 dela).
5. **Given** a organização criada por sign up, **When** a pessoa conecta uma
   organização do GitHub, **Then** o fluxo é o da US2, sem passo adicional.

**Cenários que dependem de decisão em aberto** (perguntas 1 e 7): se o sign up
é por e-mail e senha (fluxo da 045) ou pelo GitHub (fluxo da 049); se é aberto ou
por convite. Os cenários acima valem nos dois casos; o que muda é a prova de
identidade da pessoa.

---

### User Story 4 - O dado existente ganha a organização que lhe falta (Priority: P2)

Quem opera atualiza a plataforma e, ao subir, cada tenant existente ganha **a sua
organização**, e cada organização coletada do GitHub passa a ser **organização do
GitHub ligada à organização do tenant**. Nada é perdido, nada é adivinhado, e o
log diz o que foi feito por tenant.

**Why this priority**: sem ela, a produção sobe com o modelo novo e o dado
velho — a organização do tenant não existe e as três coletadas continuam sendo
"a organização". P2 e não P1 porque a US1 entrega uma instalação nova correta
sozinha; mas **a US4 é pré-requisito do release** desta feature, porque a
produção já tem dado.

**Independent Test**: restaurar o banco do ensaio de 2026-08-31 (`eo_people=88
eo_teams=12 eo_organizations=3`), subir a versão nova, e conferir: um tenant,
uma organização do tenant, três organizações do GitHub ligadas a ela, e as
contagens de equipes, pessoas, papéis, concessões e vínculos de projeto
**inalteradas**.

**Acceptance Scenarios**:

1. **Given** um tenant com N organizações coletadas e nenhuma organização do
   tenant, **When** a migração roda, **Then** existe **exatamente uma**
   organização do tenant com `tenant.name`, e as N coletadas estão ligadas a ela.
2. **Given** a migração do cenário 1, **When** se contam `eo_teams`,
   `eo_people`, `eo_organizational_roles`, `access_scope_grants` e
   `spo_project_organizations` antes e depois, **Then** as contagens são iguais,
   e cada linha continua resolvendo para uma organização existente.
3. **Given** a migração, **When** ela roda de novo, **Then** não cria segunda
   organização nem religa nada — é idempotente como o bootstrap.
4. **Given** um tenant sem nenhuma organização coletada, **When** a migração
   roda, **Then** ele ganha a organização do tenant e zero ligações — e o log diz
   isso, não fica em silêncio.
5. **Given** a regra *"um tenant é uma organização"*, **When** a migração liga as
   coletadas, **Then** ela **não** decide a que instituição cada uma pertence
   por nome nem por semelhança: liga **todas** as do tenant à organização do
   tenant, porque essa é a única derivação sem adivinhação. Se isso for falso
   para algum tenant (pergunta 3), a correção é humana e vem antes da migração,
   não dentro dela.

### Edge Cases

- **Tenant cujo nome não serve como nome de organização.** A migração usa
  `tenant.name` e `tenant.slug`; se estiverem errados (o seed de desenvolvimento
  tem `"Outra Organização"`, `priv/repo/seeds.exs:63`), a organização nasce com o
  nome errado e é **renomeável** pela tela, com autor e data. Adivinhar melhor não
  é opção.
- **Organização do GitHub observada por dois tenants.** Já é possível hoje: são
  duas linhas em `eo_organizations`, uma por tenant. Cada uma liga-se à
  organização **do seu** tenant. Nenhuma tela de um tenant sabe que o outro
  observa a mesma.
- **Slug do tenant colide com nome reservado.** Só acontece por dado existente
  anterior à lista (a produção pode ter qualquer slug — não é verificável neste
  repositório). A migração **não renomeia**: registra no log e a plataforma sobe.
  Renomear slug é decisão humana, porque a URL (se subdomínio) muda com ele.
- **Sign up para uma organização que já existe como organização do GitHub
  coletada de outro tenant.** Não há colisão: são entidades diferentes, em
  tabelas ou proveniências diferentes. Nenhuma inferência de "já existe".
- **Variáveis do §8 presentes num banco que já tem organização.** Nada muda —
  FR-011 da 052 já reaproveita o tenant pelo slug; a organização é
  reaproveitada pelo tenant.
- **Primeira hora vazia após o sign up.** A pessoa termina o cadastro e não há
  coleta. A tela diz *"nenhuma organização do GitHub conectada"* e aponta para
  `/tools` — nunca zero em painel.
- **A conta com o mesmo e-mail em duas organizações.** `users.email` é único
  **global** (`priv/repo/migrations/20260809120000_create_tenants_and_users.exs:36`),
  e `users.tenant_id` é um só (`user.ex:3`, `:64`). A pessoa que administra a
  Leds e a IFES com o mesmo e-mail **não consegue** fazer o segundo sign up. É
  limitação a declarar na recusa, e a pergunta 8 pede a decisão.

## Requirements *(mandatory)*

### A organização do tenant

- **FR-001**: Todo tenant MUST ter **exatamente uma** organização do tenant, e a
  plataforma MUST NOT permitir tenant sem ela depois desta feature.
- **FR-002**: A organização do tenant MUST ser `eo.organization` **declarada**,
  com proveniência de declaração — quem, quando, por qual ato (boot, sign up ou
  migração) — e MUST NOT exigir `source_system`, `external_id` nem `collected_at`
  de ferramenta.
- **FR-003**: No boot da primeira instalação, a organização MUST nascer no mesmo
  ato único que cria tenant e administrador (052, FR-004), a partir de
  `THE_BAND_TENANT_NOME` e `THE_BAND_TENANT_SLUG`, **sem variável nova** — a lista
  de `bootstrap.ex:52-58` é contrato fechado, e a mesma informação já está nela.
- **FR-004**: Reiniciar MUST NOT criar segunda organização nem alterar a
  existente (idempotência da 052 estendida).
- **FR-005**: O nome da organização MUST ser editável por quem administra, com
  autor e data; o slug MUST NOT ser editável pela tela nesta feature (ver
  pergunta 9).

### As organizações do GitHub

- **FR-006**: Cada organização do GitHub conectada MUST estar ligada à
  organização do tenant por relação **declarada** no ato de conectar, com autor e
  data. Nenhuma ligação MUST ser inferida por nome, login ou semelhança.
- **FR-007**: Uma organização do tenant MUST poder ter N organizações do GitHub,
  em instâncias distintas ou na mesma — o índice de `connected_tool.ex:68-71`
  já permite, e permanece.
- **FR-008**: A organização do GitHub MUST NOT aparecer, em nenhuma tela, com o
  rótulo "Organization" sem qualificador. O rótulo MUST dizer que é organização
  **do GitHub** (ou da ferramenta), e MUST mostrar login e instância.
- **FR-009**: Encerrar a observação de uma organização do GitHub MUST preservar a
  relação com a organização do tenant como histórico (*observada de … até …*),
  nunca apagá-la.
- **FR-010**: A corrente `connected_tools.organization_login ↔
  eo_organizations.login` por texto MUST ser substituída por chave, na forma que
  a alternativa escolhida determinar (A: `parent_organization_id`; B: a
  ferramenta é o recorte). Enquanto a decisão não sai, este FR fixa o
  **objetivo**, não o meio.

### O sign up

- **FR-011**: A plataforma MUST oferecer um caminho de cadastro em que uma pessoa
  sem conta informa os dados dela e o nome da organização, e MUST criar tenant,
  organização e conta administradora **num ato único** — ou nada.
- **FR-012**: O sign up MUST recusar slug já existente e slug reservado, nomeando
  o motivo, e MUST NOT criar nada na recusa.
- **FR-013**: A lista de slugs reservados MUST existir como dado declarado (não
  como constante espalhada), MUST conter ao menos `www`, `app`, `api`, `admin`,
  `status`, e MUST ser aplicada também pelo bootstrap e pela migração — que a
  **reportam** em vez de renomear.
- **FR-014**: A conta criada pelo sign up MUST ter poder de administração
  **apenas** sobre a organização recém-criada; MUST NOT existir caminho pelo qual
  o sign up conceda acesso a qualquer outro tenant.
- **FR-015**: A prova de identidade da pessoa no sign up — e-mail e senha (045)
  ou GitHub (049) — MUST ser a que a pergunta 7 decidir; esta spec MUST NOT
  introduzir um terceiro mecanismo.
- **FR-016**: O sign up MUST ser avaliado pelo perfil de Security **antes** de
  entrar em sprint, com o resultado registrado no `plan.md` da feature (ver
  Impacto). Sem essa avaliação registrada, a US3 MUST NOT ser puxada.

### A migração do dado existente

- **FR-017**: Para cada tenant existente sem organização, a migração MUST criar a
  organização do tenant com `tenant.name` e proveniência *migração 059, data*.
- **FR-018**: Toda organização coletada existente MUST ser ligada à organização
  **do seu** tenant, sem exceção e sem heurística — a única derivação admitida é
  `tenant_id`.
- **FR-019**: A migração MUST ser idempotente, MUST reportar no log o que fez por
  tenant (organização criada ou já existente; N ligações), e MUST NOT alterar a
  contagem de nenhuma tabela além de `eo_organizations` (criação) e da relação
  escolhida.

### A URL da organização — direção, não implementação

- **FR-020**: A URL de acesso a uma organização MUST selecionar o tenant **antes**
  da sessão, na forma que a pergunta 5 decidir; esta spec fixa a direção e MUST
  NOT implementar o plug de host nem o prefixo de rota.
- **FR-021**: A recusa para quem acessa a URL de organização de que não é membro
  MUST NOT distinguir *"não existe"* de *"você não faz parte"*.
- **FR-022**: O cookie de sessão MUST continuar **sem `domain`**
  (`endpoint.ex:7-12`), e essa ausência MUST ser protegida por teste — porque uma
  linha a desfaz.
- **FR-023**: Toda consulta continua recebendo o tenant explicitamente
  (constituição V); a seleção pela URL MUST alimentar `current_tenant`, e MUST NOT
  criar um segundo caminho para descobri-lo.

### Regras que valem em toda a feature

- **FR-024**: Nenhum conceito ou relação nova MUST entrar no código antes de estar
  declarado em `priv/knowledge_base/` — princípio IV e FR-021 da 058, que vale
  aqui igual.
- **FR-025**: Ausência MUST ser nomeada: *zero organizações do GitHub conectadas*
  é frase, não painel vazio; *coleta ainda não rodou* é frase, não zero.
- **FR-026**: A interface continua em inglês com pt como tradução; os novos
  rótulos ("GitHub organization", "observed until") MUST entrar no catálogo
  (`047`).

### Key Entities

- **Tenant** — a fronteira de isolamento (`tenants`); permanece, e passa a ter
  exatamente uma organização.
- **Organização do tenant** — `eo.organization` declarada: a instituição. Nome,
  slug (herdado do tenant), proveniência de declaração.
- **Organização do GitHub** — o recorte que a ferramenta expõe; hoje
  `eo_organizations` observada, amanhã o que a alternativa decidir. Login,
  instância, período de observação.
- **Relação organização do tenant ↔ organização do GitHub** — declarada ao
  conectar, com autor, data e fim (quando a observação encerra).
- **Ferramenta conectada** — `connected_tools`; permanece a unidade de
  credencial, intervalo e coleta.

## Success Criteria *(mandatory)*

- **SC-001**: Depois do boot (US1) ou da migração (US4), **100%** dos tenants
  têm exatamente uma organização do tenant — verificável por consulta:
  `count(tenants) = count(organizações do tenant)`.
- **SC-002**: **Zero** organizações do GitHub sem organização do tenant — a
  consulta que busca órfãs devolve nenhuma linha.
- **SC-003**: `/organizations` mostra a organização do tenant **uma vez**, e
  abaixo dela **todas** as organizações do GitHub conectadas, cada uma com login
  e instância; organização conectada e não coletada aparece com a ausência dita.
- **SC-004**: Nenhuma tela usa o rótulo "Organization" sem qualificador para uma
  organização do GitHub — verificável lendo os templates dos 12 arquivos listados
  em "O problema".
- **SC-005**: O sign up completa num ato: depois dele a pessoa entra e vê a
  organização; se falha, `count(tenants)`, `count(organizações)` e `count(users)`
  são os mesmos de antes.
- **SC-006**: Dois tenants povoados: **nenhuma** organização — do tenant ou do
  GitHub — de um aparece em tela alguma do outro (constituição V, teste de
  vazamento).
- **SC-007**: A migração sobre o dado do ensaio de 2026-08-31 produz **1**
  organização do tenant e **3** organizações do GitHub ligadas, com `eo_people`,
  `eo_teams`, `eo_organizational_roles`, `access_scope_grants` e
  `spo_project_organizations` com contagens **iguais** antes e depois — medidas
  por SQL, e registradas no `aceitacao.md`.
- **SC-008**: Rodar a migração duas vezes produz o mesmo estado da primeira.
- **SC-009**: O cookie de sessão não tem `domain` — asserção em teste sobre
  `@session_options`.
- **SC-010**: Os slugs reservados são recusados no sign up, e reportados (não
  renomeados) pelo bootstrap e pela migração.
- **SC-011**: 100% dos conceitos e relações novos estão em `priv/knowledge_base/`
  antes de aparecer em tela.

## Fora de escopo

- **Implementar a URL por organização** — subdomínio ou caminho. Esta spec decide
  a direção (FR-020 a FR-023) e o resto é feature própria, que depende do
  runbook §9, do DNS e da aceitação pendente da 054.
- **Prova de posse da organização do GitHub** (App do GitHub instalado na
  organização) — é o coração de `docs/backlog/setup-inicial-e-multiempresa.md` e
  continua lá. Aqui, conectar é declarar; provar é feature seguinte.
- **Entrar com o GitHub** (049) — spec pronta, não implementada
  (`grep -rli oauth lib/` só encontra `integrations/github/client.ex`). Se a
  pergunta 7 escolher o GitHub como prova no sign up, a 049 vira pré-requisito.
- **Uma conta em vários tenants** — `users.tenant_id` único e `users.email` único
  global permanecem. A pergunta 8 registra o custo.
- **O elo projeto → organização** como decisão de cardinalidade
  (`docs/backlog/projeto-pertence-a-organizacao.md`). Aqui só se registra que
  `spo_project_organizations` hoje aponta para a organização observada e mudará
  de alvo com a alternativa escolhida.
- **Teto de custo por tenant** — a cota é do usuário do GitHub (ADR 0007) e o
  gestor a governa; limite de repositórios ou de coleta por organização é decisão
  de produto separada (pergunta 4 do backlog de setup).
- **Regras da base por tenant** (`priv/knowledge_base/rules/tenants/`) — a
  chave `the_band_solution` continua sendo slug do tenant; se deve passar a ser a
  organização é decisão do perfil de Ontologia (pergunta 10).

## Perguntas abertas — para a pessoa mantenedora

| # | Pergunta | Por que decide o desenho | Leitura que este papel faria, se tivesse de escolher |
|---|---|---|---|
| 1 | **[NEEDS CLARIFICATION]** O sign up é **aberto na internet** ou **por convite** (link emitido por quem já administra a plataforma)? | aberto é superfície pública: enumeração de slugs, criação em massa de tenants, custo de coleta sem teto. Convite mantém o controle e adia a avaliação de segurança mais pesada | por convite primeiro; aberto quando a prova de posse (App) existir |
| 2 | **[NEEDS CLARIFICATION]** Um tenant pode ter **mais de uma** organização do The Band? O pedido diz *"um tenant é para uma organization"* — é **exatamente uma**? E a organização do tenant e o tenant são **a mesma coisa com dois nomes** ou duas entidades? | 1:1 estrito permite derivar a migração sem adivinhar (US4, cenário 5). Duas entidades permitem à organização ter proveniência, papéis e relações da EO sem que a tabela `tenants` as carregue | exatamente uma; duas entidades — o tenant é fronteira de isolamento, a organização é agente social. Misturá-las repetiria o colapso que a spec desfaz |
| 3 | **[NEEDS CLARIFICATION]** O que acontece com o tenant **atual**? Em desenvolvimento é `the-band-solution` (`seeds.exs:58`); em produção, o slug é o que `THE_BAND_TENANT_SLUG` recebeu e **não consta no repositório**. Ele observa `The-Band-Solution` e `leds-conectafapes` — organizações do GitHub de instituições **diferentes**. Sob "um tenant é uma organização", a migração ligaria a organização do Leds à instituição The Band Solution | é a única situação em que a derivação da US4 produz uma afirmação falsa. A correção é humana e **vem antes** da migração | ou o tenant atual é declarado como "The Band Solution" e `leds-conectafapes` passa para um tenant "Leds" criado por sign up; ou o tenant atual **é** o Leds. Não sei qual; é a pessoa mantenedora quem sabe |
| 4 | **[NEEDS CLARIFICATION]** Modelo ontológico: **A** (organização do GitHub como `eo.organization` subordinada, via `parent_organization_id`) ou **B** (organização do GitHub como recorte da fonte, fora da EO)? Decisão com o perfil de Ontologia | fixa o alvo de quatro colunas e o destino de um mapeamento — ver "O que as duas têm em comum" | — este papel não decide modelo; apresenta o custo |
| 5 | **[NEEDS CLARIFICATION]** URL: **subdomínio** `<org>.theband.dev` ou **caminho** `app.theband.dev/<org>`? | fator (a) a (d) acima | a recomendação técnica registrada é subdomínio; a decisão é da pessoa mantenedora |
| 6 | **[NEEDS CLARIFICATION]** A organização nasce no boot **das variáveis existentes** (FR-003) ou de um **passo de configuração** na primeira entrada? | as duas informações já estão nas variáveis da 052; um passo na tela criaria um segundo caminho para a mesma verdade. Mas um passo na tela permite ao administrador corrigir o nome antes de existir | das variáveis, sem variável nova — e o nome é editável depois (FR-005) |
| 7 | **[NEEDS CLARIFICATION]** A prova de identidade no sign up é **e-mail e senha** (045) ou **GitHub** (049)? | 049 não está implementada; escolhê-la torna-a pré-requisito e adia a US3. E-mail e senha reusa o que existe, e deixa o GitHub para a US3 da 049 | e-mail e senha agora; GitHub quando a 049 entregar |
| 8 | **[NEEDS CLARIFICATION]** A mesma pessoa administrando **duas** organizações: uma conta com dois vínculos, ou duas contas com e-mails distintos? Hoje `users.email` é único global e `users.tenant_id` é um só | é a pergunta 1 de `docs/backlog/setup-inicial-e-multiempresa.md`, e o sign up a torna concreta: o segundo cadastro com o mesmo e-mail é recusado | fora desta feature; a recusa diz o motivo e a decisão fica registrada como lacuna |
| 9 | **[NEEDS CLARIFICATION]** O slug da organização é **editável**? Se a URL for subdomínio, mudar o slug muda o endereço de todo mundo | fixa FR-005 | não editável pela tela nesta feature; migração de slug é ato administrativo com registro |
| 10 | **[NEEDS CLARIFICATION]** Papéis organizacionais (#317) passam a ser **da instituição** (um vocabulário) ou continuam **por organização do GitHub**? | a alternativa B os unifica por construção; a A permite os dois | da instituição — a fragmentação por agrupamento de repositórios parece sintoma do colapso, não necessidade. Mas é a #317 que sabe por que foi feita |

## Impacto

### Tabelas e schemas

| Tabela / schema | Onde | O que muda |
|---|---|---|
| `tenants` | `priv/repo/migrations/20260809120000_create_tenants_and_users.exs:14-23`; `lib/the_band/tenants/tenant.ex:19-27` | permanece; ganha a relação 1:1 com a organização do tenant; `changeset:33` ganha a lista de reservados |
| `eo_organizations` | `lib/the_band/ontology/seon/eo/schemas/organization.ex:20-38` | ganha um changeset de **declaração** (hoje só `from_source_changeset:42`); em A, `parent_organization_id:27` passa a ser preenchida; em B, perde as linhas observadas |
| `connected_tools.organization_login` | `lib/the_band/sources/connected_tool.ex:27-28`, `:68-71`, `:74-80` | permanece como identidade do recorte; a corrente por texto (FR-010) é substituída por chave |
| `eo_teams.organization_id` | `lib/the_band/ontology/seon/eo/schemas/team.ex:37`, `:86`, `:93` | muda de alvo conforme a alternativa |
| `eo_organizational_roles.organization_id` | `lib/the_band/ontology/seon/eo/schemas/organizational_role.ex:49`, `:79`, `:84` | idem; decide a pergunta 10 |
| `access_scope_grants` com `level = organization` | `lib/the_band/tenants/access/scope_grant.ex:18`; `priv/repo/migrations/20260828160856_access_scope_grants.exs:25-26` | o alvo passa a ser a organização do tenant (B) ou continua a do GitHub (A) — em A, "responsável pela instituição" precisa de nova leitura |
| `spo_project_organizations.organization_id` | `lib/the_band/ontology/seon/spo/schemas/project_organization.ex:19`; migration `20260816210000:28-51` | idem. **Divergência registrada**: `docs/backlog/projeto-pertence-a-organizacao.md` afirma que a relação organização → projeto *"não existe"*; a tabela existe desde a feature 028 e aponta para a organização **observada**. Os dois documentos precisam ser reconciliados pelo perfil de Ontologia |
| `users` | `lib/the_band/tenants/user.ex:3`, `:64`; migration `:36` (`unique_index(:users, [:email])`) | permanece; a limitação global do e-mail é declarada na recusa do sign up |

### Módulos

| Módulo | Onde | O que muda |
|---|---|---|
| `TheBand.Tenants.Bootstrap` | `lib/the_band/tenants/bootstrap.ex:53-58`, `:115-136`, `:142-152` | cria a organização no mesmo ato; lista de variáveis **não** muda |
| `TheBand.Tenants` | `lib/the_band/tenants.ex:48` (`create_tenant`) | ganha o caminho do sign up: tenant + organização + admin num ato |
| `TheBand.Ontology.SEON.EO` | `lib/the_band/ontology/seon/eo.ex:34`; `queries.ex:472`, `:494`, `:554`, `:582`, `:608`, `:636`, `:660`, `:684`, `:716`, `:777`, `:1056`, `:1198`, `:1218` | ganha a organização declarada; as consultas que partem de `eo_organizations` distinguem tenant e GitHub |
| `TheBand.Jobs.SyncGithubEO.collect_organization` | `lib/the_band/jobs/sync_github_eo.ex:515-531` | em A, grava `parent_organization_id`; em B, deixa de promover a `eo.organization`. **Arquivo em mudança ativa pela ADR 0007** — ver Dependências |
| `TheBand.SemanticIntegration` | `lib/the_band/semantic_integration.ex:98`, `:200-201` | a rota `"github.organization"` muda de destino ou de forma |
| `TheBand.Tenants.Access` | `lib/the_band/tenants/access.ex:128-136`, `:274-283`, `:436-455`, `:469-470` | o escopo `organization` resolve para o alvo novo |
| `TheBandWeb.Operacao` | `lib/the_band_web/operacao.ex:6-21` | o recorte operacional deixa de casar por `organization_login` |
| `TheBand.RawData` | `lib/the_band/raw_data.ex:103-114`, `:135-159` | as consultas por `organization_login` atravessam a relação nova |
| `TheBand.Mapping.Decision` | `lib/the_band/mapping/decision.ex:42` | a chave da regra por tenant — pergunta 10 |

### Telas

| Tela | Onde | O que muda |
|---|---|---|
| menu e cabeçalho | `lib/the_band_web/components/layouts.ex:103-104`, `:149` | "Organization" passa a apontar para a organização do tenant; o cabeçalho mostra o nome dela |
| `/organizations` | `lib/the_band_web/live/organization_live/index.ex:70`, `:87-99`, `:102-161` | vira a página **da** organização: nome, e a lista das organizações do GitHub abaixo, cada uma com login, instância e período. A frase vazia muda (US1, cenário 2) |
| `/tools` | `lib/the_band_web/live/source_live/index.ex:480-482`, `:532`, `:192` | "Organisation to observe" vira "GitHub organisation to observe"; conectar declara a relação (US2) |
| `/syncs` | `lib/the_band_web/live/sync_live/index.ex:301`, `:458`, `:743-763` | o rótulo qualifica; o comentário `:743-744` deixa de ser verdade e sai |
| `/access-scopes` | `lib/the_band_web/live/access_scopes_live/index.ex:92`, `:160`, `:209` | o alvo do escopo `organization` |
| `/people/:id` | `lib/the_band_web/live/people_live/show.ex:1801-1802` | a coluna "organisation" qualifica |
| `/roles` | `lib/the_band_web/live/roles_live/index.ex` (8 ocorrências, não lidas linha a linha) | pergunta 10 |
| sign up | **nova** — `/sign-up`, ao lado de `/sign-in` (`router.ex:52`) | US3 |

### Base de conhecimento e documentação

| Onde | O que muda |
|---|---|
| `priv/knowledge_base/mappings/github/eo/organization.yaml` | A: ganha a relação `parent` declarada no ato de conectar; B: aposentado ou redirecionado. Decisão do perfil de Ontologia |
| `priv/knowledge_base/sources/github.yaml:19` | B: `feeds_ontologies` da entidade `organization` muda |
| `priv/knowledge_base/ontology/seon/eo/modules/organizational_structure.yaml:151-156`, `:197-200`, `:207-213` | as relações usadas ganham nota de uso; nenhuma relação nova nas duas alternativas |
| `docs/producao/runbook.md:104-135` (§8) | a frase *"nome legível da organização"* passa a ser verdadeira; ganha a nota de que a organização nasce junto |
| `docs/producao/runbook.md:151-294` (§9) | recebe os cinco pré-requisitos da URL quando a pergunta 5 for decidida |
| `specs/052-primeira-conta-do-ambiente/spec.md:47`, `:136`, `:166` | a palavra "organização" ali significa tenant; ganha nota remissiva a esta spec |
| `docs/backlog/setup-inicial-e-multiempresa.md` | as features 1 e 2 daquele desenho são absorvidas parcialmente aqui (a empresa se cria; conectar declara); a prova de posse e o subdomínio continuam lá |
| `docs/backlog/projeto-pertence-a-organizacao.md` | reconciliar com `spo_project_organizations` existente |

### Riscos de segurança — para o perfil de Security avaliar

O sign up é **superfície nova**: hoje toda conta nasce de administrador
(`/accounts`, 045/051) ou do ambiente (052); depois desta feature, nasce de quem
chegar à página. `AGENTS.md:805` atribui ao perfil Security *"autenticação,
autorização, tokens, permissões, logs, dependências, dados sensíveis"*. Este papel
**não escreve cenário de ataque**; aponta onde a avaliação precisa olhar, e
FR-016 condiciona a US3 a ela:

- criação de tenant por qualquer pessoa: volume, custo de coleta, e o que
  impede a criação em massa;
- enumeração de slugs pelo sign up (*"já existe"*) e pela URL (FR-021);
- a lista de reservados como dado, e o que acontece com slug reservado já
  existente;
- e-mail global único: o que a recusa revela sobre a existência de contas em
  outros tenants;
- o cookie sem `domain` como invariante (FR-022, SC-009), e a diferença de
  superfície entre subdomínio e caminho (fator a);
- a relação declarada ao conectar como afirmação **não provada** de posse da
  organização do GitHub — a prova é feature seguinte, e até lá qualquer tenant
  pode declarar qualquer organização pública do GitHub como sua.

## Dependências e ordem

### O que está em curso e encosta nesta feature

| Em curso | Estado em 2026-09-06 | Onde encosta |
|---|---|---|
| **ADR 0007 — gestor de cotas** | PR [#808](https://github.com/The-Band-Solution/theband/pull/808) mergeada em `development` em 2026-09-06 22:50Z (partes 1, 2, 3 e 5); partes 4 e 6 nos commits `a0b8a17` e `0619aac`. A **Verificação 4** da ADR (medida real da coleta completa) está pendente — e é a coleta que roda no servidor de desenvolvimento agora | `lib/the_band/jobs/sync_github_eo.ex` e `lib/the_band/sources/` são tocados pelas duas. **A US2 e a US4 não devem entrar em sprint antes da Verificação 4 da ADR 0007 estar registrada**: mudar `collect_organization` durante a medida invalida a medida |
| **Sprint 029** | review encerrada em 2026-09-03 (`docs/sprints/029-medidas-da-equipe/sprint-review.md`): 3 US, 20 de 21 tarefas; a não entregue é a revisão independente | nenhuma sobreposição de código; a regra de **não puxar trabalho novo com item sem destino** exige que a pendência da 029 tenha bloqueador nomeado antes do próximo planejamento — e tem: revisão por terceiro |
| **v0.5.0** | `mix.exs:7` diz `0.5.0`; commit `be1073f` (#794). `docs/releases/` só tem registro até v0.3.0 — **lacuna de registro** de v0.4.0 e v0.5.0, fora desta spec mas anotada | a US4 é migração de esquema com dado em produção: exige o ensaio de restauração em dia antes do release que a leve (regra da release, ato 4) |

### De que esta feature depende

| Dependência | Para qual parte | Estado |
|---|---|---|
| decisão da pergunta 4 (modelo A ou B) com o perfil de Ontologia | US2, US4, FR-010 | em aberto |
| decisão da pergunta 3 (o tenant atual) | US4, cenário 5 | em aberto; **bloqueia o release** da US4 |
| avaliação do perfil de Security (FR-016) | US3 | não iniciada |
| 049 — entrar com o GitHub | US3, **só** se a pergunta 7 escolher GitHub | spec pronta, não implementada |
| 054 — domínio próprio, aceitação pendente | a URL (fora de escopo aqui), **só** se a pergunta 5 escolher subdomínio | SC-002/SC-003 da 054 não medidos |
| contrato da 052 (lista fechada de variáveis) | US1 | FR-003 o respeita: nenhuma variável nova |

### O que esta feature destrava

- `docs/backlog/servidor-mcp.md:34-46`: bloqueado em *"autenticação e tenant"* —
  com a organização como entidade e a URL como seletor, a decisão 1 daquele
  documento ganha o vocabulário que falta;
- `docs/backlog/setup-inicial-e-multiempresa.md`: o wizard passa a ter onde
  gravar a empresa; sobra a prova de posse e o endereço;
- o escopo `organization` da 045 passa a poder significar o que o nome diz.

### Relação com os itens de backlog que já tratam disto

Esta spec **não substitui** os dois documentos de 2026-09-01; consolida-se com
eles, e o item [`docs/backlog/organizacao-do-tenant-e-sign-up.md`](../../docs/backlog/organizacao-do-tenant-e-sign-up.md)
diz o que muda em cada um:

- [`setup-inicial-e-multiempresa.md`](../../docs/backlog/setup-inicial-e-multiempresa.md):
  esta spec é a continuação das features 1 (a empresa se cria) e 4 (o endereço),
  e **vem antes** delas na ordem — sem a instituição como entidade, o wizard não
  tem onde gravar, o App não tem a quem provar posse, e o subdomínio não tem o
  que selecionar. A afirmação de que o modelo *"já está de pé"* é corrigida: o
  que está de pé é a cardinalidade N ferramentas por tenant; a instituição não
  existe.
- [`projeto-pertence-a-organizacao.md`](../../docs/backlog/projeto-pertence-a-organizacao.md):
  o elo que aquele documento diz não existir **existe** (`spo_project_organizations`,
  feature 028) e aponta para a organização do GitHub; esta spec diz qual
  organização aquele documento quer dizer — a instituição — e registra a
  divergência para o perfil de Ontologia reconciliar.

### Ordem proposta para o backlog — proposta, a decidir na priorização

Não é plano de execução. A instrução da pessoa mantenedora em 2026-09-06 foi
*"antes de fazer isso, coloque no backlog e vamos listar as prioridades"*; a
tabela abaixo é a ordem que este papel proporia, e existe para que a
priorização tenha algo concreto a aceitar ou recusar.

| Ordem | O quê | Por quê nesta posição |
|---|---|---|
| 0 | decidir as perguntas 2, 3, 4 e 5 | sem elas a US2 e a US4 não têm critério de aceitação fechado, e a spec não passa de `/speckit-plan` |
| 1 | **US1** — a organização nasce com a instalação | não toca o job de coleta; entrega fatia vertical (tela `/organizations` muda); pode andar em paralelo à Verificação 4 da ADR 0007 |
| 2 | **US4** — migração | pré-requisito do release; depois da Verificação 4 da ADR 0007 e da resposta à pergunta 3 |
| 3 | **US2** — conectar declara | toca `collect_organization`; depois da Verificação 4 |
| 4 | **US3** — sign up | depois da avaliação de Security (FR-016) e da decisão da pergunta 1 |
| 5 | a URL por organização | feature própria; depois da 054 aceita e do runbook §9 com os cinco pré-requisitos conferidos |

## Assumptions

- **Um tenant, uma organização, exatamente** — lido do pedido (*"um tenant é
  para uma organization"*); a pergunta 2 confirma.
- **Conectar é declarar, não provar.** A prova de posse da organização do GitHub
  é feature seguinte (`docs/backlog/setup-inicial-e-multiempresa.md`), e até ela
  a relação é afirmação do tenant sobre si mesmo — registrada como tal.
- **As variáveis da 052 bastam para a US1.** `THE_BAND_TENANT_NOME` e
  `THE_BAND_TENANT_SLUG` já carregam nome e identificador da instituição; a lista
  fechada de `bootstrap.ex:52` não muda.
- **A interface é em inglês**, com pt como tradução (assunção da 058, mantida).
- **O dado de produção não foi medido nesta spec.** Os números citados são do
  ensaio local de 2026-08-31; a aceitação da US4 inclui medir contra o banco
  real antes e depois.
- **A recomendação de URL é técnica e de terceiro**: registrada como de quem
  coordena a sessão em 2026-09-06; a decisão é da pessoa mantenedora.
- **Nenhum conceito foi batizado aqui.** "Organização do tenant" e "organização
  do GitHub" são prosa; o `id` que cada uma receberá na base depende da pergunta
  4, e quem o dá é o perfil de Ontologia.
