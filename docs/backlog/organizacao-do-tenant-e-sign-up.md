# A organização do tenant, as organizações do GitHub, e o sign up

Levantado em 2026-09-06, a pedido da pessoa mantenedora. **Já tem spec-rascunho**:
[059 — A organização do tenant, e as organizações do GitHub que ela observa](../../specs/059-organizacao-do-tenant/spec.md),
com duas decisões marcadas em aberto (modelo ontológico e URL). A instrução do
mesmo dia foi: *"antes de fazer isso, coloque no backlog e vamos listar as
prioridades"* — este documento é o item de backlog; **nada foi implementado nem
planejado para execução**.

O pedido, na forma em que veio:

> *"Devemos reformular o conceito de tenant e organization. No The Band um
> tenant é para uma organization. Não é a mesma organization do GitHub. Uma
> organization do EO pode ter relação com uma ou mais organizations do GitHub. O
> GitHub usa organization para agrupar repositórios. Assim, devemos mudar isso.
> Devemos criar o conceito de organization ao subir o sistema pela primeira vez.
> Depois planejar um Sign up em que o administrador, ao se cadastrar no The Band,
> informa a sua organization (e.g., Leds, IFES, ...)."*

E, no mesmo dia: *"quando cadastrar uma organization, ela ganha uma URL de login
— `app.theband.dev/<organization>` ou `<organization>.theband.dev` — o que é
melhor?"*. Fato que acompanha a pergunta: **o domínio `theband.dev` existe,
registrado na GoDaddy.**

---

## O que é, em uma frase

Hoje a plataforma tem uma coisa só chamada "organização" — a que a coleta traz do
GitHub — e a instituição que usa a plataforma (Leds, IFES) não existe como
entidade: o tenant faz as vezes dela. O item separa as duas, faz a instituição
nascer com a instalação, liga a ela as N organizações do GitHub que ela conecta,
e abre o caminho para uma segunda instituição entrar sem console.

A medição do colapso — doze lugares, com `file:line` — está na seção "O
problema, medido no código" da [spec](../../specs/059-organizacao-do-tenant/spec.md). O achado que resume: o mapeamento
`priv/knowledge_base/mappings/github/eo/organization.yaml:9-12` declara
`equivalence: partial` e diz que a organização do GitHub *"não representa a
estrutura organizacional real, apenas o recorte visível na ferramenta"* — e o
modelo derivado a promoveu a organização inteira mesmo assim.

---

## Este item é continuação de dois que já existem — e o que muda em cada um

### [Setup inicial e a empresa com endereço próprio](setup-inicial-e-multiempresa.md) — 2026-09-01

Aquele documento decompôs o pedido do wizard em **quatro features**: (1) a empresa
se cria sozinha; (2) a empresa prova que a organização do GitHub é dela; (3) as
pessoas entram com a conta que já têm (049); (4) cada empresa ganha
`<empresa>.theband.dev`.

**O pedido de hoje é continuação das features 1 e 4, e acrescenta o que faltava
antes delas.** O que muda:

| No documento de 2026-09-01 | O que o pedido de hoje muda |
|---|---|
| *"O modelo de uma empresa com várias organizações **já está de pé**"* — porque `connected_tools` tem `tenant_id` e `organization_login` na mesma linha | **Meia verdade.** O esquema suporta N ferramentas por tenant; a **instituição** não existe como entidade em lugar nenhum — nem em `tenants` (que é fronteira de isolamento, não agente social) nem em `eo_organizations` (que só nasce da coleta, `organization.ex:42`). O que está de pé é a cardinalidade; o que falta é um dos dois lados da relação |
| a feature 1 ("a empresa se cria sozinha") era o **wizard** | vira **duas** coisas com ordem: a organização nasce **no boot** da primeira instalação (US1 da 059, sem variável nova), e o **sign up** cria as seguintes (US3). O wizard de conectar organizações continua sendo o `/tools` de hoje, com a relação declarada (US2) |
| a ordem de construção era 049 → App → subdomínio | **o conceito vem antes de tudo**: sem a organização do tenant como entidade, o wizard não tem onde gravar "a empresa", o App não tem a quem provar posse, e o subdomínio não tem o que selecionar. A 059 entra na frente da fila daquele documento, não no fim |
| vocabulário: **"empresa"** | o pedido diz **"organization (e.g., Leds, IFES)"** — IFES não é empresa. A spec usa "organização do tenant"; o `id` na base depende da decisão do modelo (pergunta 4 da spec) |
| pergunta 1 (*uma conta ou várias?*) | permanece aberta e **fica mais concreta**: o sign up com e-mail já usado em outro tenant é recusado, porque `users.email` é único global (migration `20260809120000:36`). É a pergunta 8 da spec |
| o subdomínio como "a feature inteira" da inversão do plug | a spec 059 registra os quatro fatores (sessão, infraestrutura, Phoenix, slugs) e a **recomendação técnica de quem coordena** — subdomínio — como recomendação, com a decisão da pessoa mantenedora em aberto. **Não implementa** a URL: é feature própria, depois da 054 aceita |

