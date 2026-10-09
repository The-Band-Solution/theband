# Feature Specification: Análise de rede

**Feature Branch**: `feature/1309-analise-de-rede`

**Created**: 2026-10-03

**Status**: Draft

**Épico**: [#1309](https://github.com/The-Band-Solution/theband/issues/1309), continuação de [#1182](https://github.com/The-Band-Solution/theband/issues/1182) (073 — Rede de revisão)

**Input**: pedido da pessoa mantenedora em 2026-10-03: *"eu quero ver os grafos da mesma forma que existe no codigo que foi passado e coloque a analise de rede em outro menu"*; *"quero a identificacao das comunidades, dos hubs ... a mesma analise quero todas"*. A referência é o repositório `leds-conectafapes-management-dashboard` (`dashboard_team_graph.py` e `report/collaboration_report.md`).

## Contexto

A 073 entregou a rede de revisão como **primeira fatia** das redes complexas: contagens, concentração sem nomear, grupos que não se revisam. Ela recusou, por decisão registrada, o desenho do grafo, os rankings, os rótulos de papel, o índice de mundo pequeno e as comunidades.

Em 2026-10-03 a pessoa mantenedora pediu a análise **completa**, igual à da referência, numa área própria do menu. Esta spec:

1. **reverte** decisões da 073 e de outras specs, com data e quem decidiu (seção *Decisões revertidas*);
2. traz da referência **toda a análise** — os dois grafos, comunidades, hubs, distância, mundo pequeno, papel e perfil individual —, sobre **duas** redes: a de revisão (073) e a de designação (autor da issue → responsável), que é a aresta da referência;
3. **não** repete os defeitos de cálculo da referência, conferidos no código (seção *O que não se repete da referência*).

A aresta da referência **não é colaboração**. Quem abriu uma issue e quem foi designado para ela estão ligados por um item de trabalho; o ato de designar é de quem designou, que nem sempre é o autor. A revisão semântica ([revisao-semantica.md](revisao-semantica.md)) declara o que ela é e o que não é. Nenhum texto desta feature a chama de colaboração.

## Decisões revertidas

Decididas pela pessoa mantenedora em **2026-10-03**, no pedido desta feature e nas respostas às perguntas de esclarecimento do mesmo dia. Cada linha diz o que valia, o que passa a valer, e onde a decisão anterior está escrita, para que ninguém leia a 073 e conclua o contrário.

| Onde | O que valia | O que passa a valer |
|---|---|---|
| 073, Q1 da aprovação do protótipo | nenhum desenho da rede nesta fatia | os dois grafos da referência, interativos (FR-020 a FR-026) |
| 073, FR-018 | sem rótulo de papel e sem classificar pessoa por faixa | o papel de cada pessoa na rede, com os limiares declarados na base e a razão escrita (FR-044 a FR-047) |
| 073, FR-018a | lista por pessoa ordenada por nome; nenhuma coluna de medida ordena | listas de hubs ordenadas pela medida (FR-034); a lista geral de pessoas continua por nome |
| 073, FR-019 | sem índice de mundo pequeno e sem comunidades | comunidades (FR-027 a FR-031) e mundo pequeno (FR-040 a FR-043) |
| 073, `proposta-base/README.md` §2 | recusadas: intermediação, proximidade, autovetor, distância média, diâmetro, eficiência global, clustering, σ, "membros mais centrais", "papel na rede", rankings top-5 | todas adotadas, cada uma corrigida do defeito que motivou a recusa ([proposta-base/](proposta-base/)) |
| `review.network.parameters`, `refuses` (segunda entrada) | recusa de classificar pessoas em papéis por percentil | a recusa é retirada; o papel passa a ser a regra `network.position_role`, com os cortes e a razão de cada um |
| 073, R2 da avaliação de segurança | a tela de alcance parcial não diz quantas revisões ficaram fora | quem está fora do alcance aparece **sem nome, agrupado**; o tamanho do agrupamento passa por [seguranca.md](seguranca.md) |
| 046, barra principal | a barra carrega só as entidades (People, Teams, Projects, Organization) | a barra ganha uma área de análise, **Network analysis** (FR-001) |

**Continuam valendo** da 073: a aresta de revisão (`review.network.edge`); ausência com motivo, nunca zero; sem exportação (FR-018b); sem API, sem MCP e sem material de perfil (FR-020); o registro sem par, nome ou login (FR-021); uma leitura vigente por organização e janela (FR-011); as janelas 30, 90 e 180 (FR-013).

## O que não se repete da referência

São defeitos conferidos em `dashboard_team_graph.py`. Cada um tem requisito que o impede.

| Defeito, com o lugar | O que esta feature faz | Onde |
|---|---|---|
| σ soma só os grafos aleatórios conexos e divide sempre por 10 (`:192-204`) | todo grafo aleatório gerado entra, e a média divide pelo número que entrou | FR-041 |
| σ sem semente (`:197`) | semente fixa, declarada na base, gravada na proveniência; mesmo dado dá o mesmo σ | FR-041, FR-052 |
| 0,01 para nó isolado e a centralidade de grau como reserva do autovetor (`:110-117`) | autovetor que não converge é **ausente com motivo**; nó sem aresta não é nó | FR-036, FR-008 |
| "desconexo, contendo 1 componentes" (`:277-282`): testa conexidade forte e conta componentes fracos | um critério só, declarado (fraco), e a frase diz o número certo | FR-019 |
| 1/c como "alcança outros em N passos" em grafo desconexo (`:318`) | a distância média de uma pessoa é calculada direto, sobre quem ela alcança, e dita junto de quantos alcança | FR-035 |
| distância média como média simples das médias por componente (`:139-149`) | média sobre todos os pares que se alcançam, dita junto da fração de pares que se alcançam | FR-037 |
| faixas sem razão: 0,3/0,1 na intermediação (`:308`), 0,5/0,2 no autovetor (`:330`), 2/3/4 na distância (`:341-348`), 0,4/0,7 na eficiência (`:354`), 0,3/0,7 na modularidade (`:404`), 80/50/30 no papel (`:497-507`) | nenhuma faixa sem razão escrita na base; onde não há razão, o número é comparado com o grafo aleatório equivalente, e não convertido em adjetivo | FR-031, FR-038, FR-044 |
| bots e a conta da organização como nós (`developer_stats.md`; `LEDS` como membro central de comunidade) | só é nó a pessoa observada; a conta da organização é excluída e contada | FR-006, FR-007 |
| o responsável principal entra duas vezes por issue, por `assignee` e por `assignees` (`:59-68`), e o peso não é número de issues | peso é o número de issues **distintas** do par, e cada responsável conta uma vez por issue | FR-005 |
| laço removido em silêncio (`:71`) e erro de linha engolido (`:76-77`) | auto-designação e auto-revisão contadas; nenhuma linha some sem contagem | FR-007 |
| `to_undirected()` guarda o peso de um só sentido do par recíproco (`:80`) | a projeção sem direção soma os dois sentidos, declarado | FR-010 |
| comunidades sem peso (`:241`), e a modularidade calculada com peso sobre essa partição (`:254`) | comunidades com peso, algoritmo e desempate declarados | FR-027 |

## User Scenarios & Testing *(mandatory)*

As histórias valem para **as duas redes** — revisão e designação — salvo quando dizem o contrário. "Quem consulta" é a conta que abre a tela; "alcance" é o conjunto de pessoas que ela alcança pela regra da tela de pessoas.

### User Story 1 — A área "Network analysis" no menu, com a rede de revisão como primeira página (Priority: P1)

Quem coordena encontra, no menu principal, a área **Network analysis**. A primeira página é a rede de revisão da 073, que deixa de morar só dentro da organização. Dali escolhe a organização observada, a rede (revisão ou designação) e a janela.

**Why this priority**: é o pedido literal (*"coloque a analise de rede em outro menu"*) e o lugar onde todas as outras histórias aparecem. Sozinho já entrega valor: a rede da 073 fica a um clique.

**Independent Test**: com a 073 em uso, a área aparece no menu, abre a rede de revisão com os mesmos números que a tela atual mostra, e a tela atual continua alcançável pelo endereço antigo.

**Acceptance Scenarios**:

1. **Given** uma conta de qualquer papel no tenant, **When** abre qualquer página, **Then** o menu principal mostra **Network analysis**, marcado como ativo quando a página é da área.
2. **Given** uma organização com leitura da rede de revisão, **When** a área é aberta, **Then** a primeira página é a rede de revisão daquela organização, com os mesmos números da tela da 073 para a mesma janela.
3. **Given** um endereço antigo da rede de revisão (`/organizations/:id/review-network`), **When** é aberto, **Then** leva à mesma rede dentro da área nova, sem erro.
4. **Given** o tenant com duas organizações observadas, **When** a área é aberta, **Then** quem consulta escolhe a organização, e nenhuma pessoa só da outra aparece.
5. **Given** uma conta de alcance parcial, **When** abre uma página de análise da área, **Then** lê o aviso *"Names appear only for the people you reach. Measures are computed over the whole network. People outside your reach appear grouped, without names, and only in groups of at least 3."*; a página da rede de revisão da 073, dentro da área, mantém o aviso dela (seguranca.md R3).

---

### User Story 2 — A rede de designação: quem abre issue para quem é responsável (Priority: P1)

Quem coordena vê, para uma organização e janela, a rede em que cada aresta vai de quem **abriu** uma issue para quem está **designado** como responsável por ela, com o peso igual ao número de issues distintas. Vê quantas issues entraram, quantas designações viraram aresta e quantas ficaram fora, por motivo.

**Why this priority**: é a segunda aresta pedida, a da referência. Todas as análises seguintes dependem de ela existir.

**Independent Test**: para uma organização com issues coletadas, as contagens de issues, arestas e exclusões batem com uma contagem manual das mesmas issues e designações na janela.

**Acceptance Scenarios**:

1. **Given** Ana abriu 6 issues na janela, 4 designadas a Bia e 2 a Caio, **When** a rede de designação abre, **Then** há uma aresta Ana → Bia com peso 4 e uma Ana → Caio com peso 2.
2. **Given** uma issue aberta por Ana e designada a Ana, **When** a rede é montada, **Then** a designação não vira aresta e entra na contagem de auto-designações, só no agregado.
3. **Given** uma issue aberta por `dependabot[bot]`, ou designada à conta da organização, **When** a rede é montada, **Then** a designação não vira aresta e entra na contagem do motivo, sem login.
4. **Given** uma issue com três responsáveis, **When** a rede é montada, **Then** ela gera uma aresta para cada responsável (exceto o próprio autor), cada uma com peso 1 daquela issue.
5. **Given** a tela da rede de designação, **When** é lida, **Then** ela diz, em uma frase, que a aresta liga quem abriu a quem está designado, e que isso **não** diz quem designou nem quem executou.

---

### User Story 3 — O grafo ponderado (Priority: P1)

Quem coordena vê o grafo como na referência: cada pessoa é um círculo cujo **tamanho** é o grau, a **cor** é a intermediação, e cada aresta tem **espessura** pelo peso e seta pela direção. Pode aproximar, afastar e destacar uma pessoa para ver as arestas dela. No telefone, o grafo vira uma lista.

**Why this priority**: é o primeiro dos dois grafos pedidos, e a leitura visual que a referência oferece.

**Independent Test**: com uma rede conhecida de 5 pessoas, o círculo da pessoa de maior grau é o maior, a cor segue a intermediação com legenda, e a aresta de maior peso é a mais grossa.

**Acceptance Scenarios**:

1. **Given** uma rede com leitura pronta, **When** o grafo ponderado abre, **Then** cada pessoa no alcance aparece com o nome, o tamanho segue o grau, a cor segue a intermediação, e a legenda diz em texto o que tamanho, cor e espessura representam.
2. **Given** o mesmo dado aberto duas vezes, **When** o grafo é desenhado, **Then** as posições são as mesmas: o layout é calculado no servidor com semente fixa.
3. **Given** quem consulta toca ou passa o foco numa pessoa, **When** o destaque se aplica, **Then** as arestas dela ficam em evidência, as demais esmaecem, e um texto diz quantas arestas saem e chegam. O destaque funciona com teclado.
4. **Given** uma tela estreita (telefone), **When** a página abre, **Then** no lugar do grafo aparece a lista das pessoas com grau, intermediação e as arestas de cada uma, empilhada.
5. **Given** uma comunidade com 4 pessoas fora do alcance de uma conta de alcance parcial, **When** essa conta abre o grafo, **Then** as 4 aparecem como **um** nó agregado *"People outside your reach — community N (4)"*, de forma visual distinta, sem nome e sem nó individual; **And When** quem administra abre o mesmo grafo, **Then** vê as 4 pessoas por nome. **And Given** só 1 ou 2 pessoas de fora, sem outras comunidades que juntem 3, **Then** não há nó: a pessoa alcançada ligada a elas leva a marca *"has links outside your reach"*, sem aresta nem número (FR-015).

---

### User Story 4 — As comunidades (Priority: P2)

Quem coordena vê o grafo com cada pessoa colorida pela **comunidade** detectada, a modularidade da partição, o número de comunidades, e, para cada comunidade, os membros, o número de arestas internas e os **três mais centrais** por grau interno.

**Why this priority**: é o segundo grafo pedido e a identificação de comunidades, citada nominalmente no pedido.

**Independent Test**: com dois grupos densos ligados por uma aresta só, a tela mostra duas comunidades, cada uma com seus membros, e a modularidade bate com a calculada à mão.

**Acceptance Scenarios**:

1. **Given** uma rede com leitura pronta, **When** a vista de comunidades abre, **Then** cada pessoa tem a cor da comunidade dela, com legenda em texto ("Community 1", …), e a cor não é o único sinal: o número da comunidade aparece no destaque e na lista.
2. **Given** uma comunidade de 7 pessoas, **When** ela é listada, **Then** a tela mostra o tamanho, as arestas internas, os três mais centrais com o grau interno, e todos os membros por nome.
3. **Given** a modularidade calculada, **When** é exibida, **Then** aparece o número e a leitura escrita na base, com a fonte da faixa (FR-031).
4. **Given** uma comunidade com membros fora do alcance de uma conta de alcance parcial, **When** é listada para essa conta, **Then** os três mais centrais são escolhidos **entre os membros alcançados** (*"among the members you reach"*); os de fora aparecem pela regra do agrupado (FR-015) só se forem ao menos 3; e o tamanho e as arestas internas não aparecem quando, subtraídos os nomes visíveis, contariam menos de 3 pessoas de fora. **And When** quem administra lista a mesma comunidade, **Then** vê todos os membros e os três mais centrais da comunidade inteira.
5. **Given** o texto da vista, **When** é lido, **Then** ele diz que comunidade detectada **não é equipe**.

---

### User Story 5 — Os hubs (Priority: P2)

Quem coordena vê, como na referência, as pessoas com maior centralidade de **grau**, de **intermediação**, de **proximidade** e de **autovetor**, cada lista com o valor e o que ele quer dizer, em frase correta.

**Why this priority**: identificação de hubs, pedida nominalmente.

**Independent Test**: numa rede estrela com 6 pessoas, o centro lidera grau, intermediação e proximidade, e os valores batem com o cálculo manual.

**Acceptance Scenarios**:

1. **Given** uma rede com leitura pronta, **When** a seção de hubs abre, **Then** há quatro listas de até 5 pessoas (número declarado na base), ordenadas pela medida, cada linha com o valor e a frase que ele sustenta.
2. **Given** a lista de grau, **When** é lida, **Then** cada linha diz com quantas pessoas distintas a pessoa se liga, separando "opened issues assigned to / reviews" de "assigned on issues opened by / is reviewed by", e não soma o par recíproco duas vezes.
3. **Given** a lista de proximidade numa rede desconexa, **When** é lida, **Then** cada linha diz a distância média até as pessoas que ela alcança **e quantas alcança**, e nunca converte 1/proximidade em distância.
4. **Given** a lista de autovetor numa rede com mais de um componente, **When** é lida, **Then** os valores aparecem por componente, e a tela diz que valores de componentes diferentes não se comparam.
5. **Given** um componente em que o autovetor não converge, **When** a lista é montada, **Then** as pessoas daquele componente têm a medida ausente com motivo, e nenhum valor de reserva.
6. **Given** uma conta de alcance parcial, **When** a seção de hubs abre, **Then** a lista mostra só as pessoas que ela alcança (*"Among the people you reach"*), ordenadas pela medida da rede inteira, sem a posição na rede inteira, e diz que as de fora não são ordenadas aqui, sem dizer quantas; nenhuma linha é de pessoa de fora, com ou sem nome. **And When** quem administra abre a seção, **Then** a lista é a da rede inteira, como na referência (seguranca.md R1).

---

### User Story 6 — Distância e eficiência (Priority: P3)

Quem coordena vê a distância média entre as pessoas, o diâmetro e a eficiência global, cada um ao lado do valor do grafo aleatório equivalente, em vez de um adjetivo.

**Why this priority**: parte da análise pedida; não apoia sozinha decisão sobre pessoa.

**Independent Test**: numa rede caminho de 4 pessoas, a distância média é 5/3, o diâmetro 3 e a eficiência a calculada à mão.

**Acceptance Scenarios**:

1. **Given** uma rede conexa, **When** a seção abre, **Then** aparecem distância média, diâmetro e eficiência global, cada um com o valor médio dos grafos aleatórios da leitura de mundo pequeno.
2. **Given** uma rede com dois componentes, **When** a seção abre, **Then** a distância média é sobre os pares que se alcançam, dita junto da fração de pares que se alcançam; o diâmetro é "the longest distance between people who reach each other"; e a tela diz que há pares sem caminho.
3. **Given** qualquer valor, **When** é exibido, **Then** nenhuma faixa o converte em "eficiente" ou "lenta" sem razão declarada na base.

---

### User Story 7 — Mundo pequeno (Priority: P3)

Quem coordena vê o coeficiente de clustering, a distância média, os mesmos valores para os grafos aleatórios equivalentes, as duas razões e o índice σ, com a leitura "σ > 1" escrita como critério declarado.

**Why this priority**: parte da análise pedida.

**Independent Test**: com o mesmo dado, o σ calculado duas vezes é idêntico, e a proveniência diz a semente, o número de grafos aleatórios e quantos foram gerados.

**Acceptance Scenarios**:

1. **Given** uma rede com leitura pronta, **When** a seção abre, **Then** aparece a tabela da referência (clustering e distância média, real × aleatório, razão) e o σ, com o número de grafos aleatórios e a semente.
2. **Given** grafos aleatórios desconexos entre os gerados, **When** o σ é calculado, **Then** todos entram, e a distância do aleatório é medida pela mesma regra da real.
3. **Given** uma rede pequena demais (abaixo do mínimo declarado na base), ou o clustering médio dos aleatórios (C_rand) zero ou indefinido, **When** o σ é pedido, **Then** ele é ausente com motivo, e a tela não diz "não é mundo pequeno".
4. **Given** σ > 1, **When** a conclusão é escrita, **Then** ela diz que a rede **atende ao critério σ > 1**, e uma frase diz o que o critério não prova.

---

### User Story 8 — O papel de cada pessoa (Priority: P3)

Quem coordena vê, para cada pessoa da rede, o papel na rede derivado da posição em grau e intermediação, como na referência, com o critério escrito ao lado.

**Why this priority**: pedido explícito, e o item mais sensível: é classificação de pessoa. Depende das medidas de US5.

**Independent Test**: numa rede de 20 pessoas com percentis conhecidos, cada pessoa recebe o papel que a regra da base dá, e o critério aparece junto.

**Acceptance Scenarios**:

1. **Given** uma pessoa no percentil 90 de grau e 85 de intermediação, **When** o papel é exibido, **Then** ele é o do quadrante "alto grau e alta intermediação" da base, com os percentis e os cortes ao lado.
2. **Given** uma rede com menos pessoas que o mínimo declarado para percentis, **When** a tela abre, **Then** o papel é ausente com motivo para todos, e nenhuma pessoa é classificada.
3. **Given** a tela do papel, **When** é lida, **Then** ela diz que o papel descreve a **posição na rede observada na janela**, e não desempenho, importância nem mérito, e que muda quando outras pessoas entram ou saem.
4. **Given** uma conta de alcance parcial, **When** os papéis são listados, **Then** só pessoas alcançadas têm papel exibido, e nenhuma contagem de papel entre as de fora aparece (*"2 people outside your reach are Central position"* é o mesmo ranking por outro caminho). **And When** quem administra lista os papéis, **Then** vê o de todas as pessoas da rede.
5. **Given** qualquer conta, **When** abre o próprio perfil, **Then** vê o próprio papel.

---

### User Story 9 — O perfil individual (Priority: P3)

Quem coordena abre uma pessoa e vê o perfil dela na rede, como na referência: em issues de quantas pessoas abriu com outra designada (ou quantas revisa) e em issues de quantas está designada (ou por quantas é revisada), o grau e a intermediação com o percentil, o papel, e as listas "para quem" e "de quem", com o peso de cada par.

**Why this priority**: pedido explícito; é a leitura que junta tudo para uma pessoa.

**Independent Test**: para uma pessoa com arestas nos dois sentidos, as contagens e as duas listas batem com as arestas da leitura.

**Acceptance Scenarios**:

1. **Given** Bia, designada em issues abertas por 3 pessoas e autora de issues designadas a 2, **When** o perfil abre, **Then** a tela mostra "opened issues assigned to 2 people", "assigned on issues opened by 3 people", as duas listas com o peso de cada par e o total.
2. **Given** um par em que a outra pessoa está fora do alcance, **When** a lista é montada, **Then** o par aparece agregado como "N issues with people outside your reach", sem nome, nem um número por pessoa de fora.
3. **Given** uma pessoa fora do alcance de quem consulta, **When** o endereço do perfil dela é aberto, **Then** a tela diz "not found", e não "permission denied".
4. **Given** uma pessoa sem aresta na janela, **When** o perfil é pedido, **Then** a tela diz que ela não tem arestas nesta rede na janela, e não mostra zeros.

---

### Edge Cases

- **Rede sem aresta na janela**: nenhum grafo, nenhuma medida; a tela diz que não houve designação (ou revisão) entre pessoas na janela. Nunca 0, `inf` ou grafo vazio sem texto.
- **Rede com uma aresta só**: grafo desenhado; intermediação ausente com motivo `network_too_small` (com 2 pessoas a normalização não está definida, `network.analysis.parameters.betweenness`); σ e papel ausentes com motivo de tamanho mínimo; comunidade, uma, com as duas.
- **Nó sem aresta**: não é nó (073, R2 item 4). Pessoa sem aresta não entra em hub, comunidade nem papel; o número de pessoas sem aresta é dito.
- **Componente de duas pessoas**: autovetor definido (os dois iguais); comunidade possível; a regra do grupo mínimo vale para o agregado de quem está fora do alcance.
- **Rede bipartida** (designação de uns poucos autores para muitos responsáveis): a iteração do autovetor oscila; o método declarado na base converge nesse caso, e o que não converge fica ausente.
- **Empate no desempate das comunidades**: o algoritmo desempata por regra declarada; o mesmo dado dá a mesma partição.
- **Issue sem responsável**: não gera aresta; entra na contagem de issues sem designação.
- **Responsável que deixou de ser observado** (designação retirada na origem): não gera aresta, como na referência, que lê os responsáveis vigentes; limitação declarada.
- **Issue de outro tenant ou de outra organização**: nunca entra.
- **Conta apagada na origem** (autor nulo): "sem pessoa ligada", e não bot (decisão de 2026-10-03 da 073).
- **Conta da organização** (o caso `LEDS`): excluída e contada (FR-007).
- **Leitura de uma rede pronta e da outra não**: cada rede diz o próprio estado; a outra não é mostrada no lugar.
- **Coleta mais nova que a leitura**: uma linha diz que há coleta mais nova (073, Q3).
- **Cálculo falhou**: a tela diz que a leitura não está disponível e por quê; nenhuma medida de leitura anterior aparece como se fosse a atual.

## Requirements *(mandatory)*

### Functional Requirements

**A área no menu**

- **FR-001**: O menu principal MUST ter a área **Network analysis**, visível para toda conta do tenant, marcada como ativa nas páginas da área. A primeira página é a rede de revisão da 073.
- **FR-002**: A área MUST deixar escolher a organização observada, a rede (revisão ou designação) e a janela (30, 90 ou 180 dias, padrão 90). Cada escolha fica no endereço. Rede, vista e janela são listas fechadas, comparadas como texto exato e nunca convertidas em átomo; valor fora da lista volta ao padrão (seguranca.md R13).
- **FR-003**: O endereço da rede de revisão da 073 MUST continuar funcionando e levar à mesma rede dentro da área. O redirecionamento monta o destino a partir do identificador já validado, nunca do texto recebido.

**As redes**

- **FR-004**: A rede de revisão MUST ser a da 073, pela regra `review.network.edge`, sem mudança de significado.
- **FR-005**: A rede de designação MUST ter uma aresta de quem **abriu** a issue para cada pessoa **designada** como responsável vigente, com o peso igual ao número de issues distintas daquele par na janela. A issue entra na janela pelo instante de abertura. O mapeamento da aresta MUST estar declarado na base com grau de equivalência, justificativa e limitações, e MUST NOT ser chamado de colaboração.
- **FR-006**: Nas duas redes, só é nó a **pessoa observada** com tipo de conta pessoa. Equipe, conta da plataforma, bot, aplicativo e conta da organização não são nós.
- **FR-007**: Toda designação ou revisão que não vira aresta MUST cair em exatamente um motivo, contado e mostrado só como contagem, sem login e nunca por pessoa: bot ou aplicativo; conta da organização; sem pessoa ligada; auto-designação (ou auto-revisão). A conta da organização MUST ser reconhecível como não-pessoa mesmo quando a origem a apresenta como usuário.
- **FR-008**: Pessoa sem aresta na janela MUST NOT ser nó. A contagem de pessoas sem aresta é dita.
- **FR-009**: Toda leitura MUST filtrar cada tabela pelo tenant e a organização observada, buscada por id e tenant juntos. Na rede de designação, cada tabela da junção — issue, responsável, autor, responsável como pessoa, repositório observado, repositório de origem — é filtrada pelo tenant; a organização é alcançada pelo repositório observado, sem repositório excluído; responsável vigente é o não marcado como deixado de observar; o tipo de conta vem de EO, nunca do login (seguranca.md R9).
- **FR-010**: As medidas sem direção MUST usar a projeção sem direção em que o peso do par é a **soma** dos dois sentidos. As medidas com direção dizem que usam a direção.

**O alcance**

- **FR-011**: As medidas estruturais (grau, intermediação, proximidade, autovetor, comunidades, distâncias, clustering, σ, percentis e papel) MUST ser calculadas sobre a rede **inteira** da organização na janela, e não sobre o recorte de quem consulta. A tela diz isso. Com alcance parcial, o número de pessoas da rede, o tamanho de componente e o grau normalizado seguem a regra do mínimo da FR-015 (seguranca.md R3).
- **FR-012**: O **nome** de uma pessoa MUST aparecer só para quem a alcança, pela mesma regra da tela de pessoas, recalculada a cada leitura.
- **FR-013**: A leitura que chega à tela MUST passar por **uma** função de domínio que aplica o alcance; nenhuma tela monta o recorte sozinha. A área inteira usa uma só função de alcance, `pessoas_alcancadas/2`, chamada dentro da função de domínio a cada leitura. O perfil é aberto se, e só se, a pessoa está nesse conjunto ou é a de quem consulta; `pode_ver/3` não decide nada nesta área (seguranca.md R5).
- **FR-014**: Recurso de pessoa fora do alcance aberto pelo endereço MUST responder "not found", igual para pessoa de outro tenant, inexistente, fora do alcance e identificador que não é UUID. "Sem arestas nesta rede" só para pessoa alcançada.
- **FR-015**: Quem está fora do alcance MUST aparecer **sem nome, agrupado**, pela regra de [seguranca.md](seguranca.md) R2, com alcance parcial:
  1. o mínimo é **k = 3** pessoas, declarado na base (`network.analysis.parameters.outside_reach`) com a razão;
  2. no grafo, as pessoas de fora de cada comunidade são **um nó agregado** quando forem ≥ k; as de comunidades com menos de k juntam-se num nó *"other communities"* se juntarem ≥ k; senão não há nó, e cada pessoa alcançada ligada a alguém de fora leva a marca *"has links outside your reach"*, sem aresta nem número;
  3. **nenhum nó anônimo individual**;
  4. número que, subtraídos os nomes visíveis, contaria menos de k pessoas de fora não aparece (supressão complementar), e a tela diz por quê;
  5. hubs: só pessoas alcançadas, ordenadas pela medida da rede inteira, sem a posição na rede inteira e sem linha de pessoa de fora;
  6. comunidades: membros alcançados por nome, os três mais centrais entre os alcançados, os de fora pelas regras 2 e 4; comunidade sem ninguém alcançado não tem bloco próprio;
  7. papel: só de pessoa alcançada, e nenhuma contagem de papel entre os de fora;
  8. perfil: pares de fora só agregados (FR-049).

  A mesma regra vale no grafo ponderado, no de comunidades e na lista do telefone. Quem alcança todas as pessoas vê a rede inteira por nome, como na referência.
- **FR-016**: Nenhum identificador de pessoa fora do alcance MUST chegar ao navegador, nem no markup, nem em atributo, nem no estado da página, nem pseudônimo derivado dele (hash). Nó agregado tem identificador opaco por renderização. O hook do grafo não recebe dado: o servidor renderiza o SVG, e o hook só aplica transformação e classe. Nenhum `push_event` leva nó, aresta ou medida. A tela guarda só a visão já recortada. O destaque é comando de cliente; evento com identificador, se houver, é conferido contra os nós da visão (seguranca.md R6).

**O cálculo e a leitura**

- **FR-017**: O cálculo MUST rodar em segundo plano, por organização observada, rede e janela, e conferir antes de ler: o tenant existe e está ativo; a organização pertence ao tenant; a janela e a rede estão nas listas fechadas da base. Falha cancela sem gravar. O cálculo roda em fila própria, configurada, com concorrência 1; um cálculo pendente por tenant e organização; as duas redes no mesmo job; com tempo máximo e cancelamento. A rede de entrada tem impressão digital: igual à vigente, σ, Q e layout não são recalculados. Acima do tamanho máximo da base (o valor sai do plano, medido pela #1190), σ, Q contra aleatórios e layout são ausentes com motivo (seguranca.md R7).
- **FR-018**: Cada leitura MUST guardar a proveniência: rede, janela, instante, quantos itens entraram e saíram por motivo, a versão das regras e das medidas, a semente e o número de grafos aleatórios do σ, e a semente do layout. Existe uma leitura vigente por organização, rede e janela; a nova substitui a anterior. A leitura guarda identificadores de pessoa, nunca nome nem login. O percentil e o papel **não** são gravados: derivam-se na leitura. A chave da leitura vigente inclui a rede, e a substituição apaga só a da mesma rede. A gravação não usa operação que levante com o conteúdo da leitura na mensagem. Ao encerrar a observação da organização, as leituras dela são apagadas; leitura mais velha que a maior janela não é mostrada (seguranca.md R4, R10, R11).
- **FR-019**: A conectividade MUST usar um critério só, o **fraco** (direção ignorada), declarado, e a frase da tela usa o número certo de componentes ("1 group" quando conexa).

**Os grafos**

- **FR-020**: O grafo ponderado MUST mostrar cada pessoa com tamanho pelo grau, cor pela intermediação, e cada aresta com espessura pelo peso e seta pela direção, com legenda em texto para tamanho, cor e espessura.
- **FR-021**: O grafo de comunidades MUST mostrar cada pessoa com a cor da comunidade, com o número da comunidade também em texto (no destaque e na lista). Cor nunca é o único sinal.
- **FR-022**: As posições MUST ser calculadas no servidor, com semente fixa: o mesmo dado dá o mesmo desenho. O desenho é SVG; o navegador não recalcula posição. Com alcance parcial, as posições são recalculadas na leitura sobre o grafo da visão (alcançados e agregados), com a mesma semente e ordem; as posições da rede inteira só aparecem para quem alcança todos (seguranca.md R2).
- **FR-023**: O grafo MUST permitir aproximar, afastar e destacar uma pessoa com suas arestas, por ponteiro e por teclado, sem biblioteca de script nova e sem pacote novo em `assets/`; o zoom e o arrasto acontecem no cliente, sem evento ao servidor.
- **FR-024**: Nenhum rótulo do grafo MUST ser inserido como HTML a partir de texto (073, R13): todo nome é texto escapado pelo servidor. Nenhum `raw/1`, nenhum `foreignObject`; `href` só para o perfil de pessoa alcançada; cor da paleta do servidor; atributo `style` só com número formatado no servidor; SVG inline no markup.
- **FR-025**: Em tela estreita, o grafo MUST virar a lista das pessoas com as medidas e as arestas, empilhada, com o nome da coluna em cada célula.
- **FR-026**: As duas vistas (ponderada e comunidades) MUST ser alternáveis na mesma página, como na referência, sem recalcular nada.

**Comunidades**

- **FR-027**: As comunidades MUST ser detectadas pela maximização gulosa de modularidade sobre a projeção sem direção **com peso**, com o desempate declarado na base: o mesmo dado dá a mesma partição.
- **FR-028**: Para cada comunidade, a tela MUST mostrar tamanho, arestas internas, os três mais centrais por grau interno (número declarado na base) e todos os membros no alcance por nome; os de fora, agrupados (FR-015). Com alcance parcial, os três mais centrais são escolhidos **entre os membros alcançados**, pelo grau interno da rede inteira, com a frase *"among the members you reach"*; tamanho e arestas internas seguem a regra 4 da FR-015.
- **FR-029**: A modularidade da partição MUST ser mostrada com o número de comunidades.
- **FR-030**: A tela MUST dizer que comunidade detectada não é equipe, e comunidade MUST NOT receber nome de equipe.
- **FR-031**: A leitura da modularidade por faixas MUST usar só faixas declaradas na base com a fonte escrita; faixa sem fonte não vira adjetivo.

**Hubs**

- **FR-032**: A tela MUST mostrar as quatro centralidades da referência — grau, intermediação, proximidade e autovetor —, cada uma em lista ordenada pela medida, com o tamanho da lista declarado na base.
- **FR-033**: O grau MUST ser dito como número de pessoas distintas, separado por sentido, e o grau normalizado, quando aparece, diz que depende do tamanho da rede. O grau normalizado não aparece com alcance parcial: devolveria n pelo quociente (seguranca.md R3).
- **FR-034**: As listas de hubs MUST ser ordenadas pela medida, com desempate declarado. A lista geral de pessoas continua ordenada por nome.
- **FR-035**: A proximidade MUST ser dita junto da distância média da pessoa até quem ela alcança e do número de pessoas que alcança. MUST NOT converter 1/proximidade em distância.
- **FR-036**: O autovetor MUST ser calculado por componente, com peso, pelo método declarado na base; valor que não converge é ausente com motivo; valores de componentes diferentes não são comparados nem ordenados juntos.

**Distância e mundo pequeno**

- **FR-037**: A distância média MUST ser a média sobre todos os pares de pessoas que se alcançam, dita junto da fração de pares que se alcançam.
- **FR-038**: O diâmetro MUST ser a maior distância entre pessoas que se alcançam, e a eficiência global, a média de 1/distância sobre todos os pares. Cada um aparece ao lado do valor médio dos grafos aleatórios da leitura, e nenhum vira adjetivo sem razão declarada.
- **FR-039**: O coeficiente de clustering MUST ser declarado na base, incluindo o que acontece com pessoa de grau menor que 2.
- **FR-040**: O índice σ MUST ser (C / C_aleatório) / (L / L_aleatório), com o modelo de grafo aleatório, o número de grafos e a semente declarados na base.
- **FR-041**: Todo grafo aleatório gerado MUST entrar na média, dividida pelo número que entrou, e a distância do aleatório MUST seguir a regra da real (FR-037). Mesma semente e mesmo dado dão o mesmo σ.
- **FR-042**: σ MUST ser ausente com motivo quando a rede está abaixo do tamanho mínimo da base, ou quando o clustering médio ou a distância média dos aleatórios não está definido. A ausência MUST NOT ser lida como "não é mundo pequeno".
- **FR-043**: A conclusão MUST dizer "meets the σ > 1 criterion" (ou não atende), com o critério e o que ele não prova, e não "é mundo pequeno".

**Papel e perfil**

- **FR-044**: O papel de cada pessoa MUST ser derivado dos percentis de grau e de intermediação pelos cortes e rótulos declarados na regra `network.position_role`, cada corte com razão escrita.
- **FR-045**: O percentil MUST ser calculado sobre as pessoas da rede inteira (FR-011), pelo método declarado na base, com empates tratados pela mesma regra para todos.
- **FR-046**: Abaixo do número mínimo de pessoas da base, o papel MUST ser ausente com motivo para todos.
- **FR-047**: Todo papel MUST aparecer com os percentis e o critério ao lado, e a tela MUST dizer que o papel descreve a posição na rede observada na janela, e não desempenho, importância nem mérito. Ao lado do papel e dos hubs, a tela diz: *"Position in this network and window. It does not measure performance, importance or merit, and must not be used to evaluate a person."* A própria pessoa vê sempre o próprio papel (seguranca.md R4). Quem lê o papel e os hubs com o nome de **outra** pessoa é a decisão DS1.
- **FR-048**: O perfil individual MUST mostrar a quantas pessoas estão designadas as issues que a pessoa abriu (ou quantas ela revisa) e por quantas pessoas foram abertas as issues em que ela está designada (ou por quantas é revisada), com os rótulos de `network.degree.count` — nunca "assigns to" nem "receives from", que atribuem ao autor o ato de designar (revisao-semantica-2.md, A1) —, o grau e a intermediação com percentil, o papel, e as duas listas de pares com o peso, ordenadas pelo peso, com o total.
- **FR-049**: No perfil, os pares com pessoas fora do alcance MUST aparecer só agregados, sem nome e sem número por pessoa de fora.

**Ausência, reprodutibilidade, o que não se faz**

- **FR-050**: Medida sem valor MUST ser ausente com motivo nomeado, de quem é a ausência (da origem ou da plataforma), nunca 0, 0,01 ou `inf`. Os motivos estão na base, em cada medida.
- **FR-051**: Todo número da tela MUST ser marcado como **derivado**, com texto.
- **FR-052**: Calcular de novo a mesma rede, janela e dado MUST dar o mesmo resultado, incluindo comunidades, σ e posições do desenho.
- **FR-053**: A feature MUST NOT oferecer exportação do grafo, das listas ou do perfil (imagem, GEXF, CSV, HTML), nem expor a análise pela API pública, pelo servidor MCP ou ao material de geração de perfil. Nenhuma rota da área além de `live`; nenhum botão, atributo `download` nem folha de impressão dedicada; nenhum módulo da API, do MCP ou do material de perfil referencia a análise, com teste que reprova se surgir (seguranca.md R12).
- **FR-054**: O cálculo registra organização, rede, janela, contagens e duração, e MUST NOT registrar par, nome, login, papel nem valor de medida por pessoa, nem `person_id` com medida, comunidade ou papel. O resultado do job volta como relato testável, e o registro sai dele. A leitura não é atributo de telemetria (seguranca.md R15).
- **FR-055**: As emendas de [seguranca.md](seguranca.md) marcadas como incorporadas valem como requisitos desta spec.

### Key Entities

- **Rede**: um tipo de aresta entre pessoas — revisão (`review.network.edge`) ou designação (`assignment.network.edge`) — sobre a mesma organização observada.
- **Leitura de rede**: o resultado de um cálculo para organização, rede e janela. Contém as arestas com peso, as exclusões por motivo, as medidas por pessoa, as comunidades, as medidas da rede, o σ com as amostras declaradas, as posições do desenho e a proveniência. É substituída, nunca editada.
- **Aresta de designação**: autor da issue → pessoa designada, com o número de issues distintas na janela. Relação derivada, sem relator (revisão semântica).
- **Comunidade detectada**: conjunto de pessoas da partição de maior modularidade encontrada; não é equipe.
- **Papel na rede**: rótulo de posição derivado dos percentis de grau e intermediação pela regra da base; não é atributo da pessoa.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Para uma organização real, as contagens da rede de designação (issues, arestas, exclusões por motivo) batem com uma contagem manual na origem para a mesma janela, sem diferença.
- **SC-002**: Para cinco redes de teste com resposta conhecida (estrela, caminho, dois grupos ligados por uma ponte, bipartida, desconexa), grau, intermediação, proximidade, autovetor, distância média, diâmetro, eficiência, clustering e modularidade batem com o valor calculado à mão ou por ferramenta de referência, com tolerância declarada no plano.
- **SC-003**: Recalcular a mesma leitura 10 vezes dá 10 resultados idênticos, inclusive comunidades, σ e posições.
- **SC-004**: Nenhuma pessoa fora do alcance aparece por nome, e nenhum identificador dela chega ao navegador: verificado com dois tenants, duas organizações e uma conta de alcance restrito, inspecionando o HTML entregue. Nenhum identificador nem pseudônimo de pessoa de fora aparece em JSON entregue a hook nem em `push_event`; nenhum agregado de menos de 3 pessoas aparece; nenhuma linha de hub é de pessoa de fora — verificado com uma organização em que 1, 2 e 3 pessoas de fora pertencem à mesma comunidade.
- **SC-005**: Nenhum número da tela aparece como zero, 0,01 ou infinito quando o fato é ausência: verificado numa rede sem aresta, numa rede desconexa e num componente bipartido.
- **SC-006**: Quem coordena responde, a partir da tela e em menos de dois minutos, "quais grupos se formam e quem os liga?", sem consultar outra fonte.
- **SC-007**: No telefone, a página não rola de lado, e toda informação do grafo está na lista.

## Assumptions

- **Janela da designação pelo instante de abertura da issue**: `issue_assignees` não guarda quando a designação aconteceu (decisão de 2026-08-27, `person_work.ex`). A alternativa com data, o evento de designação da linha do tempo, foi a opção (b) da D1; a pessoa mantenedora escolheu (a) em 2026-10-04.
- **Responsáveis vigentes**: como na referência, a aresta usa os responsáveis observados na última coleta. A designação retirada não gera aresta.
- **Tamanho das listas de hubs = 5 e dos mais centrais por comunidade = 3**, como na referência, declarados na base.
- **σ com 100 grafos aleatórios do mesmo número de pessoas e arestas**, semente fixa: valores propostos na base, com a razão.
- **Sem dependência nova**: cálculo e layout em Elixir, para redes de dezenas a poucas centenas de pessoas por organização. O plano confirma com o volume medido (073/T002, #1190).
- **O alcance** é o da tela de pessoas. A divergência entre a frase e o recorte aberta em #1185 vale aqui também, e é decidida antes da tarefa que aplica o alcance.

## Dependências

- A 073 mergeada em `development` (PR #1228), com a regra da aresta e a leitura.
- Issues e responsáveis coletados com autor e responsável resolvidos em pessoa (já existe).
- **Revisão semântica** antes do plano: [revisao-semantica.md](revisao-semantica.md).
- **Avaliação do agente `security` antes do plano**: [seguranca.md](seguranca.md).
- **Protótipo aprovado pela pessoa mantenedora** antes do código da tela, pelo agente `design`.
- #1185 (alcance: a frase e o recorte) decidida antes da tarefa que aplica o alcance (DS4).
- O conserto de `Repo.insert!` em `ReviewNetwork.Commands` (`lib/the_band/review_network/commands.ex:172`, seguranca.md R10: a exceção leva os pares de `person_id` para `oban_jobs.errors`) antes ou junto da primeira tarefa que toca o cálculo. É defeito de segurança conhecido na mesma superfície (AGENTS.md §14.0).

## Decisões da pessoa mantenedora

Bloqueavam o plano. As opções e a recomendação de cada uma estão no documento de origem. **Decididas em 2026-10-04 pela pessoa mantenedora: todas as recomendações aceitas.**

| # | Pergunta | Recomendação | Onde | Decisão (2026-10-04) |
|---|---|---|---|---|
| D1 | Qual aresta é a "da referência": autor → responsável vigente (igual à referência) ou quem designou → designado (`AssignedEvent`, com data) | autor → responsável, com o nome "designação" | [revisao-semantica.md](revisao-semantica.md) | **(a)** autor da issue → responsável vigente, com o nome "designação" |
| D2 | Rótulos do papel e corte baixo: posicionais e 20, ou os da referência e 30 | posicionais e 20 | revisao-semantica.md | **(a)** rótulos posicionais, corte baixo 20 |
| D3 | Como a conta da organização é reconhecida (e se vale para a rede de revisão da 073) | a administração marca, com as guardas de seguranca.md R8 | revisao-semantica.md; seguranca.md R8 | **(a)** a administração marca a conta da organização, com as guardas da R8. **A7, decidida em 2026-10-04 (T002, #1326)**: a marca vale **também** para a rede de revisão da 073, com `review.network.edge` na versão 2 (`organization_account` entre `bot_or_app` e `unlinked_person`); T027 fica no backlog |
| D4 | Intermediação sem direção ou dirigida | sem direção | revisao-semantica.md | **(a)** intermediação sem direção |
| D5 | Clustering exclui quem tem menos de 2 vizinhos, ou conta 0 | excluir e dizer quantos | revisao-semantica.md | **(a)** quem tem menos de 2 vizinhos fica fora do clustering, e a tela diz quantos |
| D6 | Segundo revisor do papel semântico antes do plano | sim | revisao-semantica.md | **(a)** segundo revisor independente: [revisao-semantica-2.md](revisao-semantica-2.md) |
| DS1 | Quem lê papel e hubs com o nome de outra pessoa | quem tem escopo concedido e a administração | [seguranca.md](seguranca.md) | **(b)** papel e hubs com nome só para quem tem escopo concedido e para a administração |
| DS2 | O mínimo do agrupado: 3 ou 5 | 3 (já na FR-015) | seguranca.md | **3** |
| DS3 | O total de uma pessoa alcançada: verdadeiro, ou separado em "with people you reach" / "in total" | total verdadeiro, com o risco residual escrito | seguranca.md | **(a)** total verdadeiro, com o risco residual escrito |
| DS4 | A #1185: corrigir a frase ou incluir a liderança declarada | corrigir a frase | seguranca.md | **(a)** a #1185 se resolve corrigindo a frase |
| DS5 | Conta sem alcance: vê tudo agregado, ou só as medidas da rede e o próprio perfil | só medidas e o próprio perfil | seguranca.md | **(b)** só as medidas da rede e o próprio perfil |

**Decisões de 2026-10-04 sobre o plano** ([plan.md](plan.md), *Decisões a confirmar*), todas iguais à opção padrão, registradas na T002 ([#1326](https://github.com/The-Band-Solution/theband/issues/1326)):

| # | Pergunta | Decisão (2026-10-04) |
|---|---|---|
| A7 | A marca de conta da organização vale também para a rede de revisão da 073? | **sim**: `review.network.edge` versão 2, coluna anulável na leitura da 073 (T027) |
| R10, item 8 | Os *"três mais centrais"* de cada comunidade seguem a DS1? | **sim**: só aparecem com escopo concedido ou para a administração (T037) |
| R21 | Comunidade rotulada por letra ou por número? | **letra** (A, B, …), como no protótipo aprovado (T037) |
| Escopo | O que entra no sprint 041 | **Fundação + US1–US3** (T001–T034); US4–US9 e o acabamento ficam para o sprint seguinte |
