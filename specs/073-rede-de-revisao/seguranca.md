# Avaliação de segurança da spec 073, antes do plano e do código

**Feature**: `specs/073-rede-de-revisao/spec.md` (épico #1182)
**Data**: 2026-10-03
**Papel**: Security (`AGENTS.md` §13 e §14.0). **Não escrevi este desenho.**
**Natureza**: leitura do diff pretendido (a spec) e da superfície que ela toca, sobre o código de
`development` em `a5901a3`. **Não é varredura completa**, e nenhum gate foi rodado: a instrução
desta avaliação vedou `mix test`/`mix gates` (a base é compartilhada). As afirmações sobre o código
vêm de leitura, cada uma com arquivo e linha.

## Resumo

A spec acerta na postura: ausência nunca é zero (FR-009), nenhum rótulo de papel (FR-018), cálculo
em segundo plano que confere a organização antes de ler (FR-010), alcance com a regra da tela de
pessoas (FR-015). O risco não está na consulta, que o Ecto parametriza e o padrão de `Quality`
já filtra por tenant. Ele está em três lugares que a spec ainda não decidiu:

1. **o cenário 1 da US1 contradiz a FR-015**: nomeia a pessoa que mais revisou sem condição de
   alcance. E a fração de k = 1 é, por construção, uma medida **de uma pessoa**, tenha ela nome na
   tela ou não;
2. **a leitura é materializada sem saber quem vai lê-la**: o alcance só pode ser aplicado na
   leitura, e tudo o que for calculado sobre a rede inteira (concentração, tamanho de grupo,
   contagem do que ficou fora) vaza algo de quem está fora do alcance. A spec manda mostrar
   *"N reviews involve people outside your reach"*, e a decisão registrada de 2026-09-09 para o
   ranking nominal diz o contrário;
3. **é a primeira tela da plataforma que põe um número por pessoa e nomeia o primeiro colocado**.
   A plataforma já recusou isso duas vezes, por escrito (a base e a descrição publicada da
   ferramenta MCP). A FR-018 proíbe o rótulo, e não proíbe o ranking.

| # | Achado | Severidade | OWASP / ASVS |
|---|---|---|---|
| R1 | US1, cenário 1, nomeia quem mais revisou sem condição de alcance; k = 1 é medida individual | **Alta** (no texto da spec) | A01 / V4.2.1 |
| R2 | Agregados sobre a rede inteira vazam quem está fora do alcance: diferença de contagens, grupos pequenos, a contagem do que ficou fora | Média | A01 / V4.2.1, V8.3 |
| R3 | A leitura materializada é anterior a quem lê: o filtro tem de morar na leitura, e o aviso de "pronta" não pode carregar a rede | Média | A01, A04 / V4.1.3, V1.4 |
| R4 | "Organização" é ambígua (tenant × `eo_organizations`): a forma da L19; o job precisa validar o par | Média | A01 / V4.2.1 |
| R5 | Uso como ranking de desempenho: a FR-018 proíbe o rótulo e não o ranking | Média | A04 / V1.1 |
| R6 | Janela e recálculo pedidos pela tela: parâmetro do cliente, fila compartilhada, enfileiramento sem unicidade | Média | A04 / V11.1, V12 |
| R7 | Retenção, nome guardado na leitura, e a pessoa que sai | Média | A04 / V8.3.4, V8.3.8 |
| R8 | API, MCP e modelo de linguagem: a spec é silenciosa, e a descrição publicada da MCP já promete o contrário | Baixa | A01, A04 / V1.4 |
| R9 | Exclusões: nunca listar login; bot tem duas classificações que discordam | Baixa | A01 / V8.3 |
| R10 | Alcance congelado no `mount` | Baixa | A01 / V4.1.3 |
| R11 | `pessoas_alcancadas/2` sem comparação de tenant (#1181, aberto) — a 073 é consumidora nova | Baixa (dependência) | A01 / V4.2.1 |
| R12 | Joins de `Quality` sem tenant nos dois lados e FK simples; `Quality.by_reviewer/2` é um ranking pronto, sem alcance, sem chamador | Baixa | A01, A04 / V4.2.1 |
| R13 | Desenho do grafo: rótulo vindo do GitHub dentro de biblioteca JS | Baixa (preventivo) | A03 / V5.3.3 |
| R14 | Registro: o job não loga par nem nome; o que a função devolve | Informativo | A09 / V7.1 |

---

## Achados

### R1 — Alta: o cenário que o teste vai codificar nomeia quem está fora do alcance

**O que é.** A01. O cenário 1 da US1 diz: *"a tela diz que a pessoa que mais revisou fez 75% das
revisões **e nomeia Ana**"*. Não há condição de alcance. A FR-015 diz que pessoa fora do alcance
não aparece por nome. Quando os dois divergem, quem implementa escreve o teste a partir do cenário,
e o teste com um tenant e uma conta administradora passa nos dois. **A divergência fica invisível
até a primeira conta de alcance parcial abrir a tela.**

E o problema não some tirando o nome. Com k = 1, a fração multiplicada pelo total é a contagem
individual de uma pessoa: *"75% de 40"* é *"alguém fez 30 revisões"*. Se esse alguém está fora do
alcance, a tela entregou uma medida sobre uma pessoa que quem lê não alcança, que é exatamente o
que a decisão de 2026-09-09 recusou.

**Onde.** Na spec (US1, cenário 1; FR-007, quarto item; FR-015). No código, a regra a ser aplicada:
`lib/the_band/tenants/access.ex:325-361` (`pessoas_alcancadas/2`). Ela devolve `{:algumas, MapSet}`
com as pessoas das equipes em escopo **incluindo as equipes derivadas do vínculo** (`:333`, sem
filtro de `origin`). Na prática, uma conta comum alcança os colegas de equipe, e só eles.

**Caminho de exploração.** Não precisa de ataque:

1. Bia é membro da equipe X, sem concessão. Ela alcança a si e aos colegas de X;
2. Ana, da equipe Y, fez 30 das 40 revisões da janela;
3. Bia abre a rede de revisão. Pelo cenário como está escrito, lê *"Ana did 75% of the reviews"*;
4. mesmo sem o nome, lê *"one person did 75%"*. Não é ninguém da lista que ela vê, então é alguém
   de fora, com 30 revisões. Se Bia sabe quem revisa na equipe Y (e o GitHub mostra isso a quem
   tem acesso ao repositório), ela reidentificou.

**Por que Alta.** É a classe do H2 e do H2-R, ambos Alta (`docs/seguranca/2026-09-24-inventario-antes-do-mcp.md:126`):
dado nominal sobre pessoa entregue fora do veredito, dentro do tenant. Aqui o defeito ainda está no
texto, e corrigi-lo agora custa uma frase. **Consequência para o negócio**: *qualquer conta da
organização lê quanto cada pessoa de outra equipe revisa, por nome, e a decisão de 2026-09-09 deixa
de valer nesta tela.*

**O que fecha.** Proposta, com alternativa para o Product Owner:

- **(a), recomendada**: a concentração é **anônima** para todo mundo, administração inclusive.
  A tela diz *"the person who reviewed most did 75%"*, sem nome. **Quem** é se lê na lista por
  pessoa (US2), que já aplica o alcance e que, pela R5, é ordenada por nome. A pergunta da
  necessidade de informação (*está concentrada?*) é respondida inteira, e a tela deixa de ter um
  primeiro colocado nomeado;
- **(b)**: nomeia quem está no alcance; quem está fora aparece como *"a person outside your reach"*.
  Isso fecha o nome, e não fecha a contagem individual do passo 4. Se o Product Owner escolher (b),
  a fração por pessoa fora do alcance passa a ser risco residual aceito, escrito;
- nos dois casos, o cenário 1 da US1 é reescrito com **duas contas** (uma administradora, uma de
  alcance parcial) e o SC-004 ganha a asserção sobre a concentração, e não só sobre a lista.

### R2 — Média: o agregado sobre a rede inteira vaza quem está fora

**O que é.** A01. A leitura é calculada sobre todas as pessoas da organização (R3). O alcance
tira nome e par. O que sobra calculado sobre o todo ainda revela, por diferença:

| O que a tela mostra | O que se infere sobre quem está fora do alcance |
|---|---|
| a linha de uma pessoa alcançável, *"reviewed 12, of 4 people"*, com 3 pares listados | existe 1 pessoa fora do alcance que ela revisou, com peso 12 − (soma dos 3 pares) |
| *"N reviews involve people outside your reach"* | quantas revisões envolvem quem está fora. Com 1 pessoa fora do alcance no par, é uma medida individual |
| *"2 groups that do not review each other: 14 and 1"* | um grupo de tamanho 1 é uma pessoa isolada. Se ela não está na lista, é alguém fora do alcance que ninguém revisa |
| *"N people with no review activity in the window"* (US2, cenário 3) | contagem sobre a organização inteira, incluindo quem quem lê não alcança |
| a janela de 30 contra a de 90, ou a leitura de ontem contra a de hoje | a atividade num intervalo curto: *"o contador de fora subiu 1 e o de Bia subiu 1"* = Bia revisou alguém de fora ontem |

**O precedente contradiz a spec.** `lib/the_band_web/live/verification_live/people.ex:152-153`,
sobre o ranking nominal de quem integrou com verificação vermelha: *"**Não diz quantas linhas
ficaram de fora**, e isso é deliberado: o número seria uma medida sobre pessoas que quem lê não
alcança."* O edge case da 073 manda dizer exatamente esse número. As duas regras não podem valer
juntas sem decisão escrita da pessoa mantenedora.

**Por que Média, e não Alta.** Nenhum nome sai. A reidentificação depende de conhecimento externo
(quem está em qual equipe) e de amostra pequena. Mas o conhecimento externo é barato: o dado de
origem é a revisão do GitHub, que quem tem acesso ao repositório já vê.

**O que fecha.** O plano precisa escolher, e a spec precisa dizer, para cada agregado, **sobre que
população ele é calculado para quem tem alcance parcial**. Proposta:

1. **A linha de uma pessoa alcançável mostra o total verdadeiro dela**. O total é fato sobre ela,
   e duas contas vendo números diferentes com o mesmo rótulo é a L67. Os pares fora do alcance não
   viram linha nem contagem por pessoa: a lista de pares diz só que *"some pairs are outside your
   reach"*, sem número;
2. **a contagem global de revisões fora do alcance não é mostrada**, seguindo o precedente de
   `verification_live/people.ex`. A tela diz que há filtro e qual é a regra, e não quantos;
3. **grupo com menos pessoas que o mínimo declarado na base** (proposta: 3, com a razão escrita) é
   mostrado como *"N small groups"* sem tamanho, para quem não alcança todos os integrantes dele.
   Quem alcança todos vê o tamanho;
4. **pessoa sem aresta não é grupo.** A pessoa que abriu solicitação e ninguém revisou (Caio, US2
   cenário 2) não entra no cálculo de grupos (FR-007, terceiro item). Ela aparece na lista por
   pessoa, se alcançável, e na contagem agregada de *"opened change requests nobody reviewed"*.
   Sem isso, todo grupo de tamanho 1 é uma pessoa apontada;
5. **a contagem de pessoas sem atividade** (US2, cenário 3) é sobre as pessoas alcançáveis, para
   quem tem alcance parcial.

**Risco residual.** A inferência por diferença entre leituras sucessivas sobre pessoas
**alcançáveis** não se fecha sem arredondar, e arredondar quebra o SC-001. Fica aceita: é atividade
de quem quem lê já alcança.

### R3 — Média: a leitura nasce antes de quem lê

**O que é.** A01/A04. A FR-010 calcula por organização, em segundo plano. A leitura materializada
não sabe quem vai abri-la, e portanto contém tudo. Três consequências que a spec precisa dizer:

1. **o alcance só pode ser aplicado na leitura**, por **uma** função de domínio que recebe
   `%Tenant{}` e `%User{}` e devolve a leitura já recortada. A tela nunca recebe a leitura inteira
   para filtrar ela mesma: filtro na tela é a segunda porta, e é como o H2 nasceu (26 telas, o
   veredito em 2);
2. **o aviso de "leitura pronta" não pode carregar a leitura.** O padrão da casa transmite o
   resultado no tópico do tenant: `TheBand.Jobs.RecomputePromotions` faz
   `Mapping.broadcast(tenant_id, {:promotions_recomputed, org_id, resultado})`
   (`lib/the_band/jobs/recompute_promotions.ex:57`). Copiado para cá, toda tela aberta do tenant
   recebe a rede inteira na caixa de mensagens do processo, e um `handle_info` que faça `assign`
   do que recebeu renderiza sem alcance. O aviso leva `{tenant, organização, janela, id da
   leitura}`, e cada tela relê pela função de domínio;
3. **nomes e logins não são gravados na leitura.** Ela guarda `person_id`. O nome se resolve na
   hora de ler, por `EO.people_names/2` (`lib/the_band/ontology/seon/eo/queries.ex:101-107`), que
   filtra por tenant. Isso dá defesa em profundidade (um id de outro tenant nunca vira nome) e
   resolve parte da R7.

**O que fecha.** Emendas à FR-011 e à FR-015 (tabela abaixo), e o contrato em
`specs/073-rede-de-revisao/contracts/` declarando a função de leitura, o que ela devolve para
alcance total e parcial, e **o que ela não expõe**.

### R4 — Média: "organização" é ambígua, e a forma é a da L19

**O que é.** A01. A spec diz *"por organização"* e *"toda leitura é da organização de quem
consulta"*. Nesta base a palavra tem dois sentidos:

- o **tenant**, que é a organização cliente da plataforma;
- a **`eo_organizations`**, a organização observada no GitHub. Um tenant pode ter várias
  (`lib/the_band/ingestion/github_change_requests.ex:134-145`, issue #446), e o job do mesmo tipo
  na casa recebe `organization_id` neste sentido (`recompute_promotions.ex:46`).

Se for o segundo sentido, filtrar só por `tenant_id` mistura as organizações. É a forma exata da
L19 (`docs/sprints/licoes-aprendidas.md:757`): o filtro existe, é o filtro errado, e nada falha. O
caminho de uma solicitação até a organização é `collected_change_requests.observed_repository_id →
observed_repositories.source_repository_id → cmpo_source_repositories.organization_id`
(`priv/repo/migrations/20260811150100_create_cmpo_source_repositories.exs:54`).

**Caminho.** Não é vazamento entre tenants. É mistura dentro do tenant: a rede da organização A
traz pessoas e arestas de B. Para quem tem escopo `organization` só em A, as pessoas de B estão
fora do alcance e caem na R2, como contagens que não deviam estar ali.

**O que fecha.**

- a spec diz qual dos dois sentidos vale, com a palavra certa;
- se for `eo_organizations`: a consulta filtra **cada tabela** pelo tenant e a solicitação pela
  organização através do repositório;
- o job recebe `tenant_id`, `organization_id` e a janela, e **antes de ler**: busca o tenant, confere
  `ensure_active` (`{:cancel, :tenant_inactive}`, como em `recompute_promotions.ex:62`), busca a
  organização **por id e tenant juntos**, e confere a janela contra a lista fechada. Qualquer
  falha é `{:cancel, motivo}` e **nenhuma leitura é gravada**. Leitura gravada com "nenhuma revisão"
  porque a organização não foi achada é fallback silencioso (princípio VIII): a tela diria que não
  houve revisão.

### R5 — Média: a FR-018 proíbe o rótulo, e não o ranking

**O que é.** A04, e o risco que a pessoa mantenedora nomeou: dado sobre pessoa virando julgamento de
desempenho. A spec introduz o primeiro número único por pessoa que é **naturalmente ordenável**
(*"reviewed 12"*) e um primeiro colocado nomeado (R1). A plataforma já recusou isso, por escrito,
em dois lugares:

- `priv/knowledge_base/measurements/flow_per_person_readings.yaml:49` e `:56`: *"um número único por
  pessoa é a figura de produtividade que a plataforma não guarda"* e *"Nenhuma coluna de medida
  ordena a tabela, e nenhuma se oferece para ordenar"*;
- `lib/the_band/mcp/ferramentas.ex:95` e `:105`, na descrição **publicada** das ferramentas MCP:
  *"ordering by them produces a ranking the platform refuses"* e *"Does not answer (…) who reviews
  most"*.

Quem recebe a tela pronta vai ordenar por revisões e ler quem revisa pouco como quem contribui
pouco. A spec precisa impedir o que a tela oferece, e declarar o resto na base (FR-007).

**O que fecha.**

- **FR-018a (nova)**: a lista por pessoa é ordenada por nome; nenhuma coluna de medida ordena a
  lista nem se oferece para ordenar; a concentração não nomeia (R1, alternativa a);
- **FR-018b (nova)**: sem exportação da rede ou da lista por pessoa nesta feature (CSV, cópia,
  impressão dedicada). Exportação é o caminho pelo qual o número sai da tela e chega a uma
  avaliação de desempenho sem as limitações ao lado;
- **auto-revisão é contada só no agregado**, nunca por pessoa (*"Ana se auto-revisou 5 vezes"*
  é acusação, e não medida);
- as **interpretações incorretas** que a FR-007 já exige precisam incluir, no mínimo:
  - revisar muito ou pouco não é produtividade nem qualidade. A carga de revisão depende de
    designação (CODEOWNERS, regra do repositório), de papel, de senioridade, de férias e de fuso;
  - ser revisado por poucas pessoas não diz nada da qualidade do trabalho de quem abriu;
  - uma aprovação sem comentário e uma revisão longa contam igual: o peso é solicitação, não
    esforço;
  - o grupo isolado pode ser um produto separado de propósito, e não um silo;
  - a revisão descartada conta; a feita fora do GitHub (par, chamada) não existe aqui;
  - só os repositórios observados entram. Quem trabalha em repositório não observado aparece como
    quem não revisa;
  - **a medida não pode ser usada para avaliar pessoa**, e a tela diz isso ao lado da lista, e não
    só na base.

**Por que Média.** Não há exploração técnica. Há o uso previsível do produto contra as pessoas que
ele mede, e é a decisão de produto que mais custa desfazer depois da tela publicada.

### R6 — Média: janela e recálculo pedidos pela tela

**O que é.** A04, negação de serviço barata, de dentro do tenant. A spec diz que *"a rede é
recalculada (…) quando alguém pede outra janela"*. Três caminhos:

1. **a janela vem do cliente.** Um `handle_event("janela", %{"dias" => "36500"})` forjado pede um
   século. Se o domínio confiar no valor, o cálculo percorre todas as avaliações do tenant. Pior
   ainda se a janela virar átomo (`String.to_atom/1`);
2. **cada clique enfileira um job.** Sem `unique` sobre `[tenant_id, organization_id, janela]` e
   cobrindo os estados `available`, `scheduled`, `executing` e `retryable`, dez abas e um script de
   eventos enchem a fila. O padrão da casa usa `unique: [period: 30, fields: [:args]]`
   (`recompute_promotions.ex:38`), que só cobre 30 segundos;
3. **a fila `:transformation` é compartilhada** (`config/config.exs:114`, concorrência 5) com o
   recálculo de promoção e o reprocessamento de mapeamentos. Uma enxurrada de redes atrasa o que a
   coleta precisa.

Sobre o custo do cálculo em si: não há índice em `collected_artifact_evaluations` sobre
`(tenant_id, external_submitted_at)` (`priv/repo/migrations/20260819040000_create_artifact_evaluations.exs:75-77`).
O recorte por janela lê todas as avaliações do tenant pelo prefixo do índice único. Na escala da
spec (dezenas a centenas de pessoas) isso cabe, mas **é afirmação, e não medida**.

**O que fecha.** A alternativa mais simples tira o caminho inteiro:

- **o job calcula as três janelas de uma vez**, ao fim da coleta de revisões. A tela só **lê**, e
  trocar de janela não enfileira nada. O custo é calcular duas janelas que talvez ninguém abra; o
  ganho é que nenhuma ação de conta comum gera trabalho em segundo plano;
- se o Product Owner preferir manter o recálculo pela tela: a janela é validada **no domínio**
  contra a lista fechada da base (FR-008), com recusa explícita fora dela; o `unique` cobre os
  estados acima sem período curto; a fila é própria, com concorrência 1, **e configurada**
  (fila declarada e não configurada fica `available` para sempre, `recompute_promotions.ex:7-9`);
- o plano **mede** o cálculo de 180 dias na maior organização em produção antes de declarar que
  cabe, e escreve o número.

### R7 — Média: retenção, nome guardado, e a pessoa que sai

**O que é.** A04, minimização de dado pessoal. A spec diz que a leitura *"é substituída por uma
nova leitura, nunca editada"*. Não diz se a anterior é apagada. Se não for, a plataforma acumula,
a cada coleta, um retrato datado de quem revisa quem: um arquivo longitudinal de relações de
trabalho entre pessoas, que nenhuma necessidade de informação declarada pede. Ele também alimenta
a inferência por diferença da R2.

**A pessoa que sai.**

- a pessoa cujo vínculo terminou continua nó das janelas em que revisou, e isso está certo: o fato
  aconteceu;
- para quem não administra, ela sai do alcance (`pessoas_alcancadas/2` usa os integrantes **de
  agora**, `access.ex:331` e `:347`) e cai na R2. Isso falha fechado;
- se a leitura guarda nome ou login (R3, item 3), o nome sobrevive na leitura mesmo depois de a
  pessoa ser removida de `eo_people`. As avaliações fazem `nilify_all` no `author_person_id`
  (`20260819040000_create_artifact_evaluations.exs:59`), e um JSON não acompanha.

**O que fecha.**

- a leitura guarda só `person_id`, e o nome se resolve na leitura (R3);
- **uma leitura vigente por `(tenant, organização, janela)`**: a nova substitui a anterior **na
  mesma transação**. Se o Product Owner quiser histórico, ele vira FR com retenção declarada, e a
  R2 ganha a linha das leituras antigas;
- a tabela leva `tenant_id NOT NULL` com `on_delete: :delete_all`, e a organização (se for
  `eo_organizations`) com FK composta por `(organization_id, tenant_id)`;
- quem apaga: só o job, ao substituir, e a cascata do tenant. Nenhuma tela apaga ou edita.

### R8 — Baixa: API, MCP e modelo de linguagem

**O que é.** A spec é silenciosa sobre a API pública e o servidor MCP (specs 061/062). O silêncio
tem duas leituras, e uma delas abre a superfície sem avaliação. Hoje:

- não há rota na API nem ferramenta MCP sobre revisor por pessoa (`lib/the_band_web/controllers/api/v1/`,
  `lib/the_band/mcp/ferramentas/`, lidos pela listagem);
- a descrição publicada de `team_review_wait` afirma que a ferramenta *"Does not answer (…) who
  reviews most"* (`ferramentas.ex:105`). Um modelo de linguagem que lê a ferramenta toma isso como
  contrato;
- o gerador de perfis (`lib/the_band/profiles/`) não lê avaliações (busca por `review` sem
  resultado). Se a rede entrar no material do perfil, ela vira texto derivado sobre pessoa, servido
  pela MCP, que é o H2-R.

**O que fecha.** FR-020 nova: a rede **não** é exposta pela API, pela MCP, nem entra no material de
perfil nesta feature. Exposição futura é spec própria, com avaliação, e com a mesma função de
leitura recortada (R3). Não há risco hoje. A emenda existe para que o segundo consumidor não nasça
lendo a tabela.

### R9 — Baixa: as exclusões

**O que é.**

- **login de excluído nunca é listado.** A revisão de *"pessoa não ligada"* é, muitas vezes, de
  uma pessoa real que a plataforma não reconheceu (prestador, conta pessoal). Listar o login
  publicaria identidade fora de qualquer veredito, porque `pessoas_alcancadas/2` só fala de
  `person_id` (é a cláusula do `nil` de `verification_live/people.ex`, que falha fechado de
  propósito). As três exclusões aparecem só como contagem;
- **bot tem duas classificações, e elas discordam.** A avaliação guarda o `__typename` cru
  (`author_type`), e `Quality` trata como humano o que é `"User"` (`lib/the_band/quality.ex:25`).
  A pessoa observada tem `account_type` em `('person','bot','app')`, derivado do `__typename`
  **e** do sufixo `[bot]` do login (`lib/the_band/semantic_integration/mapper.ex:92-101`). Uma
  conta de máquina com `__typename` `User` e login `algo[bot]` passa no filtro de `Quality` e é
  `bot` em EO. O nó da rede precisa exigir **`eo_people.account_type = 'person'`**, e a regra que
  decide precisa estar escrita no mapeamento (FR-005);
- autor nulo (conta apagada no GitHub) chega com `author_type` nulo, e a coleta o conta como bot
  (`github_change_requests.ex:321`). A FR-004 separa bot de não ligada, então o plano precisa dizer
  em qual dos dois motivos ele entra.

### R10 — Baixa: o alcance congelado no `mount`

O padrão das telas que usam o alcance é calculá-lo no `mount` (`verification_live/people.ex:90`).
Se a 073 guardar o conjunto num `assign` e reusá-lo a cada troca de janela, quem perdeu o vínculo
ou a concessão continua vendo nomes enquanto a aba estiver aberta. É a forma da S1 da 072, com
consequência menor (leitura, não ato). O alcance custa três consultas: **recalcular a cada
leitura**, dentro da função de domínio da R3, resolve sem custo relevante.

### R11 — Baixa, dependência: #1181 vem antes

`access.ex:327` concede `:todas` com `User.admin?(user)` sem comparar `user.tenant_id` com
`tenant.id`, ao contrário das outras cláusulas do módulo (`:202`, `:268`, `:401`). É a S10 da 072,
aberta como #1181. Não há caminho de exploração conhecido hoje: os chamadores passam
`current_tenant`, que é `user.tenant`. Mas a 073 é um consumidor **novo** de exatamente esta
função, e `AGENTS.md` §14.0, item 2, põe defeito de segurança conhecido antes de funcionalidade
nova na mesma superfície. O conserto é uma linha e um teste. **Recomendo que a #1181 seja
dependência bloqueante da tarefa que lê a rede com alcance.**

### R12 — Baixa: tenant nos dois lados do join, e um ranking pronto sem chamador

- os joins de `Quality` ligam avaliação a solicitação só por `a.collected_change_request_id == c.id`
  e filtram o tenant **da solicitação** (`quality.ex:74-80`, `:184-190`, `:409-412`). A FK de
  `collected_change_request_id` é simples (`20260819040000_create_artifact_evaluations.exs:44-46`),
  e `Quality.Commands.record_evaluation/2` aceita o id que o chamador mandar sem conferir de que
  tenant ele é (`lib/the_band/quality/commands.ex:12-27`). A coleta passa o id que acabou de gravar
  no mesmo tenant, então **não há vulnerabilidade hoje**: é a defesa morando no chamador. A
  consulta da rede filtra **`a.tenant_id` e `c.tenant_id`** e a pessoa pelo tenant, as três;
- `Quality.by_reviewer/2` (`quality.ex:435-455`) é um ranking de revisores por login, ordenado por
  contagem decrescente, sem alcance, e **sem nenhum chamador em `lib/`**. É o atalho óbvio para
  quem implementar a US2. O contrato da 073 diz que a tela não o usa, e o plano decide se ele é
  removido na mesma feature (ele está na superfície que a feature toca, então não é refatoração
  sem relação).

### R13 — Baixa, preventiva: o desenho do grafo

Se a tela desenhar a rede, os rótulos são nomes e logins vindos do GitHub. HEEx escapa. Uma
biblioteca de grafo em JS que monte rótulo por `innerHTML` reintroduz XSS, e uma biblioteca nova é
dependência nova, que a spec exclui. A CSP (`script-src 'self'`) segura script inline, e não segura
um `innerHTML` dentro de um script permitido. Proposta: sem biblioteca de grafo nesta fatia; se o
protótipo pedir desenho, SVG gerado no servidor em HEEx, e nada de `raw/1`.

### R14 — Informativo: o registro

- o job registra organização, janela, contagens por motivo de exclusão, duração e resultado. **Nunca
  par, nome ou login** (`AGENTS.md` §14.1). Uma linha de log com *"Ana → Bia: 12"* é a rede inteira
  num lugar que não tem alcance nenhum;
- **L69**: a decisão do job (cancelado por tenant inativo, organização não encontrada, janela fora
  da lista) volta como relator no retorno de uma função testável. O log é registro, e não prova;
- a leitura da rede é filtro e não recusa, então não há evento de recusa novo. Se o Product Owner
  quiser saber quem lê relações entre pessoas, é evento de acesso novo, e entra como FR.

---

## Emendas propostas à spec, por FR

| FR | Emenda |
|---|---|
| **US1, cenário 1** | Reescrever com duas contas: *"**Given** (…) 30 delas por Ana, **When** quem administra abre a rede, **Then** a tela diz que a pessoa que mais revisou fez 75% das revisões, **sem nomeá-la**. **And When** uma conta de alcance parcial, que não alcança Ana, abre a mesma tela, **Then** ela não lê o nome de Ana em lugar nenhum da tela."* (R1, alternativa a). Se o Product Owner escolher (b), a contagem individual de quem está fora vira risco residual aceito, escrito. |
| **FR-001** | Acrescentar: *"…pessoa observada **com `account_type` igual a pessoa**. A organização é [tenant / organização observada — decidir], e a consulta filtra cada tabela pelo tenant."* (R4, R9, R12) |
| **FR-004** | Acrescentar: *"As exclusões aparecem só como contagem, nunca com login. A auto-revisão é contada no agregado, nunca por pessoa. A revisão de conta apagada na origem entra no motivo [decidir]."* (R5, R9) |
| **FR-007** | No terceiro item: *"…número de grupos **entre pessoas com ao menos uma aresta**; pessoa sem aresta não é grupo."* No quarto: *"a fração (…) **não identifica quem**."* E as interpretações incorretas listadas na R5 entram como mínimo obrigatório. (R1, R2, R5) |
| **FR-008** | Acrescentar: *"…e o tamanho mínimo de grupo abaixo do qual o tamanho não é mostrado a quem não alcança todos os integrantes, com a razão escrita."* (R2) |
| **FR-010** | *"…conferir, antes de ler qualquer dado: o tenant existe e está ativo; a organização pertence ao tenant, buscada por id e tenant juntos; a janela está na lista fechada da base. Qualquer falha cancela o job **sem gravar leitura**."* (R4) |
| **FR-011** | Acrescentar: *"A leitura guarda identificadores de pessoa, e nunca nome ou login. Existe **uma** leitura vigente por organização e janela; a nova substitui a anterior na mesma transação. O aviso de leitura pronta leva só a identificação da leitura, nunca o conteúdo."* (R3, R7) |
| **FR-013** | *"…entre 30, 90 e 180 dias, **validados no domínio**; valor fora da lista é recusado. As três janelas são calculadas juntas, ao fim da coleta, e trocar de janela na tela **não** enfileira cálculo."* (R6; se o Product Owner preferir o recálculo pela tela, a alternativa da R6 entra no lugar da segunda frase) |
| **FR-015** | Substituir por: *"A leitura que chega à tela é recortada por **uma** função de domínio, com `Tenants.pessoas_alcancadas/2` **recalculado a cada leitura**. Pessoa fora do alcance não aparece por nome, como par, nem na fração de concentração. A linha de pessoa alcançável mostra o total dela, e os pares fora do alcance não viram linha nem número. A tela diz que há recorte e qual é a regra, **sem dizer quantas revisões ficaram de fora** (precedente de `verification_live/people.ex`, 2026-09-09). As contagens de pessoas da organização (sem atividade, tamanho de grupo) são sobre as pessoas alcançáveis, para quem tem alcance parcial."* (R1, R2, R3, R10). O edge case *"Pessoa fora do alcance"* muda junto. |
| **FR-018** | Acrescentar **FR-018a**: *"A lista por pessoa é ordenada por nome. Nenhuma coluna de medida ordena a lista nem se oferece para ordenar. A tela diz, ao lado da lista, que a medida não avalia pessoa."* E **FR-018b**: *"A feature MUST NOT oferecer exportação da rede nem da lista por pessoa."* (R5) |
| **FR-020** (nova) | *"A rede MUST NOT ser exposta pela API pública, pelo servidor MCP, nem entrar no material de geração de perfil nesta feature. Exposição futura exige spec própria e passa pela função de leitura recortada da FR-015."* (R8) |
| **FR-021** (nova) | *"O cálculo registra organização, janela, contagens e duração, e MUST NOT registrar par, nome ou login. O resultado do job volta como relator testável."* (R14) |
| **Dependências** | Acrescentar: *"#1181 (`pessoas_alcancadas/2` compara o tenant) corrigida antes da tarefa que lê a rede com alcance."* (R11) |
| **Assumptions** (*"Quem administra vê todas as pessoas"*) | Acrescentar: *"…do próprio tenant (#1181)."* |
| **SC-004** | Acrescentar: *"…nem na fração de concentração; e a tela de alcance parcial não diz quantas revisões ficaram fora."* |

---

## Cenários de ataque para o QA

Regras herdadas, válidas para todos: dois tenants povoados quando o cenário tocar isolamento; `assert`
de que a medida mediu alguma coisa **antes** de qualquer `refute`; cada guarda vista **reprovando**
com o defeito injetado, com cópia do arquivo antes de injetar. Nenhum segredo real.

| # | Quem, com o quê | Asserção | Defeito a injetar |
|---|---|---|---|
| A1 | Tenants T1 e T2 povoados, com revisões nas mesmas datas. Leitura de T1 | `assert` arestas > 0; `refute` qualquer `person_id` de T2 em nós, arestas e exclusões | tirar `a.tenant_id` **e** `c.tenant_id` do `where` (um de cada vez: os dois testes precisam reprovar) |
| A2 | Avaliação de T2 apontando para solicitação de T1, inserida à mão (a FK simples permite) | a avaliação não entra na rede de T1 | tirar `a.tenant_id` do `where` |
| A3 | Organizações A e B no mesmo tenant (se a decisão da R4 for `eo_organizations`). Leitura de A | `refute` pessoa só de B; contagens batem com A sozinha | filtrar só por tenant (a L19) |
| A4 | Conta de alcance parcial (colega da equipe X); Ana, da equipe Y, é a que mais revisa | `refute` o nome e o login de Ana no HTML; a concentração aparece sem nome | (a) renderizar o nome do primeiro colocado; (b) aplicar o alcance na tela em vez da função de domínio |
| A5 | Pessoa alcançável com 3 pares visíveis e 1 fora do alcance | a linha mostra o total verdadeiro; `refute` o par de fora e qualquer número por par de fora | listar o par com nome mascarado |
| A6 | Rede com um grupo de 1 e um grupo de 2 compostos por pessoas fora do alcance | `refute` os tamanhos 1 e 2 na tela de alcance parcial; `assert` *"small groups"* | tirar o mínimo de grupo |
| A7 | Tela de alcance parcial | `refute` a frase com quantas revisões ficaram fora | renderizar a contagem do edge case original |
| A8 | `handle_event` com janela `"36500"`, `"-1"`, `"90; drop"` e `"abc"` | recusa no domínio; nenhum job enfileirado; nenhum átomo novo | trocar a lista fechada por `String.to_integer/1` |
| A9 | 20 pedidos da mesma janela em sequência (se a alternativa de recálculo pela tela for escolhida) | no máximo um job `available`/`executing` por `(tenant, org, janela)` | `unique` com `period: 30` |
| A10 | Job com `tenant_id` suspenso; com `organization_id` de outro tenant; com organização inexistente | `{:cancel, motivo}` em cada caso, e **nenhuma** leitura gravada (`assert` antes que o caminho feliz grava) | trocar o cancelamento por leitura vazia |
| A11 | Assinante do tópico do tenant durante o cálculo | a mensagem recebida não contém `person_id`, nome, nem aresta | transmitir o resultado, como `recompute_promotions.ex:57` |
| A12 | Duas leituras seguidas da mesma janela | uma só linha vigente; nenhum nome no JSON da leitura | gravar `name` na leitura |
| A13 | Conta perde o vínculo com a equipe X com a tela aberta e troca de janela | os colegas de X somem da lista | guardar o alcance no `mount` |
| A14 | Revisão de conta `account_type = 'bot'` com `author_type = "User"` | não é nó; entra na contagem de bot | filtrar só por `author_type` |
| A15 | Revisão de login não ligado | o login não aparece no HTML; a contagem aparece | listar logins excluídos |
| A16 | `capture_log` em `:debug` durante o cálculo, com nomes óbvios de teste | `refute` nome, login e par no log | logar a aresta |
| A17 | API e MCP: listar rotas e ferramentas | nenhuma rota nem ferramenta devolve aresta ou contagem por revisor | (documental: o teste lê o registro de ferramentas e o roteador, e reprova se surgir) |
| A18 | Conta admin de T1 com `pessoas_alcancadas(T2, admin_T1)` (#1181) | `{:algumas, _}` vazio, e não `:todas` | é o código de hoje: o teste reprova antes da #1181 |

---

## Risco residual, mesmo com as emendas

- **O dado de origem é visível no GitHub** para quem tem acesso aos repositórios. O alcance protege
  a **agregação e o perfilamento** que a plataforma faz, e não o fato de uma revisão ter acontecido.
  A reidentificação por conhecimento externo (R2) não se fecha por completo sem arredondar, e
  arredondar quebra o SC-001;
- **inferência por diferença** entre leituras sucessivas sobre pessoas alcançáveis (R2): aceita,
  porque é atividade de quem quem lê já alcança;
- **colegas de equipe se veem**: pela regra de 2026-09-09, o vínculo vigente dá alcance sobre a
  equipe, e qualquer membro lê as contagens de revisão dos colegas. É a regra decidida, e não
  defeito. A 073 é a primeira tela em que isso significa *"quanto meu colega revisa"*, e o Product
  Owner deveria saber disso ao aprovar o protótipo;
- **uso fora da plataforma**: captura de tela, anotação manual. Nenhum controle técnico impede, e
  as interpretações incorretas na tela são a única defesa;
- **dono das tabelas** (#1131): nada desta feature depende de trigger, mas a leitura vigente única
  (R7) depende da aplicação respeitar a substituição.

## O que eu NÃO verifiquei

- **Nenhum gate e nenhuma ferramenta foi rodada**: `mix sobelow`, `mix hex.audit`, `mix deps.audit`,
  `mix credo`, `mix test`. A instrução vedou. Tudo acima é leitura;
- **o checklist** `specs/073-rede-de-revisao/checklists/requirements.md`: não li;
- **o protótipo**: não existe ainda. As emendas R1, R2, R5 e R13 dependem dele;
- **a spec da 058** e a FR-022/FR-023 dela no texto: usei o que o código e os comentários de
  `access.ex` dizem sobre a regra, e não a spec;
- **`EO.Visibility`** (a liderança declarada): `pessoas_alcancadas/2` não a inclui, e `pode_ver/3`
  inclui. Assumi que a 073 usa a primeira, como a lista de verificação e a API de pessoas. Se a spec
  quiser dizer *"a mesma regra do painel da pessoa"*, é a outra, e a R1/R2 mudam de população;
- **`Mapping.recompute/2` e `EO.fetch_organization`**: não li se conferem que a organização é do
  tenant. A R4 propõe a busca por id e tenant juntos sem afirmar que a de hoje faz ou não faz;
- **o volume real**: quantas avaliações a maior organização em produção tem em 180 dias. A R6 diz
  que cabe por estimativa, e o plano precisa medir;
- **se `eo_people.login` é único por tenant**: `person_ids_by_login/1` faz `Map.new` sobre o par
  (`eo/queries.ex:82-89`), e um login repetido atribuiria revisão à pessoa errada em silêncio. É
  integridade, e não li o índice;
- **a revisão de solicitação cujo autor só foi ligado depois da coleta**: `author_person_id` é
  resolvido na coleta e a solicitação integrada não é percorrida de novo
  (`github_change_requests.ex:48`, `:262`, `:340`). Afeta a contagem de "não ligada", e não a
  segurança; fica para o agente semântico;
- **as outras telas que mostram revisão** (`change_live/show.ex:37`, `teams_live/show.ex`): não
  conferi se `Quality.for_change_request/2` mostra login de revisor fora do alcance. É a mesma
  classe da R2, e fica como pergunta para um inventário próprio, não para a 073;
- **os inventários de `docs/seguranca/`** além do de 2026-09-24, e o conteúdo das issues
  `security` abertas além do título. Pelo título, só a #1181 toca esta superfície.