**O que continua lá e não vem para cá**: a prova de posse por App do GitHub
(feature 2) e a implementação do endereço (feature 4). A 059 diz que **conectar é
declarar, não provar** — e registra o risco de qualquer tenant declarar qualquer
organização pública como sua até a prova existir.

### [O projeto pertence a uma organização](projeto-pertence-a-organizacao.md) — 2026-09-01

Aquele documento registra a decisão *"a organização tem um ou mais projetos"* e
*"o projeto entre organizações não existe"*, e afirma que a relação
organização → projeto *"não existe — nem na ontologia, nem em `spo_projects`"*.

**Duas coisas a apontar:**

1. **Contradição com o código.** `spo_project_organizations` existe desde a
   migration `20260816210000_project_lifecycle_and_links.exs:28-51` (feature 028),
   com API pública em `lib/the_band/ontology/seon/spo/projects.ex:321`, `:350`,
   `:367`. É vínculo declarado, N-N, com período — e aponta para
   `eo_organizations`, isto é, **para a organização do GitHub**. O documento
   precisa ser reconciliado com isso pelo perfil de Ontologia; a spec 059 registra
   a divergência na tabela de impacto e **não a resolve**.
2. **O pedido de hoje diz qual organização aquele documento quer dizer.** *"O
   projeto entre organizações não existe"* só faz sentido para **instituições**:
   um projeto com repositórios em duas organizações do GitHub da mesma
   instituição é um projeto normal. Com a 059, o alvo daquele elo passa a ser a
   organização do tenant — e o custo que o documento previa (*"o que já foi
   coletado fica sem organização até alguém declarar"*) **diminui**: sob "um
   tenant é uma organização", a organização de todo projeto do tenant é
   derivável sem adivinhar. A pergunta que o documento deixa (*"projeto sem
   organização é recusado ou lacuna declarada?"*) continua, mas para menos
   projetos.

**Ordem**: aquele item **depende** da decisão do modelo (pergunta 4 da 059) e vem
depois dela.

---

## Como se decompõe — e a importância proposta

Prioridade do `spec.md` convertida pela escala da skill (P1 = 100, P2 = 70).
**Proposta deste papel, a confirmar na priorização.**

| User story da 059 | Prioridade | Importância | Depende de | Toca o job de coleta? |
|---|---|---|---|---|
| US1 — a organização nasce com a instalação | P1 | 100 | decisão 2 (1:1 estrito) e 4 (modelo) | **não** — pode andar em paralelo à Verificação 4 da ADR 0007 |
| US2 — conectar organizações do GitHub declara a relação | P1 | 100 | decisão 4; Verificação 4 da ADR 0007 registrada | **sim** — `sync_github_eo.ex:515-531` |
| US3 — sign up: o administrador informa a organização | P2 | 70 | decisão 1 (aberto ou convite) e 7 (prova de identidade); **avaliação do perfil de Security registrada** (FR-016) | não |
| US4 — o dado existente ganha a organização que lhe falta | P2 | 70 | decisão 3 (o tenant atual); Verificação 4 da ADR 0007; ensaio de restauração em dia | não, mas migra o que ele grava |

**A US4 é P2 e ao mesmo tempo pré-requisito do release**: a produção já tem dado.
Não é contradição — a importância mede valor para quem usa; o pré-requisito mede
ordem de embarque.

**Fora deste item** (registrado na spec): a URL por organização, a prova de posse,
a 049, uma conta em vários tenants, o teto de custo por tenant.

---

## As decisões que faltam antes de qualquer sprint

Da spec, as que **bloqueiam** o planejamento — sem elas a US2 e a US4 não têm
critério de aceitação fechado:

| # | Pergunta | Quem decide |
|---|---|---|
| 2 | um tenant é **exatamente uma** organização, e são duas entidades? | pessoa mantenedora |
| 3 | o que é o tenant atual — que observa `The-Band-Solution` **e** `leds-conectafapes`, organizações do GitHub de instituições diferentes? | pessoa mantenedora — **bloqueia o release da US4** |
| 4 | modelo A (organização do GitHub como `eo.organization` subordinada) ou B (como recorte da fonte, fora da EO)? | pessoa mantenedora com o perfil de Ontologia |
| 5 | URL: subdomínio ou caminho? (recomendação técnica registrada: subdomínio) | pessoa mantenedora |

As demais (1, 6, 7, 8, 9, 10) estão na spec e podem esperar o `/speckit-plan`.

---

## O que este item destrava

- [Um servidor MCP para os dados](servidor-mcp.md) — bloqueado em *"autenticação e
  tenant"*; ganha o vocabulário que falta (a organização como entidade, a URL
  como seletor de tenant).
- O wizard do [setup inicial](setup-inicial-e-multiempresa.md) — passa a ter onde
  gravar a instituição.
- O escopo `organization` da spec 045 — passa a poder significar o que o nome diz.

## O que encosta nele agora

- **ADR 0007, Verificação 4** (medida real da coleta completa) — pendente, e é a
  coleta que roda no servidor de desenvolvimento em 2026-09-06. A US2 e a US4
  esperam por ela: mudar `collect_organization` durante a medida invalida a
  medida.
- **Sprint 029** — encerrada em 2026-09-03 com uma pendência de revisão
  independente, bloqueador nomeado. Não há sobreposição de código.
