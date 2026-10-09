# Avaliação de segurança da spec 076, antes do plano e do código

**Feature**: `specs/076-analise-de-rede/spec.md` (épico #1309, continuação do #1182)
**Data**: 2026-10-03
**Papel**: Security (`AGENTS.md` §13 e §14.0). **Não escrevi este desenho**, nem a revisão semântica,
nem a proposta da base.
**Natureza**: leitura do diff pretendido (a spec, a revisão semântica e `proposta-base/`) e da
superfície que ele toca, sobre o código da branch `feature/1309-analise-de-rede` em `491a9be` (a 073
já mergeada, PR #1228). **Não é varredura completa**, e nenhum gate foi rodado: a instrução desta
avaliação vedou `mix test`, e `mix gates` roda a suíte. Toda afirmação sobre o código vem de
leitura, com arquivo e linha.

**O pedido não é recusar.** A pessoa mantenedora pediu, em 2026-10-03, *"a mesma análise quero
todas"*: os dois grafos com nomes, comunidades com os mais centrais, hubs, distância, mundo pequeno,
papel e perfil individual, e decidiu que **quem está fora do alcance aparece sem nome, agrupado**.
Esta avaliação propõe as mitigações que deixam isso ser entregue, e diz o que continua de risco
depois delas.

## Resumo

A spec faz certo o que a 073 já ensinou: uma função de domínio aplica o alcance (FR-013), o alcance
é recalculado a cada leitura (FR-012), recurso de fora devolve "not found" (FR-014), nenhum id de
fora chega ao navegador (FR-016), cálculo em segundo plano que confere tenant e organização antes de
ler (FR-017), leitura sem nome nem login (FR-018), sem exportação, API nem MCP (FR-053), e registro
sem par (FR-054). A FR-015 **delega a este documento** a forma do agrupado, o tamanho mínimo e o que
hubs, comunidades e perfis mostram no lugar de quem está fora. É a lacuna principal, e é aqui que
ela se fecha.

Três coisas mudam de natureza em relação à 073, e explicam os achados:

1. **a 073 recortava a população; a 076 recorta só o nome.** Na 073, quase tudo era calculado sobre
   o subgrafo das pessoas alcançadas (Q4), e o que sobrava sobre a rede inteira era o total de uma
   pessoa alcançada. Na 076, por decisão (FR-011), **toda medida estrutural é da rede inteira**. O
   que se esconde é o nome; a estrutura de quem está fora continua dentro de cada número;
2. **o agrupado é uma contagem de quem está fora**, que a decisão R2 da 073 (e a de 2026-09-09)
   recusava. A pessoa mantenedora a reverteu, e com razão: sem ela o grafo mente por omissão. Mas
   uma contagem de 1 é uma pessoa, e o agrupado precisa de mínimo, de supressão complementar e de
   uma forma que não deixe o grafo devolver a individualidade pela topologia;
3. **é a primeira tela que classifica pessoa** (papel) e que **ordena pessoas por medida** (hubs).
   A 073 recusou as duas. Elas são agora pedido explícito, e o risco deixa de ser técnico para ser
   de uso: quem vê o rótulo de quem.

| # | Achado | Severidade | OWASP / ASVS |
|---|---|---|---|
| R1 | Hubs e comunidades mostram linha **individual** anônima de quem está fora (US5 cen. 6; US4 cen. 4 sem mínimo) — não é "agrupado", e reidentifica em organização pequena | **Alta** (no texto da spec) | A01 / V4.2.1, V8.3.1 |
| R2 | A forma do agrupado não está decidida; o nó anônimo individual, que é o mais barato de implementar, devolve a pessoa pela topologia e pelo layout | Média | A01, A04 / V4.2.1, V1.4 |
| R3 | As medidas da rede inteira (FR-011), mostradas para quem está no alcance, contam e descrevem quem está fora; conflito com a R2 da 073 e com o aviso de recorte em produção | Média | A01 / V4.2.1, V8.3.1 |
| R4 | Papel e hubs são classificação e ranking de pessoa; colega vê o rótulo de colega pelo vínculo derivado; o papel não deve ser gravado | Média | A04 / V1.1, V8.3.4 |
| R5 | Duas portas possíveis: o perfil por `pode_ver/3`, o grafo por `pessoas_alcancadas/2` — e as duas discordam hoje (#1185) | Média | A01, A04 / V4.1.3, V1.4 |
| R6 | O que chega ao navegador: id, pseudônimo, JSON para o hook, `push_event`, evento de destaque com id arbitrário, SVG | Média | A01, A03 / V5.3.3, V8.2 |
| R7 | Custo: σ e Q contra 100 aleatórios, intermediação, layout — × 2 redes × 3 janelas, a cada sincronização, na fila compartilhada | Média | A04 / V11.1.4, V12 |
| R8 | A conta da organização (D3): marcar uma pessoa real como não-pessoa a esconde da rede inteira | Média | A01, A04 / V4.1.5, V7.1 |
| R9 | Junções novas da rede de designação: quatro FKs simples, sem tenant; o caminho até a organização observada é a forma da L19 | Média | A01 / V4.2.1 |
| R10 | Exceção que carrega a leitura: `Repo.insert!` grava pares `person_id` em `oban_jobs.errors` (já na 073; a 076 acrescentaria papel e medida por pessoa) | Baixa | A09 / V7.1.1, V8.3.4 |
| R11 | Retenção e saída: organização que deixa de ser observada mantém a leitura para sempre; pessoa apagada; backup | Baixa | A04 / V8.3.8 |
| R12 | Exportação, API, MCP: o que impedir concretamente (rota de imagem, `download`, material de perfil) | Baixa | A01, A04 / V1.4 |
| R13 | Entrada pelo endereço: rede, vista, janela, organização, pessoa, e o redirecionamento do endereço antigo | Baixa | A01, A03 / V5.1.3 |
| R14 | Nenhuma dependência nova: o que isso implica (hook co-localizado, `:rand` funcional, nenhum pacote npm) | Informativo | A06 / V10.3 |
| R15 | Registro e telemetria: além da FR-054 | Informativo | A09 / V7.1 |

---

## Achados

### R1 — Alta: o texto da spec põe a pessoa de fora em linha própria

**O que é.** A01. A pessoa mantenedora decidiu *"sem nome, agrupado"*. A spec escreve, em três
lugares, outra coisa:

- **US5, cenário 6**: *"uma pessoa fora do alcance numa posição da lista (…) a linha aparece sem
  nome ('a person outside your reach')"*. É uma linha por pessoa, com **posição e valor**: *"o
  segundo maior em intermediação, 0,41, é alguém fora do seu alcance"*. Não é agrupado: é anônimo;
- **US4, cenário 4**: *"and N people outside your reach"* por comunidade, **sem mínimo**. Com N = 1,
  a comunidade diz que existe uma pessoa de fora nela, e o tamanho e as arestas internas da
  comunidade (FR-028) dizem quanto ela se liga;
- **US8, cenário 4** diz só que a pessoa de fora *"não aparece com papel por nome"* — o que deixa
  aberto mostrá-la com papel sem nome.

**Caminho.** Não precisa de ataque:

1. Bia é membro da equipe X, sem concessão: alcança a si e aos colegas de X
   (`lib/the_band/tenants/access.ex:327-364`);
2. a organização tem 14 pessoas na rede de designação; 9 estão fora do alcance de Bia;
3. Bia abre os hubs de intermediação e lê, na primeira linha, *"a person outside your reach — 0,58"*;
4. ela sabe, pelo GitHub e pelo dia a dia, quem distribui trabalho entre as equipes. Em 14 pessoas,
   "a ponte da rede que não é do meu time" tem um nome. A tela entregou uma **medida individual, com
   posição num ranking, sobre uma pessoa que Bia não alcança** — a classe que a decisão de
   2026-09-09 recusou (`lib/the_band_web/live/verification_live/people.ex:152-153`) e que a 073
   classificou como Alta (R1 de `specs/073-rede-de-revisao/seguranca.md`).

**Por que Alta.** É dado sobre pessoa entregue fora do veredito, dentro do tenant, numa
classificação comparativa — a classe do H2 e do H2-R (`docs/seguranca/2026-09-24-inventario-antes-do-mcp.md`).
O defeito ainda está no texto, e corrigi-lo custa três frases; depois de virar teste, o teste com
uma conta administradora passa nos dois desenhos e a divergência fica invisível. **Consequência para
o negócio**: *qualquer conta da organização lê a posição no ranking, e o valor, de quem não é da
equipe dela, e numa organização de dezenas de pessoas isso é ler o nome.*

**O que fecha** (a FR-015 delega a decisão a este documento):

- **hubs, com alcance parcial**: a lista é das **pessoas alcançadas**, ordenada pela medida da rede
  inteira, sem o número da posição na rede inteira, com o título *"Among the people you reach"* e a
  frase *"People outside your reach are not ranked here."* — sem contagem. Nenhuma linha de pessoa
  de fora, com ou sem valor. Com `:todas`, a lista é a da rede inteira, como na referência;
- **papel**: só de pessoa alcançada; nenhuma contagem de papel entre as de fora (*"2 people outside
  your reach are Central position"* é o mesmo ranking por outro caminho);
- **comunidade**: os de fora aparecem pela regra do agrupado (R2), com o mínimo k;
- **"os três mais centrais"** de cada comunidade são escolhidos **entre os alcançados** da comunidade,
  pelo grau interno da rede inteira, e a tela diz *"among the members you reach"*.

### R2 — Média: a forma do agrupado decide se a pessoa volta pela topologia

**O que é.** A01/A04. A FR-015 não diz o que é o agrupado no grafo. As formas possíveis:

| Forma | O que revela de quem está fora | Leitura |
|---|---|---|
| (i) **nó anônimo por pessoa**, sem nome | a topologia inteira: "o nó sem nome ligado aos meus 3 colegas com peso 20" é a pessoa | **recusar**: não é agrupado, e é a forma mais barata de implementar — é a que vai aparecer se ninguém disser outra |
| (ii) **um nó agregado só**, "People outside your reach" | quantas pessoas de fora, e as arestas de cada alcançado com o conjunto | fecha a topologia, mas apaga as comunidades: a vista de comunidades (FR-021) perde a cor de quem está fora, e a pergunta *"quais grupos se formam e quem os liga?"* (SC-006) deixa de ter resposta |
| (iii) **um nó agregado por comunidade**, com mínimo k e agrupamento do resto | quantas pessoas de fora em cada comunidade com ao menos k delas, e o peso entre alcançados e cada grupo | **recomendada**: preserva a leitura de comunidades, e nenhum número fala de menos de k pessoas |

**A regra proposta, (iii), inteira:**

1. **k = 3**, declarado na base (`network.analysis.parameters`, regra nova `outside_reach`), com a
   razão: com 1 o agregado é uma pessoa; com 2, cada uma das duas é identificável por quem conhece a
   outra, e o grupo vira um par; 3 é o menor grupo em que nenhum número isola alguém sem
   conhecimento externo sobre duas pessoas. Estatística oficial costuma usar 5, mas aqui as redes têm
   dezenas de pessoas e as comunidades, poucas: 5 suprimiria quase todo agregado, e o grafo perderia
   o que a pessoa mantenedora pediu. O valor é revisável com dado;
2. **um nó por comunidade** para as pessoas de fora daquela comunidade, **quando forem ≥ k**. Rótulo
   *"People outside your reach — community 2 (4)"*. Forma visual distinta (borda tracejada,
   preenchimento hachurado: é derivado e agregado, `docs/design-system.md`), tamanho fixo (grau de
   um agregado não é grau de ninguém), sem cor de intermediação;
3. as pessoas de fora das comunidades com **menos de k** delas entram num **nó único** *"People
   outside your reach, other communities (N)"*, **se N ≥ k**;
4. se nem esse junta k, **não há nó**: cada pessoa alcançada ligada a alguém de fora ganha uma marca
   *"has links outside your reach"* (o `pairs_outside_reach?` da 073,
   `lib/the_band/review_network/slice.ex:119-121`), sem aresta, sem peso, sem número. Um nó agregado
   de 1 ou 2 pessoas ligado a Ana **e** a Bia diria que a mesma pessoa de fora se liga às duas, o que
   os totais individuais não dizem;
5. **arestas** entre alcançado e agregado somam os pesos, por sentido; entre dois agregados, uma
   aresta com a soma; **dentro** de um agregado, nada (nem laço, nem contagem);
6. **supressão complementar**: onde um número visível menos os nomes listados devolveria uma contagem
   de fora menor que k (o tamanho da comunidade, as arestas internas dela, o número de pessoas de um
   componente), o número **não aparece** para quem tem alcance parcial; a tela diz *"size not shown:
   it would count fewer than 3 people outside your reach"*;
7. **comunidade sem ninguém alcançado** não tem bloco próprio na lista: os membros dela entram no
   agregado (2) ou (3). O **número** de comunidades é medida da rede (FR-029) e aparece inteiro, porque
   conta grupos e não pessoas; o que não aparece é o bloco dela com tamanho, arestas e membros;
8. **a mesma regra em toda vista**: grafo ponderado, grafo de comunidades e a lista do telefone
   (FR-025) mostram os mesmos agregados com os mesmos números. Três regras para três vistas são três
   chances de uma delas vazar.

**O layout também fala.** Fruchterman–Reingold sobre a rede inteira (proposta-base, `layout`)
posiciona cada alcançado puxado pelos vizinhos de fora. Desenhar os alcançados nas posições da rede
inteira e o agregado no centroide dos seus membros entregaria, em coordenadas, onde estão as pessoas
de fora. **Proposta**: com `:todas`, as posições gravadas da rede inteira; com alcance parcial, o
layout é **recalculado na leitura sobre o grafo da visão** (alcançados + agregados), com a mesma
semente e a mesma ordem. É determinístico por (leitura, alcance) — a FR-052 vale por visão —, e
custa 50 iterações sobre dezenas de nós (R7 mede).

### R3 — Média: a rede inteira dentro de cada número

**O que é.** A01. A FR-011 calcula tudo sobre a rede inteira, e isso é correto para a medida (a
intermediação de uma pessoa só existe sobre a rede). Mas cada medida de pessoa **alcançada** carrega
informação sobre quem está fora:

| O que a tela mostra de Bia (alcançada) | O que se infere sobre quem está fora |
|---|---|
| *"assigns to 4 people"* (FR-048), com 3 pares nomeados | existe 1 pessoa de fora a quem Bia designa, e o peso dela é o total menos a soma dos 3 |
| proximidade com *"reaches 22 people"* (FR-035), e 9 nomes visíveis no componente | 13 pessoas de fora no componente de Bia |
| intermediação alta e nenhum caminho visível passando por ela | Bia é ponte entre grupos de fora |
| *"14 people in the network"*, 5 nomes | 9 pessoas de fora, mesmo se nenhum agregado tiver k |
| grau normalizado (FR-033) e grau bruto | n, pelo quociente |
| as três janelas, e as duas redes | a atividade de fora num intervalo curto, por diferença |

**O conflito escrito.** A R2 da 073 foi decidida em 2026-10-03: *"a tela não conta as revisões que
envolvem pessoas fora do alcance"*. A 076 a reverte **parcialmente** (Decisões revertidas), e o aviso
de recorte que está no ar diz *"the page does not say how much is outside it"*
(`lib/the_band_web/live/review_network_live/show.ex:181-189`). Na área nova, com os agregados, essa
frase fica falsa. Se a primeira página da área continua sendo a rede da 073 com as regras da 073
(FR-004, US1), a mesma conta lê, na mesma área, uma página que não conta quem está fora e outra que
conta. Duas regras na mesma área precisam ser ditas, ou uma delas mente.

**Por que Média.** Nenhum nome sai. A inferência pede conhecimento externo, que é barato aqui (a
issue e a revisão são visíveis no GitHub a quem tem acesso ao repositório), e o efeito é estrutural,
não individual — **exceto** quando a diferença dá 1, que é o caso da primeira linha da tabela.

**O que fecha.**

- **o total de uma pessoa alcançada é o total dela**, como na 073 (R2, item 1; L67: duas contas vendo
  números diferentes com o mesmo rótulo). A diferença contra os pares nomeados é risco residual
  **herdado** da 073, e passa a ser escrito: *"com uma só pessoa de fora entre os pares, o peso
  dela se deduz"*. A alternativa que fecha (separar *"with people you reach"* de *"in total"* e
  esconder o total quando os pares de fora forem menos que k) é a **DS3**;
- **n e o tamanho dos componentes** seguem a regra k (R2, item 6): com alcance parcial, *"14 people
  in the network"* só aparece se as de fora forem ≥ k; senão, *"measures are computed over the
  whole network of the organisation"*, sem n;
- **grau normalizado** não aparece com alcance parcial (o bruto, em pessoas distintas, é o que a
  FR-033 pede; o normalizado é derivado e devolve n);
- **as medidas da rede** (distância média, diâmetro, eficiência, clustering, σ, Q, número de
  comunidades) aparecem para todos: são de rede, e a contribuição de uma pessoa nelas é diluída. Com
  menos de 10 pessoas, σ e papel já são ausentes (proposta-base). Risco residual escrito;
- **o aviso de recorte da área** diz as duas coisas, com as palavras certas: *"Names appear only for
  the people you reach. Measures are computed over the whole network. People outside your reach
  appear grouped, without names, and only in groups of at least 3."* E a página da rede de revisão
  da 073, dentro da área, mantém o aviso dela — a FR-003 e a US1 continuam sem contar quem está fora
  ali, e o aviso da área não é colado em cima dele.

### R4 — Média: papel e ranking de pessoa, e quem lê o rótulo de quem

**O que é.** A04. O risco que a pessoa mantenedora nomeou para a 073 — dado de pessoa virando
julgamento de desempenho — passa a ter rótulo e ordem. A proposta-base já faz muito: rótulos
posicionais e não de mérito (S6 da revisão semântica), `confidence: low`, mínimo de 10 pessoas,
percentil por posto médio, interpretações incorretas escritas. O que falta é **quem lê**:

- pelo alcance de hoje, **colega vê colega** sem concessão nenhuma: o vínculo vigente dá escopo de
  equipe derivado (`access.ex:333-350`, sem filtro de `origin`). Na 073 isso significava *"quanto meu
  colega revisa"*, e foi aceito como risco residual. Na 076 significa **ler o rótulo do colega**:
  *"Few links, few paths"* sobre a pessoa da mesa ao lado, numa tela da plataforma;
- a spec diz *"quem coordena"* em todas as histórias, e nenhuma FR restringe a quem coordena;
- **o papel gravado** vira atributo persistido de pessoa, o que a própria regra diz que ele não é
  (*"o papel é atributo da pessoa"* está em `misinterpretations` de `network_position_role.yaml`).

**O que fecha.**

- **o papel não é gravado**. A leitura guarda grau e intermediação por pessoa (FR-018); o percentil e
  o papel derivam-se **na leitura**, pela regra vigente. Custa uma ordenação de n números; ganha que
  nenhum rótulo de pessoa existe no banco, e que mudar um corte da regra muda a tela sem recalcular;
- **a própria pessoa vê o próprio perfil e o próprio papel sempre** (a decisão de 2026-09-09: *"a
  pessoa vê o seu perfil"*), inclusive sem escopo nenhum;
- **a frase que acompanha o papel e os hubs** está na tela, ao lado, e não só na base: *"Position in
  this network and window. It does not measure performance, importance or merit, and must not be
  used to evaluate a person."* (a última oração é a da 073, R5);
- **quem lê o papel e os hubs com nome de outra pessoa** é a **DS1**: a spec diz *"todos que alcançam"*;
  a recomendação é restringir a quem tem escopo **concedido** (equipe ou organização, `origin` não
  derivado) e à administração, e deixar quem só tem o vínculo com o próprio papel e as medidas sem
  rótulo dos colegas.

### R5 — Média: uma área, uma porta

**O que é.** A01/A04. A FR-012 diz *"pela mesma regra da tela de pessoas"* e a FR-014 diz *"not
found"* para quem está fora. Hoje há **duas** regras, e elas discordam:

- `pessoas_alcancadas/2` (`access.ex:327`) — equipes em escopo, equipes das organizações em escopo, a
  própria pessoa. **Sem** a liderança declarada;
- `pode_ver/3` (`access.ex:236`) — a mesma união **mais** a liderança declarada (`EO.Visibility`,
  `:284`).

A issue #1185 (aberta, `security`) é exatamente isto, achado da 073. Se o perfil (US9) usar
`pode_ver/3`, que é o veredito natural de "abrir uma pessoa", e o grafo usar `pessoas_alcancadas/2`,
quem lidera por papel declarado abre o perfil de Caio pelo endereço e vê Caio **sem nome** no grafo
e nos hubs. Pior na direção contrária: o perfil mostra *"assigns to Ana (4)"*, com Ana alcançada pelo
perfil e não pelo grafo. **A segunda porta é como o H2 nasceu.**

**O que fecha.**

- **uma função de alcance para a área inteira**: `Tenants.pessoas_alcancadas/2`, chamada uma vez por
  leitura, dentro da função de domínio (FR-013). O perfil é aberto se, e só se, a pessoa está **nesse
  conjunto** (ou é a própria). `pode_ver/3` **não** é chamado em nenhum ponto da área;
- **"not found" igual** para pessoa de outro tenant, inexistente, fora do alcance, sem pessoa ligada,
  e id que não é UUID (`Ecto.UUID.cast/1` antes da consulta, como `EO.fetch_organization/2` faz,
  `lib/the_band/ontology/seon/eo/queries.ex:786-794`); o mesmo vale para pessoa alcançada **que não
  é nó** da rede: *"no edges in this network in this window"* só para quem a alcança (US9, cen. 4),
  porque dizer "sem arestas" a quem não alcança confirma que a pessoa existe;
- **#1185 antes da tarefa do alcance** (já está nas Dependências). Qualquer das duas saídas serve à
  076, desde que a área use uma só função. A recomendação está na **DS4**.

### R6 — Média: o que chega ao navegador

**O que é.** A01/A03. A FR-016 diz o princípio. Os caminhos concretos pelos quais ele quebra, nesta
stack:

1. **atributos do markup**: a 073 põe o `person_id` em `id`, `phx-value-id` e `aria-controls`
   (`show.ex:418-426`). Para alcançado, é aceito (a URL do perfil já o contém). Para agregado, o id é
   **opaco e por renderização** (`outside-1`, `outside-2`), **nunca** derivado do `person_id` — nem
   hash. Um hash do UUID é um pseudônimo estável: a mesma pessoa de fora teria o mesmo identificador
   nas duas redes e nas três janelas, e poderia ser seguida entre elas;
2. **o hook de zoom e destaque**: a forma mais comum de escrever um grafo interativo é mandar os nós
   como JSON num `data-graph={Jason.encode!(...)}` ou num `push_event/3`. Isso põe no navegador o que
   o hook recebe, inteiro — e é tentador passar a leitura inteira e "filtrar no JS". **O hook não
   recebe dado nenhum**: o servidor renderiza o SVG completo; o hook só aplica `transform` (zoom,
   arrasto) e alterna classes já presentes no markup;
3. **o destaque**: o `handle_event("toggle", %{"id" => person_id})` da 073 aceita qualquer texto e o
   guarda num `MapSet` sem limite (`show.ex:55-63`). Inofensivo lá (só compara), mas copiado para a
   076 vira um oráculo se o servidor responder diferente para id de fora. **Proposta**: destaque no
   cliente por `Phoenix.LiveView.JS` (`JS.add_class`/`JS.remove_class` sobre ids já renderizados),
   sem ida ao servidor; se houver evento, o id é conferido contra os nós da visão e o desconhecido é
   ignorado sem resposta distinta;
4. **o estado do LiveView**: só o que é renderizado vai ao cliente, mas o `assign` é o que um
   descuido renderiza. A tela recebe e guarda **a visão já recortada**, nunca a leitura inteira (como
   a 073 faz, `show.ex:76-84`);
5. **o SVG** (R13 da 073): nome em `<text>` e `<title>` pelo escape do HEEx, nunca `raw/1`; nenhum
   `<foreignObject>` (HTML dentro do SVG); `href` só por `~p` e só para o perfil de alcançado; cor
   da paleta fixa do servidor, nunca texto vindo do dado; atributo `style` só com número formatado
   no servidor (a CSP aceita `style-src 'unsafe-inline'`, `lib/the_band_web/router.ex:16`, e por isso
   o `style` com dado é o lugar onde a injeção entraria). SVG **inline** no HEEx, nunca `<img
   src="data:...">` montado de string.

### R7 — Média: o custo, por organização, a cada sincronização

**O que é.** A04, negação de serviço de dentro, sem atacante: a carga cresce com a organização e
com a frequência da coleta. Por organização e a cada sincronização (a 073 enfileira ao fim da coleta,
`lib/the_band/jobs/sync_github_eo.ex:373`, e a sincronização roda a cada 15 minutos, conforme o
`moduledoc` de `compute_review_network.ex`):

| Cálculo | Custo por rede e janela | Vezes |
|---|---|---|
| intermediação (Brandes) | O(n·m) | 1 |
| distâncias, proximidade, eficiência | n buscas em largura, O(n·(n+m)) | 1 |
| σ: clustering e distâncias de 100 G(n, m) | 100 × O(n·(n+m)) | 100 |
| **Q_rand**: a partição gulosa sobre cada aleatório (`modularity_reading.compare_with_random`) | o guloso de CNM, O(n²) ingênuo ou pior em Elixir | **100** |
| layout | 50 × O(n²) | 1 |

Vezes **2 redes × 3 janelas = 6** por organização, por sincronização. O termo que domina é o Q_rand:
600 execuções do algoritmo de comunidades por organização a cada 15 minutos, numa fila
(`:transformation`, concorrência 5, `config/config.exs:119`) que a coleta e o recálculo de promoções
também usam. Nada disto foi medido: a proposta-base o diz (`provenance.note`), e o volume real é a
#1190.

**O que fecha.**

- **fila própria, configurada, concorrência 1** (`network_analysis: 1`). Fila declarada e não
  configurada fica `available` para sempre (`recompute_promotions.ex:7-9`);
- **unicidade** por `(tenant, organização)` em `:incomplete`, período infinito, como a 073
  (`compute_review_network.ex:36-43`); as duas redes no mesmo job;
- **não recalcular o que não mudou**: a leitura grava uma impressão digital das arestas de entrada
  (hash das arestas ordenadas, por rede e janela); se for igual à vigente, o job não recalcula σ, Q e
  layout. Na maior parte das sincronizações nada mudou;
- **teto de tamanho** declarado na base (n e m máximos), medido pela #1190: acima dele, σ, Q_rand e
  layout ficam **ausentes com motivo** `network_too_large_for_platform`, e não rodam até o fim;
- **tempo máximo** do job (`timeout/1` do worker) com cancelamento, e a tela diz que a leitura não
  está disponível e por quê (o edge case *"Cálculo falhou"* da spec);
- **nada na leitura da tela dispara cálculo** (decisão R6 da 073, que continua). O único cálculo por
  leitura é o layout da visão parcial (R2), sobre dezenas de nós; o plano mede e escreve o número;
- **zoom e arrasto no cliente**: um evento por movimento de roda ao servidor seria carga sem razão.

### R8 — Média: a conta da organização, e o esconderijo

**O que é.** A01/A04. A revisão semântica (S8, D3) propõe que a conta de usuário usada pela
organização (o caso `LEDS`) seja reconhecida **por declaração**, e recomenda (a): quem administra
marca na tela de pessoas. Uma conta marcada **deixa de ser nó** (FR-006, FR-007). Isso é, também,
uma ferramenta para **tirar uma pessoa real de toda a análise**: quem marca a conta de Caio como
"da organização" faz Caio sumir dos grafos, dos hubs, das comunidades e do papel, e muda a medida de
todo mundo que se ligava a ele. Com alcance parcial, as contagens de exclusão não aparecem (decisão
Q5 da 073), então ninguém além da administração percebe.

**O que fecha**, para a opção (a) da D3:

- **só a administração do tenant marca** (`User.admin?` e `user.tenant_id == tenant.id`, como em
  `access.ex:269`), e a marca é **relator**: quem marcou, quando, e o motivo escrito — o mesmo desenho
  de `lib/the_band/tenants/access/scope_grant.ex`. Revogável, nunca apagada;
- **a marca não mora em `eo_people.account_type`**: aquela coluna é derivada da origem
  (`lib/the_band/semantic_integration/mapper.ex:92-101`) e a coleta seguinte a reescreveria, desfazendo
  a declaração em silêncio. Tabela própria, `tenant_id NOT NULL`, FK composta com a pessoa;
- **recusa** marcar uma pessoa que tenha **elo vigente com uma conta da plataforma** (`Tenants.person_of_user`):
  quem entra na plataforma é pessoa. Recusa também a pessoa ligada à própria conta de quem marca;
- **visível**: a tela de pessoas, para a administração, lista as contas declaradas com quem declarou;
  a área de análise diz a todos que *"accounts declared by administrators as organisation accounts
  are not people in this network"*, com o número de contas declaradas **na organização** (é número
  de contas, não de designações, e não diz quais);
- **registro**: marcar e revogar emitem evento com tenant, conta que agiu, id da pessoa marcada e o
  resultado — é ato de administração sobre a visibilidade de uma pessoa, e é o que se procura depois;
- a marca vale para as **duas** redes e para a 073? A spec só fala da designação (FR-007). Se valer
  para a revisão, muda a 073: é pergunta para o plano, com a mesma guarda.

### R9 — Média: as junções da rede de designação

**O que é.** A01. A rede de revisão já tem a consulta pronta e conferida (R12 da 073). A de
designação é **consulta nova**, sobre tabelas cujas FKs não carregam o tenant:

| Coluna | FK | Arquivo |
|---|---|---|
| `issue_assignees.collected_issue_id` | simples | `priv/repo/migrations/20260811180100_create_issue_assignees_and_labels.exs:33-35` |
| `issue_assignees.person_id` | simples, `nilify_all` | idem, `:38` |
| `collected_issues.author_person_id` | simples, `nilify_all` | `priv/repo/migrations/20260811180000_add_issue_details.exs:34` |
| `collected_issues.observed_repository_id` | simples | `priv/repo/migrations/20260811150300_create_collected_issues.exs:42-46` |

Nenhuma é vulnerabilidade hoje: a coleta grava ids do mesmo tenant. É a **defesa no chamador**, e
as consultas existentes de `person_work.ex` filtram, várias vezes, só `i.tenant_id`
(`lib/the_band/work_items/person_work.ex:140-158`, `:374-379`, `:442-448`), confiando no join. E há a
L19: *"organização"* aqui é a observada (decisão R4 da 073), e o caminho da issue até ela é
`collected_issues → observed_repositories → cmpo_source_repositories.organization_id`. Filtrar só
pelo tenant mistura as organizações do mesmo tenant, sem erro.

**O que fecha** (emenda à FR-009):

- **cada tabela** da junção pelo tenant: `i.tenant_id`, `a.tenant_id`, o autor `p_autor.tenant_id`, o
  responsável `p_resp.tenant_id`, `observed_repositories.tenant_id`, `cmpo_source_repositories.tenant_id`
  — seis, e o teste injeta cada uma removida (A1);
- a organização pelo repositório, com `excluded_at` nulo como na 073 (`commands.ex:85-88`);
- **responsável vigente** é `a.no_longer_observed_at IS NULL`
  (`20260812140000_mark_assignees_and_labels_instead_of_deleting.exs`); o tratamento da issue que
  deixou de ser observada é do agente semântico, mas precisa estar escrito;
- **tipos de conta** por `EO.account_types/2`, que filtra pelo tenant (como a 073), e nunca pelo
  `login` cru das duas tabelas (`author_login`, `issue_assignees.login`): o login **não** é lido pela
  consulta da rede, e por isso não tem como chegar à tela nem ao log.

### R10 — Baixa: a exceção que carrega a leitura

**O que é.** A09. Na 073, `substituir/3` insere com `Repo.insert!`
(`lib/the_band/review_network/commands.ex:172`), e o changeset declara `foreign_key_constraint` e
`check_constraint` (`lib/the_band/review_network/schemas/reading.ex:66-75`). Quando uma constraint
declarada no changeset falha, `Repo.insert!` levanta `Ecto.InvalidChangesetError`, cuja mensagem
inclui **"Applied changes"** e **"Params"** inteiros (`deps/ecto/lib/ecto/exceptions.ex:92-107`) — ou
seja, a lista de arestas, cada uma um par de `person_id`. O caminho realista é a corrida: a
organização é apagada entre a busca do job e a inserção. O Oban grava a mensagem formatada em
`oban_jobs.errors`, que o `Pruner` mantém por 7 dias (`config/config.exs:121`). Não é log (não há
`Oban.Telemetry.attach_default_logger` no projeto), mas é o par inteiro num lugar sem alcance, que
a FR-021 da 073 e a FR-054 da 076 querem fora de qualquer registro.

Na 076 a leitura levaria grau, intermediação e posição por pessoa, e o mesmo caminho as copiaria.

**O que fecha.** `Repo.insert/1` (sem `!`) e, no erro, rollback com **só os nomes dos campos** e da
constraint: `{:error, {:reading_rejected, [:organization_id]}}`. Nenhum `{:ok, _} = ` sobre termo
que contenha a leitura (o `MatchError` imprime o termo). O conserto na 073 é de uma linha, e está na
mesma superfície (`AGENTS.md` §14.0, item 2): recomendo que vá junto da primeira tarefa da 076 que
toca `Commands`.

### R11 — Baixa: retenção, saída e o que fica

- **uma leitura vigente** por `(tenant, organização, rede, janela)`, substituída na mesma transação
  (FR-018, que já diz isso). A unicidade da 073 é `[:tenant_id, :organization_id, :window_days]`
  (`priv/repo/migrations/20261003150000_create_review_network_readings.exs:60`); com a rede, a chave
  ganha `network`, e o `delete_all` de `substituir/3` passa a apagar por rede, senão o cálculo da
  designação apaga a leitura da revisão;
- **a organização que deixa de ser observada**: a leitura só some por cascata se a linha de
  `eo_organizations` for apagada (`:37-43`, `on_delete: :delete_all`). Se a organização só deixa de
  ser coletada, nenhum cálculo novo roda, e a última leitura — com medidas por pessoa — fica para
  sempre. **Proposta**: ao encerrar a observação, as leituras da organização são apagadas; e a tela
  não mostra leitura cujo `computed_at` seja mais velho que a maior janela (180 dias), dizendo por quê;
- **a pessoa apagada** de `eo_people`: a leitura guarda o id sem FK. A 073 tira da visão quem não tem
  nome (`lib/the_band/review_network/reader.ex:96-117`). Na 076, para `:todas`, o nó sem nome entra
  no agregado como *"no longer in the platform"*, sob a mesma regra k, e nunca com id; o cálculo
  seguinte o remove;
- **a pessoa desligada** (vínculo encerrado) continua nó das janelas em que agiu — o fato aconteceu —
  e sai do alcance de quem não administra: falha fechado;
- **backup**: a leitura substituída continua nas cópias até a retenção delas. É o tema da 064
  (#885), e fica como risco residual.

### R12 — Baixa: exportação, API e MCP, concretamente

A FR-053 está certa e precisa de dentes. O que impedir:

- **nenhuma rota** da área responde com `image/svg+xml`, `image/png`, GEXF, CSV, JSON ou HTML
  isolado; a área só tem rotas `live`;
- **nenhum** botão, `download`, `Content-Disposition`, *"copy as image"*, nem folha de estilo de
  impressão dedicada ao grafo. O navegador continua salvando a página e tirando captura de tela; a
  FR proíbe a plataforma de **oferecer**, e não pode impedir o usuário — risco residual;
- **nenhum** módulo de `lib/the_band/mcp/`, `lib/the_band_web/controllers/api/` ou
  `lib/the_band/profiles/` (o material de geração de perfil e o `prompt.ex`) referencia o módulo da
  análise ou a tabela de leituras. Hoje nenhum referencia a 073 (conferido por busca textual);
- **guarda em teste** (A17), que lê o roteador, o registro de ferramentas MCP e os módulos de perfil
  e reprova se aparecer referência. Exposição futura é spec própria, pela mesma função recortada.

### R13 — Baixa: entrada pelo endereço

A FR-002 põe organização, rede e janela no endereço; a US3 e a US4 sugerem vista (ponderada ou
comunidades) e a US9 a pessoa. Cada um é entrada externa:

- **rede, vista e janela**: listas fechadas da base, comparadas como texto exato
  (`reader.ex:66-79` é o modelo: `"090"`, `"90; drop"`, `"36500"` recusados), **nunca**
  `String.to_atom/1` nem `String.to_existing_atom/1` sobre o parâmetro. Valor fora da lista volta ao
  padrão sem dizer que era inválido, como a 073;
- **organização**: `EO.fetch_organization/2` (cast de UUID, id e tenant juntos, `queries.ex:786-794`);
- **pessoa do perfil**: R5;
- **o endereço antigo** (FR-003): o redirecionamento monta o destino com `~p` a partir do id já
  validado e da janela da lista. Nada do parâmetro original é colado na URL de destino (não há
  redirecionamento aberto, e não se carrega `?return_to=`);
- `janela/1` da 073 faz `String.to_integer/1` sobre o texto (`show.ex:96-97`) **depois** de a função
  de domínio ter validado, então não levanta; na 076 a validação continua antes de qualquer conversão.

### R14 — Informativo: nenhuma dependência nova

Confirmado como desenho. O que isso implica, e o que o plano confere:

- `mix.exs` e `mix.lock` **não mudam**; `mix hex.audit` e `mix deps.audit` ficam como estão;
- `assets/package.json` não ganha pacote; o zoom e o destaque são **hook co-localizado** (já há
  `phoenix-colocated` em `assets/js/app.js:25`) ou `Phoenix.LiveView.JS`. Código no repositório,
  servido de `'self'`: a CSP não muda;
- **todo algoritmo é escrito à mão**. O risco é de correção (SC-002 o guarda), não de segurança —
  com uma exceção: um laço sem teto (autovetor, CNM, Fruchterman–Reingold) é negação de serviço; os
  tetos estão na proposta-base (`max_iterations: 1000`, `iterations: 50`), e a R7 acrescenta o de
  tamanho;
- **o gerador**: `:rand` com **estado explícito** (`:rand.seed_s/2` e `:rand.uniform_s/1`), e não o
  estado no dicionário do processo — no dicionário, qualquer outra chamada a `:rand` no mesmo
  processo muda a sequência, e a FR-052 cai em silêncio. Não é gerador criptográfico, e não precisa
  ser: não protege segredo;
- `:digraph`, se usado, cria tabelas ETS ligadas ao processo; no job elas morrem com ele, numa tela
  não.

### R15 — Informativo: registro e telemetria

A FR-054 está certa. Acrescentar:

- **nenhum valor por pessoa**, nem com `person_id` sem nome: grau, intermediação, papel, comunidade
  de alguém. *"person_id=… role=few_links_few_paths"* num log é o papel gravado onde não há alcance;
- **o relator do job** (L69): o retorno de uma função testável diz cancelado/calculado/pulado por
  impressão digital igual/ausente por tamanho, só com contagens. O log sai dele, como na 073
  (`compute_review_network.ex:63-74`);
- **a telemetria da 074** (OpenTelemetry/SigNoz, #1238 em diante) passa pelo exportador que só deixa
  sair o permitido (#1243): a leitura, os pares e as medidas não são atributo de span;
- **marcar e revogar conta da organização** é evento (R8);
- **ler a análise não é evento novo**: é filtro, não recusa. Se a pessoa mantenedora quiser saber
  quem lê os papéis, é FR nova, com o registro sem conteúdo.

---

## Emendas propostas à spec, por FR

**Incorporável sem decisão** = decorre de requisito ou decisão já escrita, ou a FR-015 delegou a este
documento. **Depende da pessoa mantenedora** = muda o que ela pediu, ou escolhe entre opções que só
ela pode escolher (seção final).

| FR | Emenda | Origem | Marca |
|---|---|---|---|
| **FR-009** | Acrescentar: *"…cada tabela da junção — issue, responsável, autor, responsável como pessoa, repositório observado, repositório de origem — filtrada pelo tenant; a organização observada pelo repositório, sem repositório excluído; responsável vigente é o não marcado como deixado de observar; o tipo de conta vem de EO, nunca do login."* | R9 | incorporável sem decisão |
| **FR-011** | Acrescentar: *"Com alcance parcial, o número de pessoas da rede, o tamanho de componente e o grau normalizado seguem a regra do mínimo da FR-015."* | R3 | incorporável sem decisão |
| **FR-012 / FR-013** | Acrescentar: *"A área inteira usa uma só função de alcance, `pessoas_alcancadas/2`, chamada dentro da função de domínio a cada leitura. O perfil é aberto se, e só se, a pessoa está nesse conjunto ou é a de quem consulta; `pode_ver/3` não decide nada nesta área."* | R5 | incorporável sem decisão (a #1185 é a DS4, e não muda esta regra) |
| **FR-014** | *"…'not found', igual para pessoa de outro tenant, inexistente, fora do alcance, e identificador que não é UUID. 'Sem arestas nesta rede' só para pessoa alcançada."* | R5, R13 | incorporável sem decisão |
| **FR-015** | Substituir por: *"Com alcance parcial: (1) o mínimo é k = 3 pessoas, declarado na base com a razão; (2) no grafo, as pessoas de fora de cada comunidade são um nó agregado quando forem ≥ k; as de comunidades com menos de k juntam-se num nó 'other communities' se juntarem ≥ k; senão não há nó, e cada pessoa alcançada ligada a alguém de fora leva a marca 'has links outside your reach', sem aresta nem número; (3) nenhum nó anônimo individual; (4) número que, subtraído dos nomes visíveis, contaria menos de k pessoas de fora não aparece; (5) hubs: só pessoas alcançadas, ordenadas pela medida da rede inteira, sem a posição na rede inteira e sem linha de pessoa de fora; (6) comunidades: membros alcançados por nome, os três mais centrais entre os alcançados, os de fora pela regra (2) e (4); (7) papel: só de pessoa alcançada, e nenhuma contagem de papel entre os de fora; (8) perfil: pares de fora só agregados, pela FR-049. A mesma regra vale no grafo ponderado, no de comunidades e na lista do telefone."* | R1, R2 | incorporável sem decisão (delegado pela própria FR-015); o valor de k pode ser revisto na DS2 |
| **US3 cen. 5, US4 cen. 4, US5 cen. 6, US8 cen. 4** | Reescrever pela nova FR-015, cada um com **duas contas** (administração e alcance parcial) e com o caso de 1 e 2 pessoas de fora. US5 cen. 6 passa a: *"…a lista mostra só as pessoas que quem consulta alcança, e diz que as de fora não são ordenadas aqui, sem dizer quantas."* | R1 | incorporável sem decisão |
| **FR-016** | Acrescentar: *"…nem pseudônimo derivado do identificador (hash). Nó agregado tem identificador opaco por renderização. O hook do grafo não recebe dado: o servidor renderiza o SVG, e o hook só aplica transformação e classe. Nenhum `push_event` leva nó, aresta ou medida. A tela guarda só a visão já recortada. Destaque por comando de cliente; evento com identificador, se houver, é conferido contra os nós da visão."* | R6 | incorporável sem decisão |
| **FR-017** | Acrescentar: *"…em fila própria, configurada, com concorrência 1; um cálculo pendente por tenant e organização; as duas redes no mesmo job; com tempo máximo e cancelamento. A rede de entrada tem impressão digital: igual à vigente, σ, Q e layout não são recalculados. Acima do tamanho máximo da base (medido pela #1190), σ, Q contra aleatórios e layout são ausentes com motivo."* | R7 | incorporável sem decisão (o valor do teto sai do plano, com a medida) |
| **FR-018** | Acrescentar: *"O percentil e o papel não são gravados: derivam-se na leitura. A chave da leitura vigente inclui a rede, e a substituição apaga só a da mesma rede. A gravação não usa operação que levante com o conteúdo da leitura na mensagem. Ao encerrar a observação da organização, as leituras dela são apagadas; leitura mais velha que a maior janela não é mostrada."* | R4, R10, R11 | incorporável sem decisão |
| **FR-022** | Acrescentar: *"Com alcance parcial, as posições são recalculadas na leitura sobre o grafo da visão (alcançados e agregados), com a mesma semente e ordem; as posições da rede inteira só aparecem para quem alcança todos."* | R2 | incorporável sem decisão |
| **FR-023** | Acrescentar: *"…sem pacote novo em `assets/`; o zoom e o arrasto acontecem no cliente, sem evento ao servidor."* | R6, R7, R14 | incorporável sem decisão |
| **FR-024** | Acrescentar: *"Nenhum `raw/1`, nenhum `foreignObject`; `href` só para o perfil de pessoa alcançada; cor da paleta do servidor; atributo `style` só com número formatado no servidor; SVG inline no markup."* | R6 | incorporável sem decisão |
| **FR-028** | *"…os três mais centrais **entre os membros alcançados**, pelo grau interno da rede inteira, com a frase 'among the members you reach'; tamanho e arestas internas pela regra (4) da FR-015."* | R1, R2 | incorporável sem decisão |
| **FR-033** | Acrescentar: *"O grau normalizado não aparece com alcance parcial."* | R3 | incorporável sem decisão |
| **FR-044 a FR-047** | Acrescentar: *"A própria pessoa vê o próprio papel sempre. Ao lado do papel e dos hubs, na tela: 'Position in this network and window. It does not measure performance, importance or merit, and must not be used to evaluate a person.'"* | R4 | incorporável sem decisão |
| **FR-044 a FR-048** (quem lê o papel e os hubs de outra pessoa) | *"O papel e os hubs com nome de outra pessoa aparecem para [todos que a alcançam / quem tem escopo concedido e a administração / só a administração]."* | R4 | **depende da pessoa mantenedora** (DS1) |
| **FR-048 / FR-049** | Manter o total verdadeiro da pessoa alcançada, ou separar *"with people you reach"* de *"in total"*, escondendo o total quando os pares de fora forem menos que k | R3 | **depende da pessoa mantenedora** (DS3) |
| **FR-053** | Acrescentar: *"…nenhuma rota da área além de `live`; nenhum botão, atributo `download` nem folha de impressão dedicada; nenhum módulo da API, do MCP ou do material de perfil referencia a análise, com teste que reprova se surgir."* | R12 | incorporável sem decisão |
| **FR-054** | Acrescentar: *"…nem `person_id` com medida, comunidade ou papel. O resultado do job volta como relator testável, e o registro sai dele. A leitura não é atributo de telemetria."* | R15 | incorporável sem decisão |
| **FR-002 / FR-003** | Acrescentar: *"Rede, vista e janela são listas fechadas, comparadas como texto exato, nunca convertidas em átomo; valor fora volta ao padrão. O endereço antigo redireciona com destino montado do id já validado."* | R13 | incorporável sem decisão |
| **FR-007** (conta da organização) | *"A conta da organização é declarada por [opção da D3]. Se pela administração: só administração do tenant; relator com quem, quando e motivo; revogável; fora de `account_type`; recusada para pessoa com elo vigente com conta da plataforma; a área diz a todos quantas contas estão declaradas na organização, sem dizer quais; marcar e revogar emitem evento."* | R8 | **depende da pessoa mantenedora** (D3 da revisão semântica; as guardas são incorporáveis se ela escolher (a)) |
| **FR nova (conta sem alcance)** | *"Conta cujo alcance é vazio, ou só ela própria, vê as medidas da rede e o próprio perfil, e não vê grafo, comunidades nem hubs."* | R2, R4 | **depende da pessoa mantenedora** (DS5) |
| **Aviso de recorte da área** (US1, novo cenário) | *"Names appear only for the people you reach. Measures are computed over the whole network. People outside your reach appear grouped, without names, and only in groups of at least 3."* A página da rede de revisão da 073, dentro da área, mantém o aviso dela. | R3 | incorporável sem decisão |
| **SC-004** | Acrescentar: *"…nem pseudônimo, nem em JSON entregue a hook, nem em `push_event`; nenhum agregado de menos de 3 pessoas aparece; nenhuma linha de hub é de pessoa de fora — verificado com uma organização em que 1, 2 e 3 pessoas de fora pertencem à mesma comunidade."* | R1, R2, R6 | incorporável sem decisão |
| **Dependências** | Acrescentar: *"O conserto de `Repo.insert!` em `ReviewNetwork.Commands` (R10) antes ou junto da primeira tarefa que toca o cálculo."* | R10 | incorporável sem decisão |

---

## Cenários de ataque para o QA

Regras herdadas, para todos: dois tenants povoados quando tocar isolamento; `assert` de que a medida
mediu alguma coisa **antes** de qualquer `refute`; cada guarda vista **reprovando** com o defeito
injetado, copiando o arquivo antes de injetar e conferindo a restauração. Nenhum segredo real; nomes
óbvios de teste.

| # | Quem, com o quê | Asserção | Defeito a injetar |
|---|---|---|---|
| A1 | T1 e T2 com issues e responsáveis nas mesmas datas; linhas de `issue_assignees` de T2 apontando, à mão, para issue de T1 (as FKs simples permitem) | `assert` arestas > 0; `refute` qualquer pessoa de T2 em nós, agregados e contagens | tirar o filtro de tenant de **cada** uma das seis tabelas, uma por vez: seis reprovações |
| A2 | Organizações A e B no mesmo tenant; leitura de A | `refute` pessoa e issue só de B; contagens batem com A sozinha | filtrar só pelo tenant (L19) |
| A3 | Conta de alcance parcial; a pessoa de maior intermediação está fora | `refute` linha de pessoa de fora na lista de hubs, com ou sem valor; `assert` a frase *"not ranked here"*; `refute` qualquer número de posição na rede inteira | renderizar a lista da rede inteira com *"a person outside your reach"* (o texto atual da US5 cen. 6) |
| A4 | Comunidade com 1, com 2 e com 3 pessoas de fora | 1 e 2: nenhum nó próprio, nenhum tamanho de comunidade nem arestas internas; 3: nó *"(3)"* | tirar o k; mostrar o tamanho da comunidade mesmo suprimido |
| A5 | Rede em que, juntando todas as comunidades, só 2 pessoas estão fora | nenhum nó agregado; as pessoas alcançadas ligadas a elas levam só a marca; `refute` *"(2)"* e `refute` aresta com peso para fora | criar o nó "other communities" sem conferir k |
| A6 | HTML e diff do LiveView da conta parcial | `refute` todo `person_id` de fora em atributo, texto, `data-*`, `phx-value-*`; `refute` hash SHA/MD5 de cada um; ids de agregado diferentes entre duas renderizações de leituras diferentes | gerar o id do agregado por hash do `person_id` |
| A7 | Hook do grafo | o markup não tem `data-*` com JSON de nós; nenhum `push_event` na área carrega nó, aresta ou medida (`assert_push_event` negado) | passar a leitura num `data-graph` |
| A8 | Evento de destaque forjado com `person_id` de fora, com UUID aleatório e com 10 000 ids | a resposta é igual nos três; o estado não cresce sem limite | aceitar o id e responder com as arestas dele |
| A9 | Nome de pessoa `<script>alert(1)</script>` e `"><foreignObject>` (fixture, não origem real) | o SVG tem o texto escapado em `<text>` e `<title>`; nenhum elemento novo | `raw/1` no rótulo |
| A10 | Perfil pelo endereço: pessoa de outro tenant, inexistente, fora do alcance, `abc`, pessoa alcançada sem aresta | as quatro primeiras dão exatamente o mesmo "not found"; a quinta diz *"no edges"* | usar `pode_ver/3` no perfil e `pessoas_alcancadas/2` no grafo, com uma liderança declarada na fixture: o perfil abre e o nó está sem nome — o teste reprova pela divergência |
| A11 | Conta só com vínculo de equipe (escopo derivado), lendo colega | conforme a DS1: o papel do colega aparece ou não; o próprio papel aparece sempre | (depende da DS1) |
| A12 | `?network=assignmentx`, `?view=../../`, `?window=36500`, `?window=90;drop`, `?network=` com 10 000 caracteres | volta ao padrão; nenhum átomo novo (`:erlang.system_info(:atom_count)` antes e depois) | `String.to_atom/1` no parâmetro |
| A13 | Endereço antigo com `?window=90&return_to=https://exemplo.invalid` | o destino é um caminho da área, sem o parâmetro | colar a query original no destino |
| A14 | Job com tenant suspenso; organização de outro tenant; inexistente; `network` fora da lista nos args | `{:cancel, motivo}` em cada um, e nenhuma leitura gravada (`assert` antes que o caminho feliz grava) | trocar o cancelamento por leitura vazia |
| A15 | Duas sincronizações com as mesmas arestas | a segunda não recalcula σ, Q nem layout (o relator diz *"pulado"*) | ignorar a impressão digital |
| A16 | Rede acima do teto da base | σ, Q_rand e layout ausentes com motivo, em tempo limitado | tirar o teto |
| A17 | Roteador, registro de ferramentas MCP, módulos de API e de perfil | nenhuma referência à análise nem à tabela de leituras; nenhuma rota da área além de `live` | (documental: o teste lê os módulos e reprova se surgir) |
| A18 | Organização apagada entre a busca do job e a inserção | o erro gravado no job não contém nenhum `person_id` | `Repo.insert!` (o código de hoje: o teste reprova antes do conserto da R10) |
| A19 | `capture_log` em `:debug` durante o cálculo | `refute` `person_id`, nome, login, papel e medida por pessoa no log | logar a medida de cada pessoa |
| A20 | Administração marca a conta de uma pessoa com elo vigente como "da organização"; conta de membro tenta marcar; a coleta seguinte roda | recusa no primeiro; recusa no segundo; a marca válida sobrevive à coleta; o evento existe com quem marcou | gravar a marca em `account_type`; aceitar de membro |
| A21 | Leitura da designação calculada depois da de revisão | a de revisão continua vigente | `delete_all` por organização, sem a rede |
| A22 | Alcance perde a equipe com a tela aberta; troca de rede | os nomes da equipe somem na leitura seguinte | guardar o alcance no `mount` (R10 da 073) |

---

## Risco residual, mesmo com as emendas

- **A inferência por diferença sobre pessoa alcançada** (R3, primeira linha): com uma só pessoa de fora
  entre os pares de Bia, o peso daquele par se deduz do total. Herdado da 073 e agora escrito. Fecha
  só com a DS3;
- **as medidas da rede inteira carregam quem está fora**: a intermediação alta de um alcançado sem
  caminho visível, o *"reaches 22"* da proximidade, a cor da comunidade. É a FR-011, decidida, e é o
  preço de a medida ser verdadeira;
- **diferença entre janelas e entre redes**: um agregado de 4 em 90 dias e de 3 em 30 dias diz algo
  sobre a atividade recente de fora. O k vale por janela, e não fecha a diferença;
- **colegas se veem**, e na 076 se veem com papel e posição, se a DS1 ficar em (a);
- **reidentificação por conhecimento externo**: a issue, o responsável e a revisão são visíveis no
  GitHub a quem tem acesso aos repositórios. O alcance protege a **agregação e a classificação** que
  a plataforma faz, e não o fato;
- **captura de tela e "salvar como"**: a FR-053 impede a plataforma de oferecer, não o navegador de
  guardar. As frases ao lado do papel e dos hubs são a única defesa de uso;
- **a conta da organização** declarada pela administração continua sendo poder de esconder alguém. As
  guardas da R8 o tornam visível e registrado, não impossível;
- **backup** guarda a leitura substituída até a retenção dele (064);
- **organizações muito pequenas**: abaixo de 10 pessoas, σ e papel já são ausentes; com alcance
  parcial e poucas pessoas de fora, o k suprime quase todo agregado, e a tela de quem tem alcance
  parcial fica parecida com a da 073. É o comportamento certo, e o protótipo precisa mostrá-lo.

## O que eu NÃO verifiquei

- **Nenhum gate e nenhuma ferramenta foi rodada**: `mix gates`, `mix sobelow`, `mix hex.audit`,
  `mix deps.audit`, `mix credo`, `mix test`. A instrução vedou a suíte. Tudo acima é leitura;
- **o checklist** `specs/076-analise-de-rede/checklists/` e os 20 YAMLs de medida da proposta-base,
  um a um: li as três regras (`network_analysis_parameters.yaml`, `network_position_role.yaml`) e a
  lista de arquivos; as medidas, não;
- **os contratos da 073** (`contracts/tela.md`, `review-network.md`, `job.md`): li o código que os
  implementa, e não o texto;
- **o protótipo** da 076: não existe. R1, R2, R3 e R6 dependem dele, e o agente `design` precisa
  receber a regra da FR-015 emendada antes de desenhar;
- **se o crash de um LiveView registra o estado do socket**: `Phoenix.LiveView.Socket` deriva
  `Inspect` com `:assigns` (`deps/phoenix_live_view/lib/phoenix_live_view/socket.ex:48-59`), e não
  conferi se o tradutor do `Logger` inclui o estado no relatório de término. Por isso a R6, item 4,
  pede que o `assign` só tenha a visão recortada — que é o que a 073 já faz;
- **se a coleta reescreve `eo_people.account_type`** a cada passada: deduzi do `Mapper`, sem ler o
  upsert. A R8 recomenda tabela própria de qualquer forma;
- **o que acontece com a organização que deixa de ser observada** (se a linha de `eo_organizations`
  é apagada, marcada ou mantida): não li. A R11 propõe apagar as leituras ao encerrar a observação
  sem afirmar o que acontece hoje;
- **issue coletada por quadro de projeto** (`observed_projects`) de repositório de outra organização
  observada: não conferi se o caminho issue → repositório → organização a põe na organização certa
  em todos os casos;
- **o papel de operador da plataforma** (070, #1058): não conferi se uma conta de operador alcança a
  área. A regra da 070 é que o operador não lê dado de organização, e a área nova é dado de
  organização;
- **o volume** (#1190): o custo da R7 é estimativa de complexidade, e não medida;
- **o inventário mais recente de `docs/seguranca/`** além do de 2026-09-24, e as issues `security`
  abertas além do título. Pelo título, só a #1185 toca esta superfície (a #1181, citada na 073, está
  **fechada**, e o código de `access.ex:330` já compara o tenant).

---

## Decisões da pessoa mantenedora

Recomendação é recomendação: a decisão é dela, e a escolha volta para a `spec.md` com data.

| # | Pergunta | Opções | Recomendação |
|---|---|---|---|
| **DS1** | Quem lê o **papel** e os **hubs** com o nome de **outra** pessoa? (R4) | (a) todos que a alcançam, inclusive colega pelo vínculo de equipe — o que a spec diz; (b) quem tem escopo **concedido** (equipe ou organização, não derivado) e a administração; quem só tem o vínculo vê o próprio papel e as medidas sem rótulo dos colegas; (c) só a administração | **(b)**. As histórias falam de *"quem coordena"*; o vínculo derivado é o colega. O rótulo de posição sobre a pessoa da mesa ao lado, numa tela da plataforma, é o uso que a 073 recusou, e (b) entrega a análise inteira a quem coordena. Custa uma variante de `pessoas_alcancadas/2` com o filtro de `origin`, **no módulo de acesso**, e não na tela |
| **DS2** | O mínimo do agrupado (R2) | k = 3; k = 5 | **3**, com a razão escrita na base. 5 é comum em estatística oficial, mas suprimiria quase todo agregado em redes de dezenas de pessoas, e o grafo deixaria de mostrar o que foi pedido. Já está na emenda à FR-015; só muda se ela quiser 5 |
| **DS3** | O total de uma pessoa alcançada (R3) | (a) o total verdadeiro, como na 073; a diferença contra os pares nomeados fica risco residual aceito, escrito; (b) *"with people you reach"* sempre, e *"in total"* só quando os pares de fora forem ≥ k | **(a)**, por coerência com a 073 (L67) e porque o fato revelado é sobretudo sobre a pessoa alcançada. Se ela escolher (a), a linha entra no risco residual com a data |
| **DS4** | A #1185: a frase × o recorte | (a) corrigir a frase para a regra de `pessoas_alcancadas/2`; (b) incluir a liderança declarada em `pessoas_alcancadas/2` | **(a)** agora. (b) muda o alcance de toda tela que usa a função (verificação, 073, API de pessoas) e merece avaliação própria. Para a 076, as duas servem: a regra é **uma função para a área** (emenda à FR-012), e a decisão vem antes da tarefa do alcance |
| **DS5** | Conta sem alcance (vazio, ou só ela própria) | (a) vê tudo agregado, inclusive a estrutura de comunidades da organização inteira em nós anônimos; (b) vê as medidas da rede e o próprio perfil, sem grafo, comunidades nem hubs | **(b)**. Em (a), uma conta que não alcança ninguém lê a estrutura de grupos de toda a organização, sem nenhum nome que a ancore e sem decisão que ela possa tomar com isso |
| **D3** (revisão semântica) | Como a conta da organização é reconhecida (R8) | (a) a administração marca, na tela de pessoas; (b) lista de logins na base; (c) não reconhecer | **(a)**, **com as guardas da R8**: só administração, relator com quem, quando e motivo, fora de `account_type`, recusa para pessoa com elo vigente, número de contas declaradas visível a todos, evento ao marcar e ao revogar. E dizer se a marca vale também para a rede de revisão da 073 |

**Não dependem dela**, e entram na spec pelas emendas: a forma do agrupado (nó por comunidade, R2),
os hubs só entre alcançados (R1), o layout recalculado na visão parcial, o que chega ao navegador
(R6), o custo (R7), as junções (R9), a exceção (R10), a retenção (R11), a exportação (R12) e a
entrada (R13). A FR-015 delegou as quatro primeiras a este documento, e as demais decorrem de
requisitos já escritos.
